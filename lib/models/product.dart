import 'package:flutter/foundation.dart';

@immutable
class Product {
  final String id;
  final String supplierId;
  final String title;
  final String? description;
  final String? category;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? supplier;
  final List<Map<String, dynamic>>? variants;
  final List<String>? images;

  // Convenience getters
  double? get price => variants?.isNotEmpty == true
      ? variants!.first['unitPriceXaf']?.toDouble()
      : null;

  String get currency => 'XAF';

  String get name => title;

  // NEW: Check if product has an active team deal
  bool get hasActiveTeamDeal {
    if (variants == null) return false;
    for (final variant in variants!) {
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

  // NEW: Get the team price from the first team deal found
  double? get teamPrice {
    if (variants == null) return null;
    for (final variant in variants!) {
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

  const Product({
    required this.id,
    required this.supplierId,
    required this.title,
    this.description,
    this.category,
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

  String get formattedPrice {
    if (price == null) return 'N/A';
    return '${price!.toStringAsFixed(0)} $currency';
  }

  String get formattedDate {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  @override
  String toString() => 'Product(id: $id, title: $title)';
}
