import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime_type/mime_type.dart' as mime;
import '../models/product.dart';
import '../models/supplier_product.dart';
import '../models/neighbourhood.dart';
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
      validateStatus: (status) => status != null && status < 500,
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

  void clearBearerToken() => setBearerToken(null);

  String? get bearerToken => _bearerToken;

  // -------------------------------------------------------------------------
  // Authentication
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>> register(
    String phone,
    String password, {
    String role = 'CUSTOMER',
    Map<String, dynamic>? supplierData,
    String? name,
    String? referralCode,
    String? neighbourhoodId,
  }) async {
    try {
      final body = <String, dynamic>{
        'phone': phone.trim(),
        'password': password,
        'role': role.trim().toUpperCase(),
        if (name != null && name.isNotEmpty) 'name': name,
        if (referralCode != null && referralCode.isNotEmpty)
          'referralCode': referralCode,
        if (neighbourhoodId != null && neighbourhoodId.isNotEmpty)
          'neighbourhoodId': neighbourhoodId,
        if (supplierData != null) 'supplierData': supplierData,
      };
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: body,
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
  // User Profile
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      debugPrint('📡 Fetching user profile from /user/profile');
      final response = await _dio.get<Map<String, dynamic>>('/user/profile');
      if (response.statusCode == 200) return response.data ?? {};
      throw ApiException(
        message: 'Failed to fetch user profile',
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

  Future<void> updateProfile({String? neighbourhoodId}) async {
    try {
      final data = <String, dynamic>{
        if (neighbourhoodId != null) 'neighbourhoodId': neighbourhoodId,
      };
      await _dio.patch('/user/profile', data: data);
      debugPrint('✅ Profile updated');
    } on DioException catch (e) {
      throw ApiException(
        message: _getDioErrorMessage(e),
        statusCode: e.response?.statusCode,
        originalError: e,
      );
    }
  }

  // -------------------------------------------------------------------------
  // Neighbourhood
  // -------------------------------------------------------------------------

  Future<List<Neighbourhood>> fetchNeighbourhoods() async {
    try {
      debugPrint('📡 Fetching neighbourhoods from /neighbourhoods');
      final response = await _dio.get<List<dynamic>>('/neighbourhoods');
      if (response.statusCode == 200) {
        return (response.data ?? [])
            .map((j) => Neighbourhood.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      throw ApiException(
        message: 'Failed to fetch neighbourhoods',
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
  // Customer / Products
  // -------------------------------------------------------------------------

  Future<List<Product>> fetchProducts({bool nearMe = false}) async {
    try {
      debugPrint('📡 Fetching products (nearMe: $nearMe)');
      final response = await _dio.get<List<dynamic>>(
        '/products',
        queryParameters: {'nearMe': nearMe},
      );
      if (response.statusCode == 200) {
        final products = (response.data ?? [])
            .map((item) {
              try {
                return Product.fromBackendApi(
                  item is Map<String, dynamic> ? item : {},
                );
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
      throw ApiException(
        message: _getDioErrorMessage(e),
        statusCode: e.response?.statusCode,
        originalError: e,
        stackTrace: StackTrace.current,
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

  Future<Product> fetchProductById(String productId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/products/$productId',
      );
      if (response.statusCode == 200) {
        return Product.fromBackendApi(response.data ?? {});
      }
      throw ApiException(
        message: 'Failed to fetch product',
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

  Future<Map<String, dynamic>> fetchPool(String poolId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/pools/$poolId');
      if (response.statusCode == 200 && response.data != null) {
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
      final response = await _dio.post<Map<String, dynamic>>(
        '/pools/$poolId/commit',
        data: body,
      );
      if (response.statusCode == 200 && response.data != null) {
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
  // Team Deals
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>> createTeamDeal({
    required String variantId,
    required int teamPrice,
    required int minBuyers,
    String? neighbourhoodId,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/pools/team',
        data: {
          'variantId': variantId,
          'teamPrice': teamPrice,
          'minBuyers': minBuyers,
          if (neighbourhoodId != null) 'neighbourhoodId': neighbourhoodId,
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
      final response = await _dio.get<List<dynamic>>('/pools/team');
      if (response.statusCode == 200) {
        return (response.data ?? []).cast<Map<String, dynamic>>();
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
  // Check-in
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>> checkIn() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>('/checkin');
      return response.data ?? {};
    } on DioException catch (e) {
      throw ApiException(
        message: _getDioErrorMessage(e),
        statusCode: e.response?.statusCode,
        originalError: e,
      );
    }
  }

  Future<Map<String, dynamic>> getCheckinStreak() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/checkin/streak');
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
  // Referral
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>> generateReferralCode() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/referral/generate',
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

  Future<Map<String, dynamic>> getReferralStats() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/referral/stats');
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
      final response = await _dio.get<List<dynamic>>('/me/orders');
      if (response.statusCode == 200) {
        return (response.data ?? []).cast<Map<String, dynamic>>();
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
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data != null) {
        return response.data!;
      }
      if (response.statusCode == 401) {
        throw ApiException(
          message: 'Unauthorized: Token may be expired',
          statusCode: 401,
        );
      }
      if (response.statusCode == 400) {
        throw ApiException(
          message:
              'Validation error: ${response.data?['message'] ?? 'Invalid order data'}',
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
  // Supplier
  // -------------------------------------------------------------------------

  Future<List<SupplierProduct>> getSupplierProducts() async {
    try {
      final response = await _dio.get<List<dynamic>>('/supplier/products');
      if (response.statusCode == 200) {
        return (response.data ?? [])
            .map((j) => SupplierProduct.fromJson(j as Map<String, dynamic>))
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

  /// Submits a verification request for the current supplier.
  /// The backend sets verificationStatus to PENDING immediately;
  /// an admin then reviews and sets VERIFIED or REJECTED.
  Future<Map<String, dynamic>> requestSupplierVerification() async {
    try {
      debugPrint('📡 Requesting supplier verification');
      final response = await _dio.post<Map<String, dynamic>>(
        '/supplier/request-verification',
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data ?? {'message': 'Request submitted'};
      }
      throw ApiException(
        message:
            _extractResponseError(response.data) ??
            'Failed to submit verification request',
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
  // Admin
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

  /// Fetch all users for admin user management.
  Future<List<Map<String, dynamic>>> fetchAllUsers() async {
    try {
      debugPrint('📡 Fetching all users from /admin/users');
      final response = await _dio.get<List<dynamic>>('/admin/users');
      return (response.data ?? []).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw ApiException(
        message: _getDioErrorMessage(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Block a user by ID. Admin only.
  Future<void> blockUser(String userId) async {
    try {
      debugPrint('📡 Blocking user: $userId');
      await _dio.patch('/admin/users/$userId/block', data: {});
    } on DioException catch (e) {
      throw ApiException(
        message: _getDioErrorMessage(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Unblock a user by ID. Admin only.
  Future<void> unblockUser(String userId) async {
    try {
      debugPrint('📡 Unblocking user: $userId');
      await _dio.patch('/admin/users/$userId/unblock', data: {});
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
      final response = await _dio.get<Map<String, dynamic>>('/health');
      return response.statusCode == 200 ? response.data : null;
    } on DioException catch (e) {
      debugPrint('❌ Health check failed: $e');
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // Generic helpers
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

  Future<Map<String, dynamic>> delete(String path) async {
    try {
      final response = await _dio.delete<Map<String, dynamic>>(path);
      return response.data ?? {};
    } on DioException catch (e) {
      throw ApiException(
        message: _getDioErrorMessage(e),
        statusCode: e.response?.statusCode,
        originalError: e,
      );
    }
  }

  void close() {
    _dio.close();
    debugPrint('🔌 ApiService closed');
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
        return 'SSL certificate error.';
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
      if (message is String && message.trim().isNotEmpty) return message.trim();
      if (message is List && message.isNotEmpty) {
        return message.map((e) => e.toString()).join(', ');
      }
    }
    return null;
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
      }
    } catch (e) {
      debugPrint('❌ Failed to read user ID: $e');
    }
    handler.next(options);
  }
}

class _AuthInterceptor extends Interceptor {
  final ApiService _apiService;
  _AuthInterceptor(this._apiService);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_apiService.bearerToken != null) {
      options.headers['Authorization'] = 'Bearer ${_apiService.bearerToken}';
    }
    super.onRequest(options, handler);
  }
}

class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('📤 [${options.method}] ${options.uri}');
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final body = response.data.toString().replaceAll('\n', ' ');
    final preview = body.length > 200 ? '${body.substring(0, 200)}…' : body;
    debugPrint(
      '📥 [${response.statusCode}] ${response.requestOptions.uri} — $preview',
    );
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('❌ [Error] ${err.requestOptions.uri} — $err');
    super.onError(err, handler);
  }
}

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    switch (err.response?.statusCode) {
      case 401:
        debugPrint('🔓 401 Unauthorized');
      case 403:
        debugPrint('🚫 403 Forbidden');
      case 404:
        debugPrint('📭 404 Not Found');
      case 500:
        debugPrint('💥 500 Internal Server Error');
      case 503:
        debugPrint('🔧 503 Service Unavailable');
    }
    super.onError(err, handler);
  }
}
