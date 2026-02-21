import 'supplier_order_item.dart';

class SupplierOrder {
  final String id;
  final String orderNumber;
  final String buyerName;
  final String status;
  final double totalAmount;
  final String currency;
  final DateTime createdAt;
  final List<SupplierOrderItem> items;
  final DateTime? shippedAt;

  const SupplierOrder({
    required this.id,
    required this.orderNumber,
    required this.buyerName,
    required this.status,
    required this.totalAmount,
    required this.currency,
    required this.createdAt,
    required this.items,
    required this.shippedAt,
  });

  factory SupplierOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((e) => SupplierOrderItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <SupplierOrderItem>[];

    return SupplierOrder(
      id: (json['id'] ?? '').toString(),
      orderNumber: (json['orderNumber'] ?? '').toString(),
      buyerName: (json['buyerName'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      totalAmount: _asDouble(json['totalAmount']) ?? 0.0,
      currency: (json['currency'] ?? '').toString(),
      createdAt: _asDateTime(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      items: items,
      shippedAt: _asDateTime(json['shippedAt']),
    );
  }

  SupplierOrder copyWith({
    String? status,
    DateTime? shippedAt,
  }) {
    return SupplierOrder(
      id: id,
      orderNumber: orderNumber,
      buyerName: buyerName,
      status: status ?? this.status,
      totalAmount: totalAmount,
      currency: currency,
      createdAt: createdAt,
      items: items,
      shippedAt: shippedAt ?? this.shippedAt,
    );
  }
}

class SupplierOrdersPageResponse {
  final List<SupplierOrder> items;
  final int page;
  final int pageSize;
  final int total;

  const SupplierOrdersPageResponse({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  factory SupplierOrdersPageResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((e) => SupplierOrder.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <SupplierOrder>[];

    return SupplierOrdersPageResponse(
      items: items,
      page: _asInt(json['page']) ?? 1,
      pageSize: _asInt(json['pageSize']) ?? items.length,
      total: _asInt(json['total']) ?? items.length,
    );
  }
}

class SupplierOrderShipResult {
  final String status;
  final DateTime? shippedAt;

  const SupplierOrderShipResult({required this.status, required this.shippedAt});

  factory SupplierOrderShipResult.fromJson(Map<String, dynamic> json) {
    return SupplierOrderShipResult(
      status: (json['status'] ?? '').toString(),
      shippedAt: _asDateTime(json['shippedAt']),
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

DateTime? _asDateTime(Object? value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

