import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart'; // for XFile

import '../models/supplier_order.dart';
import '../models/supplier_product.dart';
import '../services/api_service.dart' as api_service;
import '../services/user_store.dart';

class SupplierApi {
  static const String _baseUrl = 'https://afro-korea-pool-server.onrender.com';

  Future<SupplierProductSummary> getProductSummary() async {
    try {
      final json = await api_service.ApiService.instance
          .getSupplierProductSummary();
      return SupplierProductSummary.fromJson(json);
    } on api_service.ApiException catch (err) {
      throw _mapApiServiceException(err);
    }
  }

  Future<SupplierPurchaseOrderSummary> getOrderSummary() async {
    try {
      final json = await api_service.ApiService.instance
          .getSupplierPurchaseOrdersSummary();
      return SupplierPurchaseOrderSummary.fromJson(json);
    } on api_service.ApiException catch (err) {
      throw _mapApiServiceException(err);
    }
  }

  Future<SupplierLatestCatalogImport> getLastCatalogImport() async {
    try {
      final json = await api_service.ApiService.instance
          .getLatestCatalogImport();
      return SupplierLatestCatalogImport.fromJson(json);
    } on api_service.ApiException catch (err) {
      throw _mapApiServiceException(err);
    }
  }

  Future<SupplierProductsPageResponse> getSupplierProducts({
    required int page,
    required int pageSize,
  }) async {
    final json = await _getJson(
      '/supplier/products',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return _parseSupplierProductsResponse(json, page: page, pageSize: pageSize);
  }

  Future<SupplierOrdersPageResponse> getSupplierOrders({
    required int page,
    required int pageSize,
  }) async {
    final json = await _getJson(
      '/supplier/purchase-orders',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return _parseSupplierOrdersResponse(json, page: page, pageSize: pageSize);
  }

  Future<SupplierOrderShipResult> markOrderAsShipped(String orderId) async {
    try {
      final json = await api_service.ApiService.instance.post(
        '/supplier/purchase-orders/$orderId/ship',
        data: const {},
      );
      return SupplierOrderShipResult.fromJson(json);
    } on api_service.ApiException catch (err) {
      throw _mapApiServiceException(err);
    }
  }

  Future<String> createProduct({
    required String name,
    String? description,
  }) async {
    try {
      final json = await api_service.ApiService.instance.createSupplierProduct({
        'product_name': name,
        if (description != null && description.isNotEmpty)
          'description': description,
      });

      final id = (json['id'] ?? '').toString();
      if (id.isEmpty) {
        throw ApiException(
          statusCode: 200,
          reasonPhrase: 'OK',
          body: json.toString(),
          message: 'Missing product id in response',
        );
      }
      return id;
    } on api_service.ApiException catch (err) {
      throw _mapApiServiceException(err);
    }
  }

  Future<void> createVariant({
    required String productId,
    required String sku,
    required double price,
    required int stock,
  }) async {
    try {
      await api_service.ApiService.instance.createSupplierVariant({
        'productId': productId,
        'sku': sku,
        'unitPriceXaf': price.round(),
        'thresholdQty': stock,
      });
    } on api_service.ApiException catch (err) {
      throw _mapApiServiceException(err);
    }
  }

  /// Create a product with multiple images (multipart request)
  Future<Map<String, dynamic>> createProductWithImages({
    required String name,
    String? description,
    required String sku,
    required double price,
    required int stock,
    required String currency,
    required List<XFile> images,
  }) async {
    try {
      final fields = {
        'product_name': name,
        if (description != null && description.isNotEmpty)
          'description': description,
        'sku': sku,
        'price': price.toString(),
        'stock': stock.toString(),
        'currency': currency,
      };
      final result = await api_service.ApiService.instance
          .createSupplierProductWithImages(fields, images);
      return result;
    } on api_service.ApiException catch (err) {
      throw _mapApiServiceException(err);
    }
  }

  Future<SupplierProduct> patchProduct({
    required String id,
    String? name,
    double? price,
    int? stock,
    bool? isActive,
  }) async {
    final body = <String, Object?>{};
    if (name != null) body['name'] = name;
    if (price != null) body['price'] = price;
    if (stock != null) body['stock'] = stock;
    if (isActive != null) body['isActive'] = isActive;

    final json = await _patchJson('/supplier/products/$id', body: body);
    if (json is! Map) {
      throw ApiException(
        statusCode: 200,
        reasonPhrase: 'OK',
        body: json?.toString() ?? 'null',
        message: 'Unexpected response for patch product',
      );
    }
    return SupplierProduct.fromJson(Map<String, dynamic>.from(json));
  }

  Future<SupplierProduct> patchProductPoolStatus({
    required String id,
    required String poolStatus,
  }) async {
    final json = await _patchJson(
      '/supplier/products/$id/status',
      body: {'poolStatus': poolStatus},
    );

    if (json is! Map) {
      throw ApiException(
        statusCode: 200,
        reasonPhrase: 'OK',
        body: json?.toString() ?? 'null',
        message: 'Unexpected response for patch product status',
      );
    }

    return SupplierProduct.fromJson(Map<String, dynamic>.from(json));
  }

  // ✅ NEW: Delete a product
  Future<void> deleteProduct(String id) async {
    try {
      await api_service.ApiService.instance.delete('/supplier/products/$id');
    } on api_service.ApiException catch (err) {
      throw _mapApiServiceException(err);
    }
  }

  // -------------------------------------------------------------------------
  // Internal HTTP helpers
  // -------------------------------------------------------------------------
  Future<Object?> _getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final uri = _buildUri(path, queryParameters);
    final headers = await _buildHeaders();

    try {
      final response = await http.get(uri, headers: headers).timeout(timeout);
      return _decodeJsonResponse(response);
    } catch (err) {
      if (err is ApiException) rethrow;
      throw ApiException(
        statusCode: 0,
        reasonPhrase: 'Network Error',
        body: '',
        message: err.toString(),
      );
    }
  }

  Future<Object?> _patchJson(
    String path, {
    required Object body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final uri = _buildUri(path, null);
    final headers = await _buildHeaders();

    try {
      final response = await http
          .patch(uri, headers: headers, body: jsonEncode(body))
          .timeout(timeout);
      return _decodeJsonResponse(response);
    } catch (err) {
      if (err is ApiException) rethrow;
      throw ApiException(
        statusCode: 0,
        reasonPhrase: 'Network Error',
        body: '',
        message: err.toString(),
      );
    }
  }

  Uri _buildUri(String path, Map<String, dynamic>? queryParameters) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse(_baseUrl).replace(
      path: normalizedPath,
      queryParameters: queryParameters == null
          ? null
          : _stringifyQuery(queryParameters),
    );
  }

  Future<Map<String, String>> _buildHeaders() async {
    final userId = await UserStore.getUserId();
    final bearerToken = api_service.ApiService.instance.bearerToken;

    return <String, String>{
      'accept': 'application/json',
      'content-type': 'application/json; charset=utf-8',
      if (userId != null && userId.isNotEmpty) 'x-user-id': userId,
      if (bearerToken != null && bearerToken.isNotEmpty)
        'Authorization': 'Bearer $bearerToken',
    };
  }
}

// -------------------------------------------------------------------------
// Custom exception for this API wrapper
// -------------------------------------------------------------------------
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

ApiException _mapApiServiceException(api_service.ApiException error) {
  return ApiException(
    statusCode: error.statusCode ?? 0,
    reasonPhrase: null,
    body: '',
    message: error.message,
  );
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

Map<String, String> _stringifyQuery(Map<String, dynamic> queryParameters) {
  final result = <String, String>{};
  for (final entry in queryParameters.entries) {
    final value = entry.value;
    if (value == null) continue;
    result[entry.key] = value.toString();
  }
  return result;
}

// -------------------------------------------------------------------------
// Response models (unchanged)
// -------------------------------------------------------------------------
class SupplierProductSummary {
  final int total;
  final int openPool;

  const SupplierProductSummary({required this.total, required this.openPool});

  factory SupplierProductSummary.fromJson(Map<String, dynamic> json) {
    return SupplierProductSummary(
      total: _asInt(json['total']) ?? 0,
      openPool: _asInt(json['openPool']) ?? 0,
    );
  }
}

class SupplierPurchaseOrderSummary {
  final int pending;
  final int shipped;

  const SupplierPurchaseOrderSummary({
    required this.pending,
    required this.shipped,
  });

  factory SupplierPurchaseOrderSummary.fromJson(Map<String, dynamic> json) {
    return SupplierPurchaseOrderSummary(
      pending: _asInt(json['pending']) ?? 0,
      shipped: _asInt(json['shipped']) ?? 0,
    );
  }
}

class SupplierLatestCatalogImport {
  final DateTime? lastImportedAt;

  const SupplierLatestCatalogImport({required this.lastImportedAt});

  factory SupplierLatestCatalogImport.fromJson(Map<String, dynamic> json) {
    final raw = json['lastImportedAt'];
    if (raw == null) {
      return const SupplierLatestCatalogImport(lastImportedAt: null);
    }
    if (raw is String) {
      return SupplierLatestCatalogImport(
        lastImportedAt: DateTime.tryParse(raw),
      );
    }
    return const SupplierLatestCatalogImport(lastImportedAt: null);
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

SupplierProductsPageResponse _parseSupplierProductsResponse(
  Object? json, {
  required int page,
  required int pageSize,
}) {
  if (json is Map) {
    return SupplierProductsPageResponse.fromJson(
      Map<String, dynamic>.from(json),
    );
  }

  if (json is List) {
    final parsedItems = json
        .whereType<Map>()
        .map((e) => SupplierProduct.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return _paginateProducts(parsedItems, page: page, pageSize: pageSize);
  }

  throw ApiException(
    statusCode: 200,
    reasonPhrase: 'OK',
    body: json?.toString() ?? 'null',
    message: 'Unexpected response for supplier products',
  );
}

SupplierOrdersPageResponse _parseSupplierOrdersResponse(
  Object? json, {
  required int page,
  required int pageSize,
}) {
  if (json is Map) {
    return SupplierOrdersPageResponse.fromJson(Map<String, dynamic>.from(json));
  }

  if (json is List) {
    final parsedItems = json
        .whereType<Map>()
        .map((e) => SupplierOrder.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return _paginateOrders(parsedItems, page: page, pageSize: pageSize);
  }

  throw ApiException(
    statusCode: 200,
    reasonPhrase: 'OK',
    body: json?.toString() ?? 'null',
    message: 'Unexpected response for supplier purchase orders',
  );
}

SupplierProductsPageResponse _paginateProducts(
  List<SupplierProduct> allItems, {
  required int page,
  required int pageSize,
}) {
  final total = allItems.length;
  final start = ((page <= 1 ? 1 : page) - 1) * pageSize;
  final endExclusive = (start + pageSize > total) ? total : start + pageSize;
  final items = (start >= 0 && start < total)
      ? allItems.sublist(start, endExclusive)
      : <SupplierProduct>[];

  return SupplierProductsPageResponse(
    items: items,
    page: page <= 1 ? 1 : page,
    pageSize: pageSize,
    total: total,
  );
}

SupplierOrdersPageResponse _paginateOrders(
  List<SupplierOrder> allItems, {
  required int page,
  required int pageSize,
}) {
  final total = allItems.length;
  final start = ((page <= 1 ? 1 : page) - 1) * pageSize;
  final endExclusive = (start + pageSize > total) ? total : start + pageSize;
  final items = (start >= 0 && start < total)
      ? allItems.sublist(start, endExclusive)
      : <SupplierOrder>[];

  return SupplierOrdersPageResponse(
    items: items,
    page: page <= 1 ? 1 : page,
    pageSize: pageSize,
    total: total,
  );
}
