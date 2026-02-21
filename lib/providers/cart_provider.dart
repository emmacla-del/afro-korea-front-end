import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart_item_model.dart';
import '../models/product.dart'; // FIXED: Issue #1 - unified product model

/// CartNotifier manages the shopping cart state
///
/// Provides methods to:
/// - Add items to cart
/// - Remove items from cart
/// - Update item quantities
/// - Calculate total price
class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  /// Add a product to the cart or increase quantity if already present
  void addItem(Product product, {int quantity = 1}) {
    final existingIndex = state.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (existingIndex >= 0) {
      // Product already in cart - increase quantity
      final existingItem = state[existingIndex];
      final updatedItem = existingItem.copyWith(
        quantity: existingItem.quantity + quantity,
      );
      state = [
        ...state.sublist(0, existingIndex),
        updatedItem,
        ...state.sublist(existingIndex + 1),
      ];
    } else {
      // New product - add to cart
      state = [...state, CartItem(product: product, quantity: quantity)];
    }
  }

  /// Remove a product from the cart by product ID
  void removeItem(String productId) {
    state = state.where((item) => item.product.id != productId).toList();
  }

  /// Update quantity of an item in the cart
  void updateQuantity(String productId, int newQuantity) {
    if (newQuantity <= 0) {
      removeItem(productId);
      return;
    }

    state = state.map((item) {
      if (item.product.id == productId) {
        return item.copyWith(quantity: newQuantity);
      }
      return item;
    }).toList();
  }

  /// Get an item from the cart by product ID
  CartItem? getItem(String productId) {
    try {
      return state.firstWhere((item) => item.product.id == productId);
    } catch (e) {
      return null;
    }
  }

  /// Clear all items from the cart
  void clear() {
    state = [];
  }

  /// Get the number of items in the cart (unique products)
  int get itemCount => state.length;

  /// Get the total quantity of all items
  int get totalQuantity =>
      state.fold<int>(0, (sum, item) => sum + item.quantity);

  /// Get the total price of all items in the cart
  double get totalPrice =>
      state.fold<double>(0, (sum, item) => sum + item.itemTotal);

  /// Format total price as currency (uses first item's currency or default)
  String get formattedTotalPrice {
    if (state.isEmpty) return '0 XAF';
    final currency = state.first.product.currency;
    return '${totalPrice.toStringAsFixed(0)} $currency';
  }

  /// Check if a product is in the cart
  bool isInCart(String productId) {
    return state.any((item) => item.product.id == productId);
  }

  /// Get list of cart items as JSON for API request
  List<Map<String, dynamic>> toJson() {
    return state.map((item) => item.toJson()).toList();
  }
}

/// StateNotifier provider for cart management
///
/// Usage in widgets:
/// ```dart
/// ref.watch(cartProvider)  // Watch all cart items
/// ref.read(cartProvider.notifier).addItem(product)
/// ```
final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});

/// Derived provider for cart total price
final cartTotalProvider = Provider<double>((ref) {
  final cartItems = ref.watch(cartProvider);
  return cartItems.fold<double>(0, (sum, item) => sum + item.itemTotal);
});

/// Derived provider for formatted total price
final cartFormattedTotalProvider = Provider<String>((ref) {
  final cartItems = ref.watch(cartProvider);
  if (cartItems.isEmpty) return '0 XAF';
  final currency = cartItems.first.product.currency;
  final total = cartItems.fold<double>(0, (sum, item) => sum + item.itemTotal);
  return '${total.toStringAsFixed(0)} $currency';
});

/// Derived provider for cart item count (unique products)
final cartItemCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).length;
});

/// Derived provider for total quantity (sum of all item quantities)
final cartTotalQuantityProvider = Provider<int>((ref) {
  final cartItems = ref.watch(cartProvider);
  return cartItems.fold<int>(0, (sum, item) => sum + item.quantity);
});

/// Derived provider to check if cart is empty
final isCartEmptyProvider = Provider<bool>((ref) {
  return ref.watch(cartProvider).isEmpty;
});
