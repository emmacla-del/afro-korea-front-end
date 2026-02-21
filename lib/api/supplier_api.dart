import 'api_client.dart';
import '../models/supplier_product.dart';
import '../models/supplier_order.dart';
import '../services/user_store.dart';

class SupplierApi {
  final ApiClient _client;

  SupplierApi({ApiClient? client}) : _client = client ?? ApiClient(userIdProvider: () => UserStore.getUserId());

  Future<SupplierProductSummary> getProductSummary() async {
    final json = await _client.get('/supplier/products/summary');
    if (json is! Map) {
      throw ApiException(
        statusCode: 200,
        reasonPhrase: 'OK',
        body: json?.toString() ?? 'null',
        message: 'Unexpected response for product summary',
      );
    }
    return SupplierProductSummary.fromJson(Map<String, dynamic>.from(json));
  }

  Future<SupplierPurchaseOrderSummary> getOrderSummary() async {
    final json = await _client.get('/supplier/purchase-orders/summary');
    if (json is! Map) {
      throw ApiException(
        statusCode: 200,
        reasonPhrase: 'OK',
        body: json?.toString() ?? 'null',
        message: 'Unexpected response for purchase order summary',
      );
    }
    return SupplierPurchaseOrderSummary.fromJson(
      Map<String, dynamic>.from(json),
    );
  }

  Future<SupplierLatestCatalogImport> getLastCatalogImport() async {
    final json = await _client.get('/supplier/catalog-imports/latest');
    if (json is! Map) {
      throw ApiException(
        statusCode: 200,
        reasonPhrase: 'OK',
        body: json?.toString() ?? 'null',
        message: 'Unexpected response for latest catalog import',
      );
    }
    return SupplierLatestCatalogImport.fromJson(Map<String, dynamic>.from(json));
  }

  Future<SupplierProductsPageResponse> getSupplierProducts({
    required int page,
    required int pageSize,
  }) async {
    final json = await _client.get(
      '/supplier/products',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );

    if (json is! Map) {
      throw ApiException(
        statusCode: 200,
        reasonPhrase: 'OK',
        body: json?.toString() ?? 'null',
        message: 'Unexpected response for supplier products',
      );
    }

    return SupplierProductsPageResponse.fromJson(Map<String, dynamic>.from(json));
  }

  Future<SupplierOrdersPageResponse> getSupplierOrders({
    required int page,
    required int pageSize,
  }) async {
    final json = await _client.get(
      '/supplier/purchase-orders',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );

    if (json is! Map) {
      throw ApiException(
        statusCode: 200,
        reasonPhrase: 'OK',
        body: json?.toString() ?? 'null',
        message: 'Unexpected response for supplier purchase orders',
      );
    }

    return SupplierOrdersPageResponse.fromJson(Map<String, dynamic>.from(json));
  }

  Future<SupplierOrderShipResult> markOrderAsShipped(String orderId) async {
    final json = await _client.patch(
      '/supplier/purchase-orders/$orderId/ship',
      body: const {},
    );

    if (json is! Map) {
      throw ApiException(
        statusCode: 200,
        reasonPhrase: 'OK',
        body: json?.toString() ?? 'null',
        message: 'Unexpected response for ship purchase order',
      );
    }

    return SupplierOrderShipResult.fromJson(Map<String, dynamic>.from(json));
  }

  Future<String> createProduct({
    required String name,
    String? description,
  }) async {
    final json = await _client.post(
      '/supplier/products',
      body: {
        'product_name': name,
        ...?(description == null ? null : {'description': description}),
      },
    );

    if (json is! Map) {
      throw ApiException(
        statusCode: 200,
        reasonPhrase: 'OK',
        body: json?.toString() ?? 'null',
        message: 'Unexpected response for create product',
      );
    }

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
  }

  Future<void> createVariant({
    required String productId,
    required String sku,
    required double price,
    required int stock,
  }) async {
    final json = await _client.post(
      '/supplier/variants',
      body: {
        'productId': productId,
        'sku': sku,
        'unitPriceXaf': price.round(),
        'thresholdQty': stock,
      },
    );

    if (json != null && json is! Map) {
      throw ApiException(
        statusCode: 200,
        reasonPhrase: 'OK',
        body: json.toString(),
        message: 'Unexpected response for create variant',
      );
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

    final json = await _client.patch(
      '/supplier/products/$id',
      body: body,
    );

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
    final json = await _client.patch(
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
}

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
      return SupplierLatestCatalogImport(lastImportedAt: DateTime.tryParse(raw));
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
