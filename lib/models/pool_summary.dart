class PoolSummary {
  final String id;
  final String status;
  final int committedQty;
  final int thresholdQty;
  final DateTime? deadlineAt;
  final DateTime? paymentWindowEndsAt;

  const PoolSummary({
    required this.id,
    required this.status,
    required this.committedQty,
    required this.thresholdQty,
    required this.deadlineAt,
    required this.paymentWindowEndsAt,
  });

  factory PoolSummary.fromApiJson(Map<String, dynamic> json) {
    return PoolSummary(
      id: (json['id'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      committedQty: _asInt(json['committedQty']) ?? 0,
      thresholdQty: _asInt(json['thresholdQtySnapshot']) ?? 0,
      deadlineAt: _asDateTime(json['deadlineAt']),
      paymentWindowEndsAt: _asDateTime(json['paymentWindowEndsAt']),
    );
  }

  double get progress {
    if (thresholdQty <= 0) return 0.0;
    final raw = committedQty / thresholdQty;
    if (raw < 0) return 0.0;
    if (raw > 1) return 1.0;
    return raw;
  }

  /// Serialize PoolSummary back to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'committedQty': committedQty,
      'thresholdQtySnapshot': thresholdQty,
      'deadlineAt': deadlineAt?.toIso8601String(),
      'paymentWindowEndsAt': paymentWindowEndsAt?.toIso8601String(),
    };
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

DateTime? _asDateTime(Object? value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
