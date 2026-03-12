import 'package:flutter/foundation.dart';
import 'product.dart'; // FIXED: Issue #1 - unified product model

/// CartItem represents a product added to the shopping cart with quantity.
///
/// This model combines a Product with the quantity selected by the user.
@immutable
class CartItem {
  /// The product being added to cart
  final Product product;

  /// Quantity of this product in the cart
  final int quantity;

  const CartItem({required this.product, required this.quantity})
    : assert(quantity > 0, 'Quantity must be greater than 0');

  /// Total price for this cart item (product price × quantity)
  double get itemTotal => product.price * quantity;

  /// Create a copy of CartItem with modified fields
  CartItem copyWith({Product? product, int? quantity}) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }

  /// Convert CartItem to JSON for API request
  Map<String, dynamic> toJson() {
    return {
      'productId': product.id,
      'quantity': quantity,
      'unitPrice': product.price,
    };
  }

  /// Format item total as currency
  String get formattedItemTotal {
    return '${itemTotal.toStringAsFixed(0)} ${product.currency}';
  }

  @override
  String toString() =>
      'CartItem(product: ${product.name}, quantity: $quantity, total: $formattedItemTotal)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItem &&
          runtimeType == other.runtimeType &&
          product.id == other.product.id &&
          quantity == other.quantity;

  @override
  int get hashCode => product.id.hashCode ^ quantity.hashCode;
}
