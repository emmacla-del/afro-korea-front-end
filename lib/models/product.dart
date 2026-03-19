import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'product_category.dart';

@immutable
class Product {
  final String id;
  final String supplierId;
  final String title;
  final String? description;
  final String? category;
  final ProductCategory? catEnum;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? supplier;
  final List<Map<String, dynamic>>? variants;
  final List<String>? images;

  const Product({
    required this.id,
    required this.supplierId,
    required this.title,
    this.description,
    this.category,
    this.catEnum,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.supplier,
    this.variants,
    this.images,
  });

  factory Product.fromBackendApi(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      supplierId: json['supplierId'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      category: json['category'],
      catEnum: ProductCategoryExtension.fromRaw(json['catEnum']),
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
      supplier: json['supplier'],
      variants: json['variants'] != null
          ? List<Map<String, dynamic>>.from(json['variants'])
          : null,
      images: json['images'] != null ? List<String>.from(json['images']) : null,
    );
  }

  // --- Convenience Getters ---
  String get name => title;
  String get currency => 'XAF';

  // Solo price from first variant
  double? get price {
    if (variants == null || variants!.isEmpty) return null;
    return variants!.first['unitPriceXaf']?.toDouble();
  }

  // --- Team Deal Properties (all refer to the first active pool) ---

  /// Returns the first active TEAM_DEAL pool, or null if none.
  Map<String, dynamic>? get _activePool {
    for (final variant in variants ?? []) {
      final pools = variant['pools'] as List?;
      if (pools != null && pools.isNotEmpty) {
        for (final pool in pools) {
          if (pool['dealType'] == 'TEAM_DEAL' && pool['status'] == 'OPEN') {
            return pool as Map<String, dynamic>;
          }
        }
      }
    }
    return null;
  }

  /// Whether the product has an active team deal.
  bool get hasActiveTeamDeal => _activePool != null;

  /// Team price from the active pool.
  double? get teamPrice => _activePool?['teamPrice']?.toDouble();

  /// Current number of buyers from the active pool.
  int? get currentBuyers => _activePool?['currentBuyers'] as int?;

  /// Minimum buyers required from the active pool.
  int? get minBuyers => _activePool?['minBuyers'] as int?;

  /// ID of the active team deal pool.
  String? get activeTeamDealPoolId => _activePool?['id'] as String?;

  /// Expiry date of the active team deal.
  DateTime? get expiryDate {
    final pool = _activePool;
    if (pool == null) return null;
    // Try different possible field names; your backend uses 'deadlineAt'
    final dateStr =
        pool['deadlineAt'] ??
        pool['endTime'] ??
        pool['expiryDate'] ??
        pool['expiresAt'];
    if (dateStr != null) return DateTime.parse(dateStr);
    return null;
  }

  /// Remaining time until the deal expires.
  Duration get timeLeft {
    final expiry = expiryDate;
    if (expiry == null) return Duration.zero;
    final diff = expiry.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Whether the active team deal has expired.
  bool get isExpired => timeLeft.inSeconds <= 0;

  /// Discount percentage based on solo and team prices.
  int get discountPercent {
    final solo = price;
    final group = teamPrice;
    if (solo == null || group == null || group >= solo) return 0;
    return ((solo - group) / solo * 100).round();
  }

  /// 👇 NEW: Neighbourhood name of the active pool (if restricted)
  String? get activePoolNeighbourhoodName =>
      _activePool?['neighbourhood']?['name'] as String?;

  // --- Display Helpers ---
  String get displayCategory =>
      catEnum?.displayName ?? category ?? 'No category';

  String get formattedPrice {
    if (price == null) return 'N/A';
    return '${price!.toStringAsFixed(0)} $currency';
  }

  String get formattedDate => DateFormat('MMM d, yyyy').format(createdAt);

  @override
  String toString() => 'Product(id: $id, title: $title)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
