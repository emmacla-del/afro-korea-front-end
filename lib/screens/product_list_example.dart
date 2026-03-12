import 'package:flutter/material.dart';
import '../models/product.dart'; // FIXED: Issue #1 - unified product model
import '../services/api_service.dart';

/// Example widget demonstrating how to use ApiService with Dio
class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late final ApiService _apiService;
  List<Product> _products = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService.instance;

    // Optional: Set bearer token if user is logged in
    // _apiService.setBearerToken('user_jwt_token_here');

    _loadProducts();
  }

  /// Fetch products from backend
  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final products = await _apiService.fetchProducts();
      setState(() {
        _products = products;
      });
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
    } catch (e) {
      setState(() {
        _errorMessage = 'Unexpected error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    // Optionally close API service when screen is disposed
    // _apiService.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Products'), elevation: 0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: $_errorMessage'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadProducts,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _products.isEmpty
          ? const Center(child: Text('No products available'))
          : ListView.builder(
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                return ProductCard(product: product);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadProducts,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

/// Product card widget
class ProductCard extends StatelessWidget {
  final Product product;

  const ProductCard({required this.product, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.name,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            if (product.description != null)
              Text(
                product.description!,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  product.formattedPrice,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  product.formattedDate,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Example of authenticated endpoint usage
Future<void> exampleAuthenticatedCall(String userToken) async {
  final apiService = ApiService.instance;

  // Set bearer token before making requests
  apiService.setBearerToken(userToken);

  try {
    // Fetch user's orders (requires authentication)
    final orders = await apiService.fetchMyOrders();
    print('Orders: $orders');

    // Fetch a pool (may require authentication)
    final pool = await apiService.fetchPool('pool-id-here');
    print('Pool: $pool');

    // Commit to a pool
    final result = await apiService.commitToPool(
      'pool-id-here',
      body: {'quantity': 5, 'notes': 'Committing to pool'},
    );
    print('Result: $result');
  } on ApiException catch (e) {
    print('API Error: ${e.message}');

    // Handle specific errors
    if (e.statusCode == 401) {
      print('Token expired or unauthorized');
      // Refresh token or redirect to login
    } else if (e.statusCode == 500) {
      print('Server error');
    }
  }
}
