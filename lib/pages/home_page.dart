import 'package:flutter/material.dart';
import '../app/app_role.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import 'product_detail_page.dart'; // 👈 import the detail page

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
                      return _ProductTile(product: product);
                    }, childCount: _products.length),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Product tile for the home page with team deal badge and navigation
class _ProductTile extends StatelessWidget {
  final Product product;

  const _ProductTile({required this.product});

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.images?.isNotEmpty == true
        ? product.images!.first
        : null;
    final regularPrice = product.price ?? 0;
    final currency = 'XAF';
    final supplierName = product.supplier?['displayName'] ?? 'Unknown supplier';
    final hasTeamDeal = product.hasActiveTeamDeal;
    final teamPrice = product.teamPrice;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailPage(productId: product.id),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image with team deal badge
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: imageUrl == null
                      ? Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.image),
                        )
                      : Image.network(imageUrl, fit: BoxFit.cover),
                ),
                if (hasTeamDeal)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'TEAM DEAL',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Price row: regular price + team price if available
                  Row(
                    children: [
                      Text(
                        '$regularPrice $currency',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration:
                              hasTeamDeal &&
                                  teamPrice != null &&
                                  teamPrice < regularPrice
                              ? TextDecoration.lineThrough
                              : null,
                          color:
                              hasTeamDeal &&
                                  teamPrice != null &&
                                  teamPrice < regularPrice
                              ? Colors.grey
                              : null,
                        ),
                      ),
                      if (hasTeamDeal &&
                          teamPrice != null &&
                          teamPrice < regularPrice) ...[
                        const SizedBox(width: 4),
                        Text(
                          '$teamPrice $currency',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    supplierName,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
