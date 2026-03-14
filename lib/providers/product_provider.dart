import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../services/api_service.dart';

/// FutureProvider that fetches products from the backend.
///
/// Usage in widgets:
/// ```dart
/// ref.watch(productsProvider)  // Automatically handles loading/error states
/// ```
///
/// Returns:
/// - AsyncValue.loading while fetching
/// - AsyncValue.data with List&lt;Product&gt; on success
/// - AsyncValue.error on failure
final productsProvider = FutureProvider<List<Product>>((ref) async {
  final apiService = ApiService.instance;
  return apiService.fetchProducts();
});

/// Provider for getting a specific product by ID.
///
/// Usage:
/// ```dart
/// ref.watch(productByIdProvider('product-uuid'))
/// ```
final productByIdProvider = FutureProvider.family<Product?, String>((
  ref,
  productId,
) async {
  final products = await ref.watch(productsProvider.future);
  try {
    return products.firstWhere((p) => p.id == productId);
  } catch (e) {
    return null;
  }
});

/// Provider for filtered products by category.
///
/// Usage:
/// ```dart
/// ref.watch(productsByCategoryProvider('Electronics'))
/// ```
final productsByCategoryProvider =
    FutureProvider.family<List<Product>, String?>((ref, category) async {
      final products = await ref.watch(productsProvider.future);

      if (category == null || category.isEmpty) {
        return products;
      }

      final lowerCategory = category.toLowerCase();
      return products
          .where((p) => p.category?.toLowerCase() == lowerCategory)
          .toList();
    });

/// Provider for searching products by name/description.
///
/// Usage:
/// ```dart
/// ref.watch(searchProductsProvider('skincare'))
/// ```
final searchProductsProvider = FutureProvider.family<List<Product>, String>((
  ref,
  query,
) async {
  final products = await ref.watch(productsProvider.future);

  if (query.isEmpty) {
    return products;
  }

  final lowerQuery = query.toLowerCase();
  return products
      .where(
        (p) =>
            p.title.toLowerCase().contains(
              lowerQuery,
            ) || // 👈 use title (non‑nullable)
            (p.description?.toLowerCase().contains(lowerQuery) ?? false),
      )
      .toList();
});

/// Provider for sorted products by price (ascending).
///
/// Products with no price (null) are placed at the end.
///
/// Usage:
/// ```dart
/// ref.watch(productsSortedByPriceProvider)
/// ```
final productsSortedByPriceProvider = FutureProvider<List<Product>>((
  ref,
) async {
  final products = await ref.watch(productsProvider.future);
  final sorted = List<Product>.from(products);
  sorted.sort((a, b) {
    final aPrice = a.price ?? double.infinity;
    final bPrice = b.price ?? double.infinity;
    return aPrice.compareTo(bPrice);
  });
  return sorted;
});

/// Provider for most recently created products.
///
/// Usage:
/// ```dart
/// ref.watch(newestProductsProvider(10))
/// ```
final newestProductsProvider = FutureProvider.family<List<Product>, int>((
  ref,
  limit,
) async {
  final products = await ref.watch(productsProvider.future);
  final sorted = List<Product>.from(products);
  sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return sorted.take(limit).toList();
});

/// Provider for product count.
///
/// Usage:
/// ```dart
/// ref.watch(productCountProvider)
/// ```
final productCountProvider = FutureProvider<int>((ref) async {
  final products = await ref.watch(productsProvider.future);
  return products.length;
});

/// Error handler for products provider.
/// Provides a default empty list when products fail to load.
final productsWithFallbackProvider = FutureProvider<List<Product>>((ref) async {
  try {
    return await ref.watch(productsProvider.future);
  } catch (e) {
    return [];
  }
});
