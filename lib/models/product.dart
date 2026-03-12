/*
PRODUCT MODEL FOR DUAL SUPPLY MARKETS - UNIFIED

FIELDS:
1. Basic: id, title, description, category, isActive
2. Pricing: priceXaf (double), currency
3. Supplier: supplierId, supplierName, supplierOrigin ('nigeria' or 'korea'), supplierCity, supplierCountry, supplierVerificationStatus
4. Images: List of image URLs
5. MOQ Pooling: moq (minimum order quantity), currentOrders, poolingDeadline, poolSummary
6. Logistics: estimatedDays (Nigeria: 3-7, Korea: 14-21), requiresCustoms (Korea only)
7. Timestamps: createdAt, updatedAt

FIXED: Issue #1 (merged product.dart + product_model.dart)
FIXED: Issue #21 (aligned with backend /products endpoint response)
UPDATED: Added supplierCountry and supplierVerificationStatus from backend
*/

import 'package:intl/intl.dart';
import 'pool_summary.dart';

class Product {
  // === IDs & Metadata ===
  final String id;
  final String title;
  final String? description;
  final String category;
  final bool isActive;

  // === Pricing ===
  final double priceXaf;
  final String currency;

  // === Supplier Info ===
  final String supplierId;
  final String supplierName;
  final String
  supplierOrigin; // 'nigeria' | 'korea' (derived, kept for backward compatibility)
  final String supplierCity;
  final String? supplierCountry; // NEW: from backend
  final String? supplierVerificationStatus; // NEW: from backend

  // === MOQ Pooling ===
  final int moq;
  final int currentOrders;
  final DateTime poolingDeadline;
  final PoolSummary? poolSummary;

  // === Logistics ===
  final int estimatedDays;
  final bool requiresCustoms;
  final List<String> images;

  // === Timestamps ===
  final DateTime createdAt;
  final DateTime? updatedAt;

  Product({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.isActive,
    required this.priceXaf,
    required this.currency,
    required this.supplierId,
    required this.supplierName,
    required this.supplierOrigin,
    required this.supplierCity,
    this.supplierCountry,
    this.supplierVerificationStatus,
    required this.moq,
    required this.currentOrders,
    required this.poolingDeadline,
    this.poolSummary,
    required this.estimatedDays,
    required this.requiresCustoms,
    required this.images,
    required this.createdAt,
    this.updatedAt,
  });

