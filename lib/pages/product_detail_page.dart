import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class ProductDetailPage extends StatefulWidget {
  final String productId;

  const ProductDetailPage({super.key, required this.productId});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  Product? _product;
  bool _isLoading = true;
  String? _error;
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final products = await ApiService.instance.fetchProducts();
      if (!mounted) return;
      final product = products.firstWhere((p) => p.id == widget.productId);
      setState(() {
        _product = product;
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
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Product Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Product Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProduct,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_product == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Product Details')),
        body: const Center(child: Text('Product not found')),
      );
    }
    final product = _product!;
    return Scaffold(
      appBar: AppBar(
        title: Text(product.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: share product link
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Image gallery
          if (product.images != null && product.images!.isNotEmpty)
            _buildImageGallery(product.images!),
          const SizedBox(height: 16),

          // Title and description
          Text(product.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          if (product.description != null && product.description!.isNotEmpty)
            Text(product.description!),
          const SizedBox(height: 16),

          // Supplier info
          Card(
            child: ListTile(
              leading: const Icon(Icons.store),
              title: Text(
                product.supplier?['displayName'] ?? 'Unknown supplier',
              ),
              subtitle: Text(product.supplier?['country'] ?? ''),
            ),
          ),
          const SizedBox(height: 16),

          // Variants section
          Text(
            'Available Options',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ..._buildVariants(product),

          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(product),
    );
  }

  Widget _buildImageGallery(List<String> images) {
    return Column(
      children: [
        SizedBox(
          height: 250,
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: images.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentImageIndex = index;
                  });
                },
                itemBuilder: (ctx, i) {
                  return Container(
                    color: Colors.grey[100],
                    child: Image.network(
                      images[i],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image, size: 50),
                      ),
                    ),
                  );
                },
              ),
              // Positioned counter at bottom right
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentImageIndex + 1} / ${images.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
              // Dots indicator at bottom center (optional)
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    images.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _currentImageIndex == i ? 12 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentImageIndex == i
                            ? Colors.white
                            : Colors.white70,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildVariants(Product product) {
    if (product.variants == null || product.variants!.isEmpty) {
      return [const Text('No variants available')];
    }
    final variants = product.variants!;
    return variants.map((v) {
      final price = (v['unitPriceXaf'] as num?)?.toDouble() ?? 0;
      final stock = v['thresholdQty'] as int? ?? 0;
      final sku = v['sku'] as String? ?? '';
      final pools = v['pools'] as List?;
      final hasTeamDeal = pools != null && pools.isNotEmpty;

      double? teamPrice;
      int? minBuyers;
      int? currentBuyers;
      if (hasTeamDeal) {
        final pool = pools!.first as Map<String, dynamic>?;
        teamPrice = (pool?['teamPrice'] as num?)?.toDouble();
        minBuyers = pool?['minBuyers'] as int?;
        currentBuyers = pool?['currentBuyers'] as int?;
      }

      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'SKU: $sku',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  if (stock > 0)
                    Text(
                      'In stock: $stock',
                      style: const TextStyle(color: Colors.green),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text('$price XAF', style: const TextStyle(fontSize: 16)),
                  if (hasTeamDeal &&
                      teamPrice != null &&
                      teamPrice < price) ...[
                    const SizedBox(width: 8),
                    Text(
                      '$teamPrice XAF',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '-${((price - teamPrice) / price * 100).round()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (hasTeamDeal && minBuyers != null && currentBuyers != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: currentBuyers / minBuyers,
                        backgroundColor: Colors.grey[200],
                        color: Colors.green,
                      ),
                      const SizedBox(height: 4),
                      Text('👥 $currentBuyers/$minBuyers joined'),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildBottomBar(Product product) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  // TODO: Join team deal (need to pick a variant)
                  if (product.variants != null) {
                    for (var v in product.variants!) {
                      final pools = v['pools'] as List?;
                      if (pools != null && pools.isNotEmpty) {
                        final pool = pools.first as Map<String, dynamic>?;
                        if (pool != null &&
                            pool['dealType'] == 'TEAM_DEAL' &&
                            pool['status'] == 'OPEN') {
                          try {
                            await ApiService.instance.joinTeamDeal(pool['id']);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✅ Joined team deal!'),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('❌ Error: $e')),
                            );
                          }
                          return;
                        }
                      }
                    }
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No open team deal available'),
                    ),
                  );
                },
                icon: const Icon(Icons.groups),
                label: const Text('Join Team Deal'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // TODO: Buy now (choose variant and go to cart/checkout)
                },
                icon: const Icon(Icons.shopping_bag),
                label: const Text('Buy Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
