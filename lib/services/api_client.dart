import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

import 'package:http/http.dart' as http;
import 'user_store.dart';

/// Reusable HTTP client for the AfroPool backend API.
///
/// - Centralizes base URL + default headers.
/// - Handles JSON encode/decode.
/// - Supports GET and POST.
/// - Makes it easy to add MVP auth (`x-user-id`) now or later.
/// - Supports multiple environments (real device, Android emulator, iOS simulator).
///
/// This file is intentionally standalone and is not wired into the UI yet.
class ApiClient {
  // FIXED: Use deployed Render backend for all platforms
  static const String productionBaseUrl = 'https://afro-korea-pool-server.onrender.com';

  /// Use Render URL for emulator/simulator as well to target deployed backend
  static const String androidEmulatorBaseUrl = productionBaseUrl;
  static const String iosSimulatorBaseUrl = productionBaseUrl;

  /// Default fallback URL points to Render deployment
  static const String defaultBaseUrl = productionBaseUrl;

  final Uri baseUri;
  final http.Client _http;

  /// Provides a user id for MVP auth.
  ///
  /// When present (or when `userId` is passed per request), the client adds:
  /// `x-user-id: <uuid>`
  final FutureOr<String?> Function()? userIdProvider;

  /// Headers applied to every request (can be overridden per request).
  ///
  /// Defaults to JSON request/response headers.
  final Map<String, String> defaultHeaders;

  /// Optional manual override (set by developer) to force a base URL.
  /// Example: `ApiClient.manualBaseUrl = 'http://10.0.2.2:3000';`
  static String? manualBaseUrl;

  static String get _baseUrl {
    // Manual override takes precedence
    if (manualBaseUrl != null && manualBaseUrl!.isNotEmpty) {
      debugPrint('ApiClient: manualBaseUrl override present -> ${manualBaseUrl!}');
      return manualBaseUrl!;
    }

    // For deployed app we want to use the Render URL on all platforms (web, Android, iOS, desktop).
    if (kIsWeb) {
      debugPrint('ApiClient: Platform detected = Web; selecting $productionBaseUrl');
      return productionBaseUrl;
    }

    try {
      if (Platform.isAndroid) {
        debugPrint('ApiClient: Platform detected = Android; selecting $productionBaseUrl');
        return productionBaseUrl;
      }

      if (Platform.isIOS) {
        debugPrint('ApiClient: Platform detected = iOS; selecting $productionBaseUrl');
        return productionBaseUrl;
      }

      debugPrint('ApiClient: Platform unknown; selecting fallback $productionBaseUrl');
      return productionBaseUrl;
    } catch (e, st) {
      debugPrint('ApiClient: Platform detection error: $e');
      debugPrint(st.toString());
      debugPrint('ApiClient: Falling back to $productionBaseUrl');
      return productionBaseUrl;
    }
  }

  ApiClient({
    String? baseUrl,
    http.Client? httpClient,
    this.userIdProvider,
    Map<String, String>? defaultHeaders,
  }) : baseUri = Uri.parse(baseUrl ?? _baseUrl),
       _http = httpClient ?? http.Client(),
       defaultHeaders =
           defaultHeaders ??
           const {
             'accept': 'application/json',
             'content-type': 'application/json; charset=utf-8',
           };

  /// Releases the underlying HTTP client.
  ///
  /// Call this if you create an `ApiClient` with the default constructor in a
  /// long-lived object that is disposed.
  void close() => _http.close();

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    String? userId,
    Duration timeout = const Duration(seconds: 20),
    T Function(Object? json)? decode,
  }) async {
    final uri = _buildUri(path, queryParameters);
    final mergedHeaders = await _buildHeaders(headers, userId);

    final response = await _http
        .get(uri, headers: mergedHeaders)
        .timeout(timeout);

    final json = _decodeJsonResponse(response);
    return (decode ?? _identityDecode<T>)(json);
  }

  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    String? userId,
    Duration timeout = const Duration(seconds: 20),
    T Function(Object? json)? decode,
  }) async {
    final uri = _buildUri(path, queryParameters);
    final mergedHeaders = await _buildHeaders(headers, userId);

    final response = await _http
        .post(uri, headers: mergedHeaders, body: jsonEncode(body))
        .timeout(timeout);

    final json = _decodeJsonResponse(response);
    return (decode ?? _identityDecode<T>)(json);
  }

  Uri _buildUri(String path, Map<String, dynamic>? queryParameters) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;

    final resolved = baseUri.replace(
      path: _joinPaths(baseUri.path, normalizedPath),
      queryParameters:
          queryParameters == null ? null : _stringifyQuery(queryParameters),
    );

    return resolved;
  }

  Future<Map<String, String>> _buildHeaders(
    Map<String, String>? headers,
    String? userId,
  ) async {
    final result = <String, String>{...defaultHeaders, ...?headers};

    // Order: explicit request value -> injected provider -> persisted UserStore.
    final fromProvider = userIdProvider == null ? null : await userIdProvider!();
    final fromStore = await UserStore.getUserId();
    final resolvedUserId = (userId ?? fromProvider ?? fromStore)?.trim();

    if (resolvedUserId != null && resolvedUserId.isNotEmpty) {
      result['x-user-id'] = resolvedUserId;
    }

    return result;
  }

  Object? _decodeJsonResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        reasonPhrase: response.reasonPhrase,
        body: response.body,
      );
    }

    if (response.body.isEmpty) return null;

    try {
      return jsonDecode(response.body);
    } on FormatException catch (err) {
      throw ApiException(
        statusCode: response.statusCode,
        reasonPhrase: response.reasonPhrase,
        body: response.body,
        message: 'Invalid JSON response: ${err.message}',
      );
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String? reasonPhrase;
  final String body;
  final String? message;

  ApiException({
    required this.statusCode,
    required this.reasonPhrase,
    required this.body,
    this.message,
  });

  @override
  String toString() {
    final base = 'ApiException(statusCode: $statusCode, reason: $reasonPhrase)';
    if (message == null || message!.isEmpty) return base;
    return '$base: $message';
  }
}

T _identityDecode<T>(Object? json) => json as T;

String _joinPaths(String a, String b) {
  if (a.isEmpty) return b;
  if (b.isEmpty) return a;
  final left = a.endsWith('/') ? a.substring(0, a.length - 1) : a;
  final right = b.startsWith('/') ? b.substring(1) : b;
  return '$left/$right';
}

Map<String, String> _stringifyQuery(Map<String, dynamic> queryParameters) {
  final result = <String, String>{};
  for (final entry in queryParameters.entries) {
    final value = entry.value;
    if (value == null) continue;
    result[entry.key] = value.toString();
  }
  return result;
}