  /// Factory constructor to deserialize from legacy mock data JSON
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      category: json['category'] ?? 'All',
      isActive: json['isActive'] ?? true,
      priceXaf: _parseDouble(json['priceXaf'] ?? json['price']),
      currency: json['currency'] ?? 'XAF',
      supplierId: json['supplierId'] ?? '',
      supplierName: json['supplierName'] ?? 'Unknown',
      supplierOrigin: json['supplierOrigin'] ?? 'unknown',
      supplierCity: json['supplierCity'] ?? '',
      supplierCountry: json['supplierCountry'], // not present in mock
      supplierVerificationStatus:
          json['supplierVerificationStatus'], // not present
      moq: json['moq'] ?? 0,
      currentOrders: json['currentOrders'] ?? 0,
      poolingDeadline: _parseDateTime(json['poolingDeadline']),
      poolSummary: null,
      estimatedDays: json['estimatedDays'] ?? 14,
      requiresCustoms: json['requiresCustoms'] ?? false,
      images: _parseImages(json['images']),
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  /// FIXED: Issue #21 - Deserialize from backend NestJS /products endpoint response
  /// Backend returns: { id, title, description, category, supplier: {displayName, country, verificationStatus, ...}, variants: [{unitPriceXaf, thresholdQty, leadTimeDays}], createdAt, updatedAt }
  factory Product.fromBackendApi(Map<String, dynamic> json) {
    final variants = json['variants'] as List?;
    final firstVariant = variants != null && variants.isNotEmpty
        ? Map<String, dynamic>.from(variants.first)
        : <String, dynamic>{};

    final supplierMap = json['supplier'] is Map
        ? Map<String, dynamic>.from(json['supplier'])
        : <String, dynamic>{};

    final unitPriceXaf = _parseDouble(firstVariant['unitPriceXaf']);
    final thresholdQty = _parseInt(firstVariant['thresholdQty']) ?? 0;
    final leadTimeDays = _parseInt(firstVariant['leadTimeDays']) ?? 14;

    // Extract supplier fields
    final supplierName = (supplierMap['displayName'] ?? 'Unknown') as String;
    final supplierCountry = supplierMap['country'] as String?;
    final supplierVerificationStatus =
        supplierMap['verificationStatus'] as String?;

    // Determine origin from country or fallback to name detection
    String supplierOrigin;
    if (supplierCountry != null) {
      supplierOrigin = supplierCountry.toLowerCase() == 'nigeria'
          ? 'nigeria'
          : supplierCountry.toLowerCase() == 'cameroon'
          ? 'cameroon'
          : 'unknown';
    } else {
      supplierOrigin = supplierName.toLowerCase().contains('korea')
          ? 'korea'
          : 'nigeria';
    }

    return Product(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      category: json['category'] ?? 'Other',
      isActive: json['isActive'] ?? true,
      priceXaf: unitPriceXaf,
      currency: 'XAF',
      supplierId: json['supplierId'] ?? '',
      supplierName: supplierName,
      supplierOrigin: supplierOrigin,
      supplierCity: supplierMap['city'] ?? '',
      supplierCountry: supplierCountry,
      supplierVerificationStatus: supplierVerificationStatus,
      moq: thresholdQty,
      currentOrders: 0, // Will be fetched from pool separately
      poolingDeadline: DateTime.now().add(Duration(days: 7)), // Default
      poolSummary: null,
      estimatedDays: leadTimeDays,
      requiresCustoms: supplierOrigin == 'korea',
      images: const [], // Backend doesn't provide images yet
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  /// Convert Product to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'isActive': isActive,
      'priceXaf': priceXaf,
      'currency': currency,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'supplierOrigin': supplierOrigin,
      'supplierCity': supplierCity,
      'supplierCountry': supplierCountry,
      'supplierVerificationStatus': supplierVerificationStatus,
      'moq': moq,
      'currentOrders': currentOrders,
      'poolingDeadline': poolingDeadline.toIso8601String(),
      'poolSummary': poolSummary?.toJson(),
      'estimatedDays': estimatedDays,
      'requiresCustoms': requiresCustoms,
      'images': images,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Progress percentage for MOQ pooling (0.0 to 1.0)
  double getProgressPercentage() {
    if (moq == 0) return 0.0;
    return (currentOrders / moq).clamp(0.0, 1.0);
  }

  /// Get color for progress bar based on completion
  String getProgressColor() {
    final progress = getProgressPercentage();
    if (progress >= 0.7) return '#10b981'; // green
    if (progress >= 0.3) return '#f59e0b'; // orange
    return '#ef4444'; // red
  }

  /// Time remaining until pool deadline
  Duration getTimeRemaining() {
    final now = DateTime.now();
    if (poolingDeadline.isAfter(now)) {
      return poolingDeadline.difference(now);
    } else {
      return Duration.zero;
    }
  }

  /// Formatted shipping estimate (e.g., "3-7 days" or "14-21 days + customs")
  String getShippingLabel() {
    final customsSuffix = requiresCustoms ? ' + customs' : '';
    if (estimatedDays <= 0) return 'N/A';
    return '$estimatedDays days$customsSuffix';
  }

  /// Format price with currency
  String get formattedPrice {
    final formatted = priceXaf
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '$formatted $currency';
  }

  /// Compatibility getters for older code expecting `name` and `price`.
  String get name => title;

  double get price => priceXaf;

  /// Format creation date for display
  String get formattedDate {
    return DateFormat('MMM d, yyyy').format(createdAt);
  }

  @override
  String toString() =>
      'Product(id: $id, title: $title, price: $formattedPrice, origin: $supplierOrigin)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// === Helper parsing functions ===

double _parseDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

int? _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

DateTime _parseDateTime(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return DateTime.now();
    }
  }
  return DateTime.now();
}

List<String> _parseImages(dynamic value) {
  if (value is List) {
    return List<String>.from(value.whereType<String>());
  }
  return [];
}
