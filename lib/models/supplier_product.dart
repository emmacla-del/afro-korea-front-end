class SupplierProduct {
  final String id;
  final String name;
  final String sku;
  final double price;
  final String currency;
  final int stock;
  final String poolStatus;
  final bool isActive;
  final DateTime createdAt;

  const SupplierProduct({
    required this.id,
    required this.name,
    required this.sku,
    required this.price,
    required this.currency,
    required this.stock,
    required this.poolStatus,
    required this.isActive,
    required this.createdAt,
  });

  factory SupplierProduct.fromJson(Map<String, dynamic> json) {
    return SupplierProduct(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      sku: (json['sku'] ?? '').toString(),
      price: _asDouble(json['price']) ?? 0.0,
      currency: (json['currency'] ?? '').toString(),
      stock: _asInt(json['stock']) ?? 0,
      poolStatus: (json['poolStatus'] ?? '').toString(),
      isActive: _asBool(json['isActive']) ?? true,
      createdAt: _asDateTime(json['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class SupplierProductsPageResponse {
  final List<SupplierProduct> items;
  final int page;
  final int pageSize;
  final int total;

  const SupplierProductsPageResponse({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  factory SupplierProductsPageResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((e) => SupplierProduct.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <SupplierProduct>[];

    return SupplierProductsPageResponse(
      items: items,
      page: _asInt(json['page']) ?? 1,
      pageSize: _asInt(json['pageSize']) ?? items.length,
      total: _asInt(json['total']) ?? items.length,
    );
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _asDouble(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

bool? _asBool(Object? value) {
  if (value is bool) return value;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true') return true;
    if (normalized == 'false') return false;
  }
  return null;
}

DateTime? _asDateTime(Object? value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

