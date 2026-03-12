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
              .map(
                (e) => SupplierOrderItem.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList()
        : <SupplierOrderItem>[];

    final events = _asList(json['events']);
    final shippedEvent = events
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .firstWhere(
          (e) =>
              (e['status'] ?? '').toString().trim().toUpperCase() == 'SHIPPED',
          orElse: () => const <String, dynamic>{},
        );

    final totalAmount =
        _asDouble(json['totalAmount']) ??
        _asDouble(json['amountXaf']) ??
        items.fold<double>(
          0,
          (sum, item) => sum + (item.quantity * item.unitPrice),
        );

    return SupplierOrder(
      id: (json['id'] ?? '').toString(),
      orderNumber:
          _asString(json['orderNumber']) ?? _buildOrderNumber(json['id']),
      buyerName:
          _asString(json['buyerName']) ??
          _asString(_asMap(json['directOrder'])?['userId']) ??
          '',
      status: _normalizeStatus((json['status'] ?? '').toString()),
      totalAmount: totalAmount,
      currency: _asString(json['currency']) ?? 'XAF',
      createdAt:
          _asDateTime(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      items: items,
      shippedAt:
          _asDateTime(json['shippedAt']) ??
          _asDateTime(shippedEvent['createdAt']),
    );
  }

  SupplierOrder copyWith({String? status, DateTime? shippedAt}) {
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
    final rawItems = json['items'] ?? json['data'];
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

  const SupplierOrderShipResult({
    required this.status,
    required this.shippedAt,
  });

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

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<Object?> _asList(Object? value) {
  if (value is List) return value;
  return const <Object?>[];
}

String? _asString(Object? value) {
  if (value == null) return null;
  final v = value.toString().trim();
  if (v.isEmpty) return null;
  return v;
}

String _buildOrderNumber(Object? idValue) {
  final id = _asString(idValue) ?? '';
  if (id.isEmpty) return '';
  final suffix = id.length <= 8 ? id : id.substring(0, 8);
  return 'PO-$suffix';
}

String _normalizeStatus(String raw) {
  final status = raw.trim().toUpperCase();
  switch (status) {
    case 'PENDING_SUPPLIER_CONFIRM':
    case 'CONFIRMED':
      return 'PENDING';
    case 'SHIPPED':
      return 'SHIPPED';
    case 'DELIVERED':
      return 'DELIVERED';
    case 'CANCELED':
      return 'CANCELED';
    default:
      return status.isEmpty ? 'UNKNOWN' : status;
  }
}
