import 'package:flutter/material.dart';
import '../app/app_role.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../widgets/product_card.dart';

class HomePage extends StatefulWidget {
  final AppRole currentRole;
  final ValueChanged<AppRole> onRoleChanged;
  final VoidCallback onLogout;
  final bool isAdmin;

  const HomePage({
    super.key,
    required this.currentRole,
    required this.onRoleChanged,
    required this.onLogout,
    this.isAdmin = false,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Product> _products = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final products = await ApiService.instance.fetchProducts();
      if (!mounted) return;
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadProducts,
      child: CustomScrollView(
        slivers: [
          // Admin button is now in MainScaffold's drawer, not here
          // Role switch button is now in MainScaffold's app bar
          // Supplier mode banner
          if (widget.currentRole == AppRole.supplier)
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                color: Colors.green[50],
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                child: Row(
                  children: const [
                    Icon(Icons.store, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Supplier Mode',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Product grid or loading/error
          SliverPadding(
            padding: const EdgeInsets.all(8),
            sliver: _isLoading
                ? const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _error != null
                ? SliverToBoxAdapter(
                    child: Center(
                      child: Column(
                        children: [
                          Text('Error: $_error'),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _loadProducts,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _products.isEmpty
                ? const SliverToBoxAdapter(
                    child: Center(child: Text('No products available')),
                  )
                : SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final product = _products[index];
                      return ProductCard(
                        product: product,
                        onTap: () {
                          // TODO: Navigate to product details
                        },
                        onLongPress: () {},
                        onJoinPool: () {
                          // TODO: Join pool logic
                        },
                        onBuyNow: () {
                          // TODO: Buy now logic
                        },
                      );
                    }, childCount: _products.length),
                  ),
          ),
        ],
      ),
    );
  }
}
