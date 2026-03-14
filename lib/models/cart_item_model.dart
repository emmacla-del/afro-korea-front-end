import 'package:flutter/foundation.dart';
import 'product.dart'; // Needed for the factory method that uses Product

/// CartItem represents a specific product variant added to the shopping cart.
///
/// This model stores the exact variant selected, its price at the time of addition,
/// and the quantity.
@immutable
class CartItem {
  /// ID of the product (parent product)
  final String productId;

  /// ID of the specific variant
  final String variantId;

  /// Product title (for display, copied from product at time of addition)
  final String title;

  /// Price of the variant at the time it was added to the cart
  final double price;

  /// Currency (e.g., 'XAF')
  final String currency;

  /// Quantity of this variant in the cart
  final int quantity;

  const CartItem({
    required this.productId,
    required this.variantId,
    required this.title,
    required this.price,
    required this.currency,
    required this.quantity,
  }) : assert(quantity > 0, 'Quantity must be greater than 0');

  /// Factory to create a CartItem from a product, a selected variant, and quantity
  factory CartItem.fromProductAndVariant(
    Product product,
    Map<String, dynamic> variant,
    int quantity,
  ) {
    return CartItem(
      productId: product.id,
      variantId: variant['id'] ?? '',
      title: product.title,
      price: (variant['unitPriceXaf'] ?? 0).toDouble(),
      currency: 'XAF',
      quantity: quantity,
    );
  }

  /// Total price for this cart item (price × quantity)
  double get totalPrice => price * quantity;

  /// Create a copy of CartItem with modified fields
  CartItem copyWith({
    String? productId,
    String? variantId,
    String? title,
    double? price,
    String? currency,
    int? quantity,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      variantId: variantId ?? this.variantId,
      title: title ?? this.title,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      quantity: quantity ?? this.quantity,
    );
  }

  /// Convert CartItem to JSON for API request (e.g., when creating an order)
  Map<String, dynamic> toJson() {
    return {
      'variantId': variantId,
      'quantity': quantity,
      'unitPrice': price,
      'currency': currency,
    };
  }

  /// Format item total as currency
  String get formattedItemTotal {
    return '${totalPrice.toStringAsFixed(0)} $currency';
  }

  @override
  String toString() =>
      'CartItem(title: $title, variantId: $variantId, quantity: $quantity, total: $formattedItemTotal)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItem &&
          runtimeType == other.runtimeType &&
          variantId == other.variantId &&
          quantity == other.quantity;

  @override
  int get hashCode => variantId.hashCode ^ quantity.hashCode;
}
