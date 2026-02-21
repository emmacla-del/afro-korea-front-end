import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/product.dart'; // FIXED: Issue #1 - unified product model

/// Exception wrapper for API errors with meaningful error messages
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;
  final StackTrace? stackTrace;

  ApiException({
    required this.message,
    this.statusCode,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() =>
      'ApiException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

/// Production-ready API service using Dio with Singleton pattern.
///
/// Features:
/// - Singleton instance for app-wide use
/// - Configured for Render-deployed backend
/// - Built-in logging and error interception
/// - Bearer token support
/// - Proper timeout and retry handling
/// - Null-safe Dart
///
/// Usage:
/// ```dart
/// // Get singleton instance
/// final apiService = ApiService.instance;
/// 
/// // Set bearer token for authenticated requests
/// apiService.setBearerToken('your_token_here');
/// 
/// // Fetch products
/// final products = await apiService.fetchProducts();
/// ```
class ApiService {
  /// Production backend URL (Render)
  static const String _baseUrl = 'https://afro-korea-pool-server.onrender.com';

  /// Request timeout duration
  static const Duration _timeout = Duration(seconds: 15);

  /// Singleton instance
  static final ApiService _instance = ApiService._internal();

  late final Dio _dio;
  String? _bearerToken;

  /// Private constructor for Singleton pattern
  ApiService._internal() {
    _initializeDio();
  }

  /// Get singleton instance
  static ApiService get instance => _instance;

  /// Initialize Dio with production-ready configuration
  void _initializeDio() {
    final baseOptions = BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: _timeout,
      receiveTimeout: _timeout,
      sendTimeout: _timeout,
      contentType: 'application/json',
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json; charset=utf-8',
      },
      validateStatus: (status) {
        // Allow all status codes to be handled by interceptors
        return status != null && status < 500;
      },
    );

    _dio = Dio(baseOptions);

    // Add interceptors
    _dio.interceptors.addAll([
      _LoggingInterceptor(),
      _AuthInterceptor(this),
      _ErrorInterceptor(),
    ]);

    debugPrint('✅ ApiService initialized for: $_baseUrl');
  }

  /// Set Bearer token for authenticated requests
  void setBearerToken(String token) {
    _bearerToken = token;
    debugPrint('🔐 Bearer token set for authentication');
  }

  /// Clear Bearer token
  void clearBearerToken() {
    _bearerToken = null;
    debugPrint('🔓 Bearer token cleared');
  }

  /// Get current Bearer token
  String? get bearerToken => _bearerToken;

  /// Fetch all products from /products endpoint
  ///
  /// FIXED: Issue #21 - Uses Product.fromBackendApi() to deserialize backend response
  /// Backend returns: { id, title, description, category, supplier: {displayName}, variants: [...], isActive, createdAt, updatedAt }
  ///
  /// Throws [ApiException] on errors.
  /// Returns empty list if no products found.
  Future<List<Product>> fetchProducts() async {
    try {
      debugPrint('📡 Fetching products from /products');

      final response = await _dio.get<List<dynamic>>(
        '/products',
      );

      // Handle 200 success
      if (response.statusCode == 200) {
        final data = response.data ?? [];
        final products = data
            .map((item) {
              try {
                final json = item is Map<String, dynamic>
                    ? item
                    : <String, dynamic>{};
                return Product.fromBackendApi(json); // FIXED: Issue #21
              } catch (e) {
                debugPrint('⚠️ Error parsing product: $e');
                return null;
              }
            })
            .whereType<Product>()
            .toList();

        debugPrint('✅ Fetched ${products.length} products');
        return products;
      }

      // Handle 401 Unauthorized
      if (response.statusCode == 401) {
        throw ApiException(
          message: 'Unauthorized: Please log in to view products',
          statusCode: 401,
        );
      }

      // Handle 500+ server errors
      if (response.statusCode != null && response.statusCode! >= 500) {
        throw ApiException(
          message: 'Server error: Unable to fetch products',
          statusCode: response.statusCode,
        );
      }

      // Handle other errors
      throw ApiException(
        message: 'Unexpected error: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      debugPrint('❌ Dio error fetching products: $e');
      throw ApiException(
        message: _getDioErrorMessage(e),
        statusCode: e.response?.statusCode,
        originalError: e,
        stackTrace: StackTrace.current,
      );
    } on ApiException {
      rethrow;
    } catch (e, st) {
      debugPrint('❌ Unexpected error fetching products: $e');
      throw ApiException(
        message: 'Unexpected error: $e',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  /// Fetch a specific pool by ID
  Future<Map<String, dynamic>> fetchPool(String poolId) async {
    try {
      debugPrint('📡 Fetching pool: $poolId');

      final response = await _dio.get<Map<String, dynamic>>(
        '/pools/$poolId',
      );

      if (response.statusCode == 200 && response.data != null) {
        debugPrint('✅ Fetched pool: $poolId');
        return response.data!;
      }

      throw ApiException(
        message: 'Failed to fetch pool',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException(
        message: _getDioErrorMessage(e),
        statusCode: e.response?.statusCode,
        originalError: e,
      );
    }
  }

  /// Commit to a pool
  Future<Map<String, dynamic>> commitToPool(
    String poolId, {
    required Map<String, dynamic> body,
  }) async {
    try {
      debugPrint('📡 Committing to pool: $poolId');

      final response = await _dio.post<Map<String, dynamic>>(
        '/pools/$poolId/commit',
        data: body,
      );

      if (response.statusCode == 200 && response.data != null) {
        debugPrint('✅ Successfully committed to pool: $poolId');
        return response.data!;
      }

      throw ApiException(
        message: 'Failed to commit to pool',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException(
        message: _getDioErrorMessage(e),
        statusCode: e.response?.statusCode,
        originalError: e,
      );
    }
  }

  /// Fetch current user's orders
  Future<List<Map<String, dynamic>>> fetchMyOrders() async {
    try {
      debugPrint('📡 Fetching my orders from /me/orders');

      final response = await _dio.get<List<dynamic>>(
        '/me/orders',
      );

      if (response.statusCode == 200) {
        final data = response.data ?? [];
        return data.map((item) => item as Map<String, dynamic>).toList();
      }

      if (response.statusCode == 401) {
        throw ApiException(
          message: 'Unauthorized: Please log in to view orders',
          statusCode: 401,
        );
      }

      throw ApiException(
        message: 'Failed to fetch orders',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException(
        message: _getDioErrorMessage(e),
        statusCode: e.response?.statusCode,
        originalError: e,
      );
    }
  }

  /// Create a direct order from cart items
  /// 
  /// Requires Bearer token for authentication.
  /// Sends cart items to /orders/direct endpoint.
  /// 
  /// Parameters:
  /// - [items] - List of JSON-serialized cart items with productId, quantity, unitPrice
  /// 
  /// Returns the order response with orderId and status
  Future<Map<String, dynamic>> createOrder(List<Map<String, dynamic>> items) async {
    try {
      debugPrint('📡 Creating order with ${items.length} items');

      if (items.isEmpty) {
        throw ApiException(
          message: 'Cannot create order: Cart is empty',
          statusCode: 400,
        );
      }

      if (_bearerToken == null) {
        throw ApiException(
          message: 'Unauthorized: Please log in to create orders',
          statusCode: 401,
        );
      }

      final requestBody = {
        'items': items,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final response = await _dio.post<Map<String, dynamic>>(
        '/orders/direct',
        data: requestBody,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data != null) {
          debugPrint('✅ Order created successfully: ${response.data?['orderId']}');
          return response.data!;
        }
      }

      if (response.statusCode == 401) {
        throw ApiException(
          message: 'Unauthorized: Token may be expired',
          statusCode: 401,
        );
      }

      if (response.statusCode == 400) {
        final errorMessage = response.data?['message'] ?? 'Invalid order data';
        throw ApiException(
          message: 'Validation error: $errorMessage',
          statusCode: 400,
        );
      }

      throw ApiException(
        message: 'Failed to create order',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      debugPrint('❌ Dio error creating order: $e');
      throw ApiException(
        message: _getDioErrorMessage(e),
        statusCode: e.response?.statusCode,
        originalError: e,
      );
    } on ApiException {
      rethrow;
    } catch (e, st) {
      debugPrint('❌ Unexpected error creating order: $e');
      throw ApiException(
        message: 'Unexpected error: $e',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  /// Convert DioException to user-friendly message
  static String _getDioErrorMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout. Check your network and backend availability.';
      case DioExceptionType.sendTimeout:
        return 'Request timeout while sending data.';
      case DioExceptionType.receiveTimeout:
        return 'Response timeout. Backend took too long to respond.';
      case DioExceptionType.badResponse:
        return 'Server error (${error.response?.statusCode}): ${error.response?.statusMessage}';
      case DioExceptionType.badCertificate:
        return 'SSL certificate error. This backend may have SSL issues.';
      case DioExceptionType.connectionError:
        return 'Connection error. Backend may be unreachable.';
      case DioExceptionType.unknown:
        return 'Unknown error: ${error.message}';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
    }
  }

  /// Close Dio instance and clean up resources
  void close() {
    _dio.close();
    debugPrint('🔌 ApiService closed');
  }
}

/// Logging interceptor to print all HTTP requests/responses
class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint(
      '📤 [${options.method}] ${options.uri}\n'
      'Headers: ${options.headers}\n'
      'Timeout: ${options.sendTimeout}ms',
    );
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint(
      '📥 [${response.statusCode}] ${response.requestOptions.uri}\n'
      'Response: ${response.data.toString().replaceAll('\n', ' ').substring(0, 200)}...',
    );
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('❌ [Error] ${err.requestOptions.uri}\n$err');
    super.onError(err, handler);
  }
}

/// Auth interceptor to inject Bearer token into requests
class _AuthInterceptor extends Interceptor {
  final ApiService _apiService;

  _AuthInterceptor(this._apiService);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Inject Bearer token if available
    if (_apiService.bearerToken != null) {
      options.headers['Authorization'] = 'Bearer ${_apiService.bearerToken}';
      debugPrint('🔐 Bearer token injected');
    }
    super.onRequest(options, handler);
  }
}

/// Error interceptor to handle common error scenarios
class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Log specific error codes
    if (err.response != null) {
      switch (err.response?.statusCode) {
        case 401:
          debugPrint('🔓 Unauthorized (401): Token may be expired');
        case 403:
          debugPrint('🚫 Forbidden (403): Insufficient permissions');
        case 404:
          debugPrint('📭 Not Found (404): Endpoint does not exist');
        case 500:
          debugPrint('💥 Server Error (500): Internal server error');
        case 503:
          debugPrint('🔧 Service Unavailable (503): Backend is down');
      }
    }
    super.onError(err, handler);
  }
}
