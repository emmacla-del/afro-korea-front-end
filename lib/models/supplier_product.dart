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
    final variants = _asList(json['variants']);
    final firstVariant = variants.isNotEmpty ? _asMap(variants.first) : null;
    final pools = firstVariant == null
        ? const <Object?>[]
        : _asList(firstVariant['pools']);
    final firstPool = pools.isNotEmpty ? _asMap(pools.first) : null;

    final title =
        _asString(json['name']) ??
        _asString(json['product_name']) ??
        _asString(json['title']) ??
        '';
    final sku = _asString(json['sku']) ?? _asString(firstVariant?['sku']) ?? '';
    final poolStatus =
        _asString(json['poolStatus']) ??
        _asString(firstPool?['status']) ??
        'CLOSED';
    final currency = _asString(json['currency']) ?? 'XAF';
    final isProductActive = _asBool(json['isActive']) ?? true;
    final isVariantActive = _asBool(firstVariant?['isActive']) ?? true;

    return SupplierProduct(
      id: (json['id'] ?? '').toString(),
      name: title,
      sku: sku,
      price:
          _asDouble(json['price']) ??
          _asDouble(firstVariant?['unitPriceXaf']) ??
          0.0,
      currency: currency,
      stock:
          _asInt(json['stock']) ?? _asInt(firstVariant?['thresholdQty']) ?? 0,
      poolStatus: poolStatus,
      isActive: isProductActive && isVariantActive,
      createdAt:
          _asDateTime(json['createdAt']) ??
          _asDateTime(firstVariant?['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
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
    final rawItems = json['items'] ?? json['data'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (e) => SupplierProduct.fromJson(Map<String, dynamic>.from(e)),
              )
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

String? _asString(Object? value) {
  if (value == null) return null;
  final v = value.toString().trim();
  if (v.isEmpty) return null;
  return v;
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

List<Object?> _asList(Object? value) {
  if (value is List) return value;
  return const <Object?>[];
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}
