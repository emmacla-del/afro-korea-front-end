import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime_type/mime_type.dart' as mime;
import '../models/product.dart';
import '../models/supplier_product.dart';
import 'user_store.dart';

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

class ApiService {
  static const String _baseUrl = 'https://afro-korea-pool-server.onrender.com';

  // ✅ NEW: public getter so other files can build absolute image URLs
  static String get baseUrl => _baseUrl;

  static const Duration _timeout = Duration(seconds: 60);

  static final ApiService _instance = ApiService._internal();
  late final Dio _dio;
  String? _bearerToken;

  ApiService._internal() {
    _initializeDio();
  }

  static ApiService get instance => _instance;

  void _initializeDio() {
    final baseOptions = BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: _timeout,
      receiveTimeout: _timeout,
      sendTimeout: _timeout,
      contentType: 'application/json; charset=utf-8',
      headers: {'Accept': 'application/json'},
      validateStatus: (status) {
        return status != null && status < 500;
      },
    );

    _dio = Dio(baseOptions);

    _dio.interceptors.addAll([
      _UserIdInterceptor(),
      _AuthInterceptor(this),
      _LoggingInterceptor(),
      _ErrorInterceptor(),
    ]);

    debugPrint('✅ ApiService initialized for: $_baseUrl');
  }

  void setBearerToken(String? token) {
    final normalized = (token ?? '').trim();
    _bearerToken = normalized.isEmpty ? null : normalized;
    if (_bearerToken == null) {
      debugPrint('🔓 Bearer token cleared');
      return;
    }
    debugPrint('🔐 Bearer token set for authentication');
  }

  void clearBearerToken() {
    setBearerToken(null);
  }

  String? get bearerToken => _bearerToken;

  // -------------------------------------------------------------------------
  // Authentication
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>> register(
    String phone,
    String password, {
    String role = 'CUSTOMER',
    Map<String, dynamic>? supplierData,
  }) async {
    try {
      final Map<String, dynamic> requestBody = {
        'phone': phone.trim(),
        'password': password,
        'role': role.trim().toUpperCase(),
      };
      if (supplierData != null) {
        requestBody['supplierData'] = supplierData;
      }
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: requestBody,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data ?? {};
      }

      throw ApiException(
        message: _extractResponseError(response.data) ?? 'Registration failed',
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

  Future<Map<String, dynamic>> login(String phone, String password) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'phone': phone.trim(), 'password': password},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data ?? {};
      }

      throw ApiException(
        message: _extractResponseError(response.data) ?? 'Login failed',
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

  // -------------------------------------------------------------------------
  // Customer endpoints
  // -------------------------------------------------------------------------

  Future<List<Product>> fetchProducts() async {
    try {
      debugPrint('📡 Fetching products from /products');
      final response = await _dio.get<List<dynamic>>('/products');

      if (response.statusCode == 200) {
        final data = response.data ?? [];
        final products = data
            .map((item) {
              try {
                final json = item is Map<String, dynamic>
                    ? item
                    : <String, dynamic>{};
                return Product.fromBackendApi(json);
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

      if (response.statusCode == 401) {
        throw ApiException(
          message: 'Unauthorized: Please log in to view products',
          statusCode: 401,
        );
      }

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

  Future<Map<String, dynamic>> fetchPool(String poolId) async {
    try {
      debugPrint('📡 Fetching pool: $poolId');
      final response = await _dio.get<Map<String, dynamic>>('/pools/$poolId');
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

  // -------------------------------------------------------------------------
  // Team Deal endpoints
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>> createTeamDeal({
    required String variantId,
    required int teamPrice,
    required int minBuyers,
  }) async {
    try {
      debugPrint('📡 Creating team deal for variant: $variantId');
      final response = await _dio.post<Map<String, dynamic>>(
        '/pools/team',
        data: {
          'variantId': variantId,
          'teamPrice': teamPrice,
          'minBuyers': minBuyers,
        },
      );
      return response.data ?? {};
    } on DioException catch (e) {
      throw ApiException(
        message: _getDioErrorMessage(e),
        statusCode: e.response?.statusCode,
        originalError: e,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getOpenTeamDeals() async {
    try {
      debugPrint('📡 Fetching open team deals from /pools/team');
      final response = await _dio.get<List<dynamic>>('/pools/team');
      if (response.statusCode == 200) {
        final data = response.data ?? [];
        return data.map((item) => item as Map<String, dynamic>).toList();
      }
      throw ApiException(
        message: 'Failed to fetch team deals',
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

  Future<Map<String, dynamic>> joinTeamDeal(String poolId) async {
    try {
      debugPrint('📡 Joining team deal: $poolId');
      final response = await _dio.post<Map<String, dynamic>>(
        '/pools/$poolId/join',
      );
      return response.data ?? {};
    } on DioException catch (e) {
      throw ApiException(
        message: _getDioErrorMessage(e),
        statusCode: e.response?.statusCode,
        originalError: e,
      );
    }
  }

  // -------------------------------------------------------------------------
  // Orders
  // -------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchMyOrders() async {
    try {
      debugPrint('📡 Fetching my orders from /me/orders');
      final response = await _dio.get<List<dynamic>>('/me/orders');
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

  Future<Map<String, dynamic>> createOrder(
    List<Map<String, dynamic>> items,
  ) async {
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

      final response = await _dio.post<Map<String, dynamic>>(
        '/orders/direct',
        data: {'items': items, 'timestamp': DateTime.now().toIso8601String()},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data != null) {
          debugPrint(
            '✅ Order created successfully: ${response.data?['orderId']}',
          );
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
      throw ApiException(
        message: _getDioErrorMessage(e),
        statusCode: e.response?.statusCode,
        originalError: e,
      );
    } on ApiException {
      rethrow;
    } catch (e, st) {
      throw ApiException(
        message: 'Unexpected error: $e',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  // -------------------------------------------------------------------------
  // Supplier endpoints
  // -------------------------------------------------------------------------

  Future<List<SupplierProduct>> getSupplierProducts() async {
    try {
      debugPrint('📡 Fetching supplier products from /supplier/products');
      final response = await _dio.get<List<dynamic>>('/supplier/products');
      if (response.statusCode == 200) {
        final data = response.data ?? [];
        return data
            .map(
              (json) => SupplierProduct.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      }
      throw ApiException(
        message: 'Failed to fetch supplier products',
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

  Future<Map<String, dynamic>> getSupplierProductSummary() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/supplier/products/summary',
      );
      return response.data ?? {};
    } on DioException catch (e) {
      throw ApiException(
        message: _getDioErrorMessage(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> getSupplierPurchaseOrdersSummary() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/supplier/purchase-orders/summary',
      );
      return response.data ?? {};
    } on DioException catch (e) {
      throw ApiException(
        message: _getDioErrorMessage(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> getLatestCatalogImport() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/supplier/catalog-imports/latest',
      );
      return response.data ?? {};
    } on DioException catch (e) {
      throw ApiException(
        message: _getDioErrorMessage(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> createSupplierProduct(
    Map<String, dynamic> productData,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/supplier/products',
        data: productData,
      );
      return response.data ?? {};
    } on DioException catch (e) {
      throw ApiException(
        message: _getDioErrorMessage(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> createSupplierVariant(
    Map<String, dynamic> variantData,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/supplier/variants',
        data: variantData,
      );
      return response.data ?? {};
    } on DioException catch (e) {
      throw ApiException(
        message: _getDioErrorMessage(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> createSupplierProductWithImages(
    Map<String, dynamic> fields,
    List<XFile> images,
  ) async {
    try {
      final formData = FormData.fromMap({
        ...fields,
        'images': await Future.wait(
          images.map((img) async {
            final bytes = await img.readAsBytes();
            final mimeType = mime.mime(img.path) ?? 'image/jpeg';
            return MultipartFile.fromBytes(
              bytes,
              filename: img.name,
              contentType: DioMediaType.parse(mimeType),
            );
          }),
        ),
      });

      final response = await _dio.post<Map<String, dynamic>>(
        '/supplier/products',
        data: formData,
      );
      return response.data ?? {};
    } on DioException catch (e) {
      throw ApiException(
        message: _getDioErrorMessage(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  // -------------------------------------------------------------------------
  // Admin endpoints
  // -------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchPendingSuppliers() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/admin/suppliers/pending',
      );
      return (response.data ?? []).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw ApiException(
        message: _getDioErrorMessage(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<void> verifySupplier(String supplierId) async {
    try {
      await _dio.patch('/admin/suppliers/$supplierId/verify', data: {});
    } on DioException catch (e) {
      throw ApiException(
        message: _getDioErrorMessage(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<void> rejectSupplier(String supplierId) async {
    try {
      await _dio.patch('/admin/suppliers/$supplierId/reject', data: {});
    } on DioException catch (e) {
      throw ApiException(
        message: _getDioErrorMessage(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  // -------------------------------------------------------------------------
  // Health check
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>?> checkHealth() async {
    try {
      debugPrint('📡 Checking health at /health');
      final response = await _dio.get<Map<String, dynamic>>('/health');
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      debugPrint('❌ Health check failed: $e');
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // Generic methods
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>> get(String path) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(path);
      return response.data ?? {};
    } on DioException catch (e) {
      throw ApiException(
        message: _getDioErrorMessage(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path, data: data);
      return response.data ?? {};
    } on DioException catch (e) {
      throw ApiException(
        message: _getDioErrorMessage(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(path, data: data);
      return response.data ?? {};
    } on DioException catch (e) {
      throw ApiException(
        message: _getDioErrorMessage(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  // -------------------------------------------------------------------------
  // Error helpers
  // -------------------------------------------------------------------------

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

  static String? _extractResponseError(Object? data) {
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
      if (message is List && message.isNotEmpty) {
        return message.map((e) => e.toString()).join(', ');
      }
    }
    return null;
  }

  void close() {
    _dio.close();
    debugPrint('🔌 ApiService closed');
  }
}

// -------------------------------------------------------------------------
// Interceptors
// -------------------------------------------------------------------------

class _UserIdInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final userId = await UserStore.getUserId();
      if (userId != null && userId.isNotEmpty) {
        options.headers['x-user-id'] = userId;
        debugPrint('🔑 x-user-id header added: $userId');
      } else {
        debugPrint('⚠️ No user ID found – x-user-id header not added');
      }
    } catch (e) {
      debugPrint('❌ Failed to read user ID: $e');
    }
    handler.next(options);
  }
}

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
    final responseStr = response.data.toString().replaceAll('\n', ' ');
    final truncated = responseStr.length > 200
        ? '${responseStr.substring(0, 200)}...'
        : responseStr;
    debugPrint(
      '📥 [${response.statusCode}] ${response.requestOptions.uri}\n'
      'Response: $truncated',
    );
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('❌ [Error] ${err.requestOptions.uri}\n$err');
    super.onError(err, handler);
  }
}

class _AuthInterceptor extends Interceptor {
  final ApiService _apiService;

  _AuthInterceptor(this._apiService);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_apiService.bearerToken != null) {
      options.headers['Authorization'] = 'Bearer ${_apiService.bearerToken}';
      debugPrint('🔐 Bearer token injected');
    }
    super.onRequest(options, handler);
  }
}

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
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
