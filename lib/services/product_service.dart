import '../models/product.dart';
import 'api_service.dart';
import 'mock_product_service.dart';

enum ProductFallbackBehavior { none, mock }

/// Product service backed by the AfroPool API.
///
/// Backend endpoint used:
/// - `GET /products` (public product browse)
///
/// This class is structured to clearly separate:
/// - API fetching
/// - mapping/parsing
/// - fallback behavior (temporary)
class ProductService {
  final ProductFallbackBehavior fallbackBehavior;

  ProductService({this.fallbackBehavior = ProductFallbackBehavior.mock});

  Future<List<Product>> listProducts() async {
    try {
      final json = await _fetchCatalogProducts();
      return _parseCatalogProducts(json);
    } catch (_) {
      return _fallbackProducts();
    }
  }

  // ----------------------------
  // 1) API fetching
  // ----------------------------
  Future<Object?> _fetchCatalogProducts() {
    return ApiService.instance.fetchProducts();
  }

  // ----------------------------
  // 2) Mapping / parsing
  // ----------------------------
  List<Product> _parseCatalogProducts(Object? json) {
    if (json is! List<Product>) {
      throw ApiException(message: 'Expected a product list from GET /products');
    }
    return json;
  }

  // ----------------------------
  // 3) Fallback behavior (temporary)
  // ----------------------------
  List<Product> _fallbackProducts() {
    switch (fallbackBehavior) {
      case ProductFallbackBehavior.none:
        return const [];
      case ProductFallbackBehavior.mock:
        return MockProductService.getMockProducts();
    }
  }
}
