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
    return SupplierOrderItem(
      productName: (json['productName'] ?? '').toString(),
      quantity: _asInt(json['quantity']) ?? 0,
      unitPrice: _asDouble(json['unitPrice']) ?? 0.0,
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

