class SupplierOrderItem {
  final String productName;
  final int quantity;
  final double unitPrice;

  const SupplierOrderItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  factory SupplierOrderItem.fromJson(Map<String, dynamic> json) {
    final variant = _asMap(json['variant']);
    final variantProduct = variant == null ? null : _asMap(variant['product']);

    return SupplierOrderItem(
      productName:
          _asString(json['productName']) ??
          _asString(json['name']) ??
          _asString(json['title']) ??
          _asString(variantProduct?['title']) ??
          _asString(json['variantId']) ??
          'Unknown item',
      quantity: _asInt(json['quantity']) ?? _asInt(json['qty']) ?? 0,
      unitPrice:
          _asDouble(json['unitPrice']) ??
          _asDouble(json['unitPriceXaf']) ??
          0.0,
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

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}
