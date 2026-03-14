import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart_item_model.dart';
import '../models/product.dart';

/// CartNotifier manages the shopping cart state
///
/// Provides methods to:
/// - Add items to cart (with specific variant)
/// - Remove items from cart
/// - Update item quantities
/// - Calculate total price
class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  /// Add a product variant to the cart or increase quantity if already present
  void addItem({
    required Product product,
    required String variantId,
    int quantity = 1,
  }) {
    // Find the variant in the product's variant list using a loop (safe null handling)
    Map<String, dynamic>? variant;
    if (product.variants != null) {
      for (final v in product.variants!) {
        if (v['id'] == variantId) {
          variant = v;
          break;
        }
      }
    }
    if (variant == null) return; // Variant not found – should not happen

    final existingIndex = state.indexWhere(
      (item) => item.variantId == variantId,
    );

    if (existingIndex >= 0) {
      // Variant already in cart – increase quantity
      final existingItem = state[existingIndex];
      final updatedItem = CartItem(
        productId: existingItem.productId,
        variantId: existingItem.variantId,
        title: existingItem.title,
        price: existingItem.price,
        currency: existingItem.currency,
        quantity: existingItem.quantity + quantity,
      );
      state = [
        ...state.sublist(0, existingIndex),
        updatedItem,
        ...state.sublist(existingIndex + 1),
      ];
    } else {
      // New variant – add to cart
      final newItem = CartItem.fromProductAndVariant(
        product,
        variant,
        quantity,
      );
      state = [...state, newItem];
    }
  }

  /// Remove a variant from the cart by variant ID
  void removeItem(String variantId) {
    state = state.where((item) => item.variantId != variantId).toList();
  }

  /// Update quantity of an item in the cart (by variant ID)
  void updateQuantity(String variantId, int newQuantity) {
    if (newQuantity <= 0) {
      removeItem(variantId);
      return;
    }

    state = state.map((item) {
      if (item.variantId == variantId) {
        return CartItem(
          productId: item.productId,
          variantId: item.variantId,
          title: item.title,
          price: item.price,
          currency: item.currency,
          quantity: newQuantity,
        );
      }
      return item;
    }).toList();
  }

  /// Get an item from the cart by variant ID
  CartItem? getItem(String variantId) {
    try {
      return state.firstWhere((item) => item.variantId == variantId);
    } catch (e) {
      return null;
    }
  }

  /// Clear all items from the cart
  void clear() {
    state = [];
  }

  /// Get the number of unique variants in the cart
  int get itemCount => state.length;

  /// Get the total quantity of all items
  int get totalQuantity =>
      state.fold<int>(0, (sum, item) => sum + item.quantity);

  /// Get the total price of all items in the cart
  double get totalPrice =>
      state.fold<double>(0, (sum, item) => sum + item.totalPrice);

  /// Format total price as currency (uses first item's currency or default)
  String get formattedTotalPrice {
    if (state.isEmpty) return '0 XAF';
    final currency = state.first.currency;
    return '${totalPrice.toStringAsFixed(0)} $currency';
  }

  /// Check if a variant is already in the cart
  bool isInCart(String variantId) {
    return state.any((item) => item.variantId == variantId);
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
/// ref.read(cartProvider.notifier).addItem(product: product, variantId: '...')
/// ```
final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});

/// Derived provider for cart total price
final cartTotalProvider = Provider<double>((ref) {
  final cartItems = ref.watch(cartProvider);
  return cartItems.fold<double>(0, (sum, item) => sum + item.totalPrice);
});

/// Derived provider for formatted total price
final cartFormattedTotalProvider = Provider<String>((ref) {
  final cartItems = ref.watch(cartProvider);
  if (cartItems.isEmpty) return '0 XAF';
  final currency = cartItems.first.currency;
  final total = cartItems.fold<double>(0, (sum, item) => sum + item.totalPrice);
  return '${total.toStringAsFixed(0)} $currency';
});

/// Derived provider for cart item count (unique variants)
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
