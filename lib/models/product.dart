import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'product_category.dart'; // 👈 make sure this file exists

@immutable
class Product {
  final String id;
  final String supplierId;
  final String title;
  final String? description;
  final String? category; // free‑text category
  final ProductCategory? catEnum; // 👈 new enum field
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
      catEnum: ProductCategoryExtension.fromRaw(json['catEnum']), // parse enum
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

  // Convenience getters
  String get name => title; // for compatibility

  // Solo price from first variant
  double? get price {
    if (variants == null || variants!.isEmpty) return null;
    return variants!.first['unitPriceXaf']?.toDouble();
  }

  String get currency => 'XAF';

  // Team deal properties
  bool get hasActiveTeamDeal {
    for (final variant in variants ?? []) {
      final pools = variant['pools'] as List?;
      if (pools != null && pools.isNotEmpty) {
        final pool = pools.first as Map<String, dynamic>?;
        if (pool != null &&
            pool['dealType'] == 'TEAM_DEAL' &&
            pool['status'] == 'OPEN') {
          return true;
        }
      }
    }
    return false;
  }

  double? get teamPrice {
    for (final variant in variants ?? []) {
      final pools = variant['pools'] as List?;
      if (pools != null && pools.isNotEmpty) {
        final pool = pools.first as Map<String, dynamic>?;
        if (pool != null && pool['dealType'] == 'TEAM_DEAL') {
          final price = pool['teamPrice'];
          if (price != null) return price.toDouble();
        }
      }
    }
    return null;
  }

  int? get currentBuyers {
    for (final variant in variants ?? []) {
      final pools = variant['pools'] as List?;
      if (pools != null && pools.isNotEmpty) {
        final pool = pools.first as Map<String, dynamic>?;
        if (pool?['dealType'] == 'TEAM_DEAL') {
          return pool?['currentBuyers'] as int?;
        }
      }
    }
    return null;
  }

  int? get minBuyers {
    for (final variant in variants ?? []) {
      final pools = variant['pools'] as List?;
      if (pools != null && pools.isNotEmpty) {
        final pool = pools.first as Map<String, dynamic>?;
        if (pool?['dealType'] == 'TEAM_DEAL') {
          return pool?['minBuyers'] as int?;
        }
      }
    }
    return null;
  }

  String? get activeTeamDealPoolId {
    for (final variant in variants ?? []) {
      final pools = variant['pools'] as List?;
      if (pools != null && pools.isNotEmpty) {
        final pool = pools.first as Map<String, dynamic>?;
        if (pool != null &&
            pool['dealType'] == 'TEAM_DEAL' &&
            pool['status'] == 'OPEN') {
          return pool['id'] as String?;
        }
      }
    }
    return null;
  }

  int get discountPercent {
    final solo = price;
    final group = teamPrice;
    if (solo == null || group == null || group >= solo) return 0;
    return ((solo - group) / solo * 100).round();
  }

  // Display helpers
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
