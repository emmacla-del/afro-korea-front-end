import 'package:intl/intl.dart';

/// Strongly typed Product model matching Prisma response from backend.
/// Handles null-safety and JSON deserialization.
class Product {
  /// Unique identifier (UUID from database)
  final String id;

  /// Product name
  final String name;

  /// Product description (optional)
  final String? description;

  /// Price in XAF (Cameroonian Franc)
  final double price;

  /// Currency code (e.g., "XAF")
  final String currency;

  /// UTC timestamp when product was created
  final DateTime createdAt;

  /// Category tag (optional)
  final String? category;

  /// Supplier ID (optional, for filtering)
  final String? supplierId;

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.currency,
    required this.createdAt,
    this.category,
    this.supplierId,
  });

  /// Factory constructor to deserialize from JSON (Prisma response)
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String? ?? '',
      name: json['title'] as String? ?? json['name'] as String? ?? 'Unknown',
      description: json['description'] as String?,
      price: _parsePrice(json['unitPriceXaf'] ?? json['price']),
      currency: json['currency'] as String? ?? 'XAF',
      createdAt: _parseDateTime(json['createdAt']),
      category: json['category'] as String?,
      supplierId: json['supplierId'] as String?,
    );
  }

  /// Convert Product to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': name,
      'description': description,
      'unitPriceXaf': price,
      'currency': currency,
      'createdAt': createdAt.toIso8601String(),
      'category': category,
      'supplierId': supplierId,
    };
  }

  /// Helper to parse price (handles int or double)
  static double _parsePrice(dynamic price) {
    if (price == null) return 0.0;
    if (price is double) return price;
    if (price is int) return price.toDouble();
    if (price is String) return double.tryParse(price) ?? 0.0;
    return 0.0;
  }

  /// Helper to parse DateTime from ISO 8601 string or Unix timestamp
  static DateTime _parseDateTime(dynamic dateTime) {
    if (dateTime == null) return DateTime.now();
    if (dateTime is DateTime) return dateTime;
    if (dateTime is String) {
      try {
        return DateTime.parse(dateTime);
      } catch (e) {
        return DateTime.now();
      }
    }
    if (dateTime is int) {
      return DateTime.fromMillisecondsSinceEpoch(dateTime);
    }
    return DateTime.now();
  }

  /// Format price as currency display
  String get formattedPrice {
    return '${price.toStringAsFixed(0)} $currency';
  }

  /// Format creation date for display
  String get formattedDate {
    return DateFormat('MMM d, yyyy').format(createdAt);
  }

  @override
  String toString() =>
      'Product(id: $id, name: $name, price: $formattedPrice, category: $category)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
