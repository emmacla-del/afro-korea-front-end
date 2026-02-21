import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

typedef JwtTokenProvider = FutureOr<String?> Function();
typedef UserIdProvider = FutureOr<String?> Function();

class ApiClient {
  // Compile-time override: --dart-define=AFROPOOL_API_BASE_URL=...
  static const String baseUrl = String.fromEnvironment(
    'AFROPOOL_API_BASE_URL',
    defaultValue: 'https://afro-korea-pool-server.onrender.com',
  );

  final http.Client _http;
  final JwtTokenProvider tokenProvider;
  final UserIdProvider? userIdProvider;

  ApiClient({
    http.Client? httpClient,
    JwtTokenProvider? tokenProvider,
    this.userIdProvider,
  }) : _http = httpClient ?? http.Client(),
       tokenProvider = tokenProvider ?? _defaultTokenProvider;

  void close() => _http.close();

  Future<Object?> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Duration timeout = const Duration(seconds: 10),
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, queryParameters);
    final mergedHeaders = await _buildHeaders(extra: headers);

    final response = await _http
        .get(uri, headers: mergedHeaders)
        .timeout(timeout);

    return _decodeJsonResponse(response);
  }

  Future<Object?> patch(
    String path, {
    Object? body,
    Duration timeout = const Duration(seconds: 10),
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, null);
    final mergedHeaders = await _buildHeaders(extra: headers);

    final response = await _http
        .patch(uri, headers: mergedHeaders, body: jsonEncode(body ?? const {}))
        .timeout(timeout);

    return _decodeJsonResponse(response);
  }

  Future<Object?> post(
    String path, {
    Object? body,
    Duration timeout = const Duration(seconds: 10),
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, null);
    final mergedHeaders = await _buildHeaders(extra: headers);

    final response = await _http
        .post(uri, headers: mergedHeaders, body: jsonEncode(body ?? const {}))
        .timeout(timeout);

    return _decodeJsonResponse(response);
  }

  Uri _buildUri(String path, Map<String, dynamic>? queryParameters) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse(baseUrl).replace(
      path: normalizedPath,
      queryParameters:
          queryParameters == null ? null : _stringifyQuery(queryParameters),
    );
  }

  Future<Map<String, String>> _buildHeaders({
    Map<String, String>? extra,
  }) async {
    final token = await tokenProvider();
    final userId = userIdProvider == null ? null : await userIdProvider!();

    return <String, String>{
      'accept': 'application/json',
      'content-type': 'application/json; charset=utf-8',
      'Authorization': 'Bearer ${token ?? ''}',
      if (userId != null && userId.isNotEmpty) 'x-user-id': userId,
      ...?extra,
    };
  }

  Object? _decodeJsonResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        reasonPhrase: response.reasonPhrase,
        body: response.body,
        message: _extractErrorMessage(response.body),
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

  static Future<String?> _defaultTokenProvider() async {
    // TODO(auth): Replace with real JWT storage.
    final token = const String.fromEnvironment('AFROPOOL_JWT', defaultValue: '');
    return token.isEmpty ? null : token;
  }
}

String? _extractErrorMessage(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return null;

  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map<String, dynamic>) {
      final message = decoded['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
      if (message is List) {
        final joined = message.map((e) => e.toString()).join(', ').trim();
        if (joined.isNotEmpty) return joined;
      }

      final errors = decoded['errors'];
      if (errors is List && errors.isNotEmpty) {
        final first = errors.first;
        if (first is Map<String, dynamic>) {
          final path = first['path']?.toString();
          final errMsg = first['message']?.toString();
          if (errMsg != null && errMsg.trim().isNotEmpty) {
            if (path != null && path.trim().isNotEmpty) {
              return '$path: ${errMsg.trim()}';
            }
            return errMsg.trim();
          }
        }
        return errors.first.toString();
      }
    }
  } catch (_) {
    // Ignore JSON parse failures; fall back to raw body below.
  }

  return trimmed.length > 300 ? '${trimmed.substring(0, 300)}...' : trimmed;
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

Map<String, String> _stringifyQuery(Map<String, dynamic> queryParameters) {
  final result = <String, String>{};
  for (final entry in queryParameters.entries) {
    final value = entry.value;
    if (value == null) continue;
    result[entry.key] = value.toString();
  }
  return result;
}
