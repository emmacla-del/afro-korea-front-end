import '../models/product.dart';
import 'api_client.dart';
import 'mock_product_service.dart';

enum ProductFallbackBehavior {
  none,
  mock,
}

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
  final ApiClient _api;
  final ProductFallbackBehavior fallbackBehavior;

  ProductService({
    ApiClient? apiClient,
    this.fallbackBehavior = ProductFallbackBehavior.mock,
  }) : _api = apiClient ?? ApiClient();

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
    return _api.get<Object?>(
      '/products',
      timeout: const Duration(seconds: 5),
    );
  }

  // ----------------------------
  // 2) Mapping / parsing
  // ----------------------------
  List<Product> _parseCatalogProducts(Object? json) {
    if (json is! List) {
      throw ApiException(
        statusCode: 200,
        reasonPhrase: 'OK',
        body: json?.toString() ?? 'null',
        message: 'Expected a JSON array from GET /products',
      );
    }

    final result = <Product>[];
    for (final item in json) {
      if (item is! Map) continue;
      final mapped = Product.fromBackendApi(Map<String, dynamic>.from(item));
      result.add(mapped);
    }
    return result;
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
