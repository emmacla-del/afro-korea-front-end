import 'package:flutter/material.dart';
import '../app/app_role.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import 'product_detail_page.dart';

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

      // 🔍 TEMP DEBUG — remove after fixing
      for (final p in products) {
        debugPrint('🏊 Product: ${p.title}');
        debugPrint('   variants count: ${p.variants?.length ?? 0}');
        for (final v in p.variants ?? []) {
          final pools = v['pools'] as List?;
          debugPrint('   variant pools: $pools');
        }
      }

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
                color: const Color(0xFFE8F5E9),
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                child: const Row(
                  children: [
                    Icon(Icons.store, color: Color(0xFF00C471), size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Supplier Mode',
                      style: TextStyle(
                        color: Color(0xFF00C471),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          SliverToBoxAdapter(
            child: Container(height: 1, color: Colors.grey.shade100),
          ),

          SliverPadding(
            padding: EdgeInsets.zero,
            sliver: _isLoading
                ? const SliverToBoxAdapter(
                    child: SizedBox(
                      height: 300,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                : _error != null
                ? SliverToBoxAdapter(
                    child: SizedBox(
                      height: 300,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
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
                    ),
                  )
                : _products.isEmpty
                ? const SliverToBoxAdapter(
                    child: SizedBox(
                      height: 300,
                      child: Center(child: Text('No products available')),
                    ),
                  )
                : SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.58,
                          crossAxisSpacing: 1, // ✅ hairline gap
                          mainAxisSpacing: 1, // ✅ hairline gap
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _ProductTile(product: _products[index]),
                      childCount: _products.length,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;

  const _ProductTile({required this.product});

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.images?.isNotEmpty == true
        ? product.images!.first
        : null;
    final soloPrice = product.price ?? 0;
    final groupPrice = product.teamPrice;
    final hasGroup = product.hasActiveTeamDeal;
    final discount = product.discountPercent;
    final current = product.currentBuyers ?? 0;
    final min = product.minBuyers ?? 0;
    final supplierName = product.supplier?['displayName'] ?? 'Unknown supplier';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailPage(productId: product.id),
          ),
        );
      },
      child: Container(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Portrait image — no padding, fills width
            AspectRatio(
              aspectRatio: 0.85,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: Colors.white,
                    child: imageUrl == null
                        ? const Center(
                            child: Icon(
                              Icons.image,
                              size: 48,
                              color: Colors.grey,
                            ),
                          )
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.contain, // ✅ full product visible
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(
                                Icons.broken_image,
                                size: 48,
                                color: Colors.grey,
                              ),
                            ),
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              );
                            },
                          ),
                  ),

                  // Discount badge
                  if (discount > 0)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$discount% OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ✅ Info strip — compact like Coupang
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // ✅ Pinduoduo dual price
                    if (hasGroup && groupPrice != null) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          const Icon(
                            Icons.groups,
                            size: 12,
                            color: Color(0xFF00C471),
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              '${groupPrice.toStringAsFixed(0)} XAF',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF00C471),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Solo: ${soloPrice.toStringAsFixed(0)} XAF',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: min > 0 ? (current / min).clamp(0.0, 1.0) : 0,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF00C471),
                          ),
                          minHeight: 3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$current/$min joined',
                        style: const TextStyle(fontSize: 9, color: Colors.grey),
                      ),
                    ] else
                      Text(
                        '${soloPrice.toStringAsFixed(0)} XAF',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),

                    const Spacer(),

                    Text(
                      supplierName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
