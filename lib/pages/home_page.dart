import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:transparent_image/transparent_image.dart';

import '../app/app_role.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import 'product_detail_page.dart';

enum ProductFilter { all, nearMe }

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
  ProductFilter _filter = ProductFilter.all;
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
      final products = await ApiService.instance.fetchProducts(
        nearMe: _filter == ProductFilter.nearMe,
      );
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
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.card_giftcard, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Invite friends & earn rewards 🎁",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('Filter:', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 8),
                  PopupMenuButton<ProductFilter>(
                    initialValue: _filter,
                    onSelected: (filter) {
                      setState(() => _filter = filter);
                      _loadProducts();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _filter == ProductFilter.all
                                ? 'All products'
                                : 'Near me',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const Icon(Icons.arrow_drop_down, size: 18),
                        ],
                      ),
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: ProductFilter.all,
                        child: Text('All products'),
                      ),
                      const PopupMenuItem(
                        value: ProductFilter.nearMe,
                        child: Text('Near me'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: _buildGridSliver(),
          ),
        ],
      ),
    );
  }

  Widget _buildGridSliver() {
    if (_isLoading) {
      return const SliverToBoxAdapter(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return SliverToBoxAdapter(child: Center(child: Text('Error: $_error')));
    }
    if (_products.isEmpty) {
      if (_filter == ProductFilter.nearMe) {
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const Icon(Icons.location_off, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No deals in your neighbourhood yet.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _filter = ProductFilter.all);
                    _loadProducts();
                  },
                  child: const Text('Show all products'),
                ),
              ],
            ),
          ),
        );
      }
      return const SliverToBoxAdapter(
        child: Center(child: Text('No products available')),
      );
    }
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.62, // square image + content below
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => _ProductTile(product: _products[index]),
        childCount: _products.length,
      ),
    );
  }
}

// ==================== Product Tile ====================

class _ProductTile extends StatefulWidget {
  final Product product;
  const _ProductTile({required this.product});

  @override
  State<_ProductTile> createState() => _ProductTileState();
}

class _ProductTileState extends State<_ProductTile> {
  Timer? _timer;
  late Duration _timeLeft;

  @override
  void initState() {
    super.initState();
    _timeLeft = widget.product.timeLeft;
    if (widget.product.hasActiveTeamDeal) _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _timeLeft = widget.product.timeLeft;
        if (_timeLeft.inSeconds <= 0) _timer?.cancel();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds <= 0) return '00:00:00';
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  void _goToDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(productId: widget.product.id),
      ),
    );
  }

  void _buyAlone() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Buy Alone — not implemented yet')),
    );
  }

  void _joinGroup() {
    final poolId = widget.product.activeTeamDealPoolId;
    if (poolId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailPage(
            productId: widget.product.id,
            initialPoolId: poolId,
          ),
        ),
      );
    } else {
      _goToDetail();
    }
  }

  void _shareDeal() {
    Share.share(
      '🔥 Check out this deal on ${widget.product.title}!\n'
      'Price: ${widget.product.price} XAF\n'
      'https://yourapp.com/product/${widget.product.id}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final isExpired = _timeLeft.inSeconds <= 0;
    final hasActive = p.hasActiveTeamDeal && !isExpired;
    final imageUrl = p.images?.isNotEmpty == true ? p.images!.first : null;

    final supplierName = () {
      final name = p.supplier?['displayName'] as String?;
      return (name != null && name.trim().isNotEmpty)
          ? name.trim()
          : 'Unknown supplier';
    }();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Image — fixed height, not AspectRatio ──────────────────────
          _buildImage(imageUrl, hasActive),

          // ── Content below image ────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  GestureDetector(
                    onTap: _goToDetail,
                    child: Text(
                      p.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Dual-action frame
                  _buildDualActionFrame(),
                  const SizedBox(height: 4),

                  // Supplier + share
                  Row(
                    children: [
                      Expanded(child: _buildSupplierRow(p, supplierName)),
                      _ShareButton(onPressed: _shareDeal),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String? imageUrl, bool hasActive) {
    return GestureDetector(
      onTap: _goToDetail,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        child: AspectRatio(
          aspectRatio: 1.0, // 👈 1:1 square matches 800×800 Cloudinary output
          child: Stack(
            fit: StackFit.expand,
            children: [
              // White base — matches Cloudinary white padding
              Container(color: Colors.white),
              imageUrl == null
                  ? Container(
                      color: Colors.grey.shade100,
                      child: const Icon(
                        Icons.image,
                        color: Colors.grey,
                        size: 40,
                      ),
                    )
                  : FadeInImage(
                      placeholder: MemoryImage(kTransparentImage),
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.contain, // full image, no cropping
                      imageErrorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade100,
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                          size: 40,
                        ),
                      ),
                    ),
              if (hasActive)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    color: Colors.orange.withValues(alpha: 0.9),
                    child: Text(
                      'Ends: ${_formatDuration(_timeLeft)}',
                      textAlign: TextAlign.center,
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
      ),
    );
  }

  Widget _buildSupplierRow(Product p, String supplierName) {
    final isVerified = p.supplier?['verificationStatus'] == 'VERIFIED';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            supplierName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
          ),
        ),
        if (p.supplier != null) ...[
          const SizedBox(width: 3),
          if (isVerified) ...[
            Icon(Icons.verified, size: 10, color: Colors.blue.shade600),
            const SizedBox(width: 2),
            Text(
              'Verified',
              style: TextStyle(
                fontSize: 9,
                color: Colors.blue.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
          ] else
            Text(
              'Unverified',
              style: TextStyle(fontSize: 9, color: Colors.grey.shade400),
            ),
        ],
      ],
    );
  }

  Widget _buildDualActionFrame() {
    final p = widget.product;
    final isExpired = _timeLeft.inSeconds <= 0;
    final hasActive = p.hasActiveTeamDeal && !isExpired;
    final current = p.currentBuyers ?? 0;
    final min = p.minBuyers ?? 0;
    final savings = (p.price ?? 0) - (p.teamPrice ?? 0);
    final progress = min > 0 ? (current / min).clamp(0.0, 1.0) : 0.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // LEFT: Solo
            Expanded(
              child: InkWell(
                onTap: _buyAlone,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'SOLO',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        '${p.price} XAF',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Text(
                        'Standard',
                        style: TextStyle(fontSize: 8, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            VerticalDivider(
              width: 1,
              color: Colors.grey.shade200,
              indent: 4,
              endIndent: 4,
            ),

            // RIGHT: Group
            Expanded(
              child: hasActive
                  ? _PulsingGroupCard(
                      onTap: _joinGroup,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.horizontal(
                            right: Radius.circular(8),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'GROUP',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00C471),
                              ),
                            ),
                            Text(
                              '${p.teamPrice} XAF',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00C471),
                              ),
                            ),
                            Text(
                              '-${p.discountPercent}% · Save ${savings.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 8,
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (p.activePoolNeighbourhoodName != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        size: 8,
                                        color: Colors.blue.shade700,
                                      ),
                                      const SizedBox(width: 2),
                                      Flexible(
                                        child: Text(
                                          p.activePoolNeighbourhoodName!,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 7,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 3),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 3,
                                backgroundColor: Colors.grey.shade300,
                                valueColor: const AlwaysStoppedAnimation(
                                  Color(0xFF00C471),
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$current/$min joined',
                              style: const TextStyle(fontSize: 7),
                            ),
                          ],
                        ),
                      ),
                    )
                  : InkWell(
                      onTap: _goToDetail,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(8),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(8),
                          ),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.group_add, size: 14, color: Colors.blue),
                            Text(
                              'START GROUP',
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            Text(
                              'Be the first',
                              style: TextStyle(fontSize: 7, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== Pulsing Animation Wrapper ====================

class _PulsingGroupCard extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  const _PulsingGroupCard({required this.onTap, required this.child});

  @override
  State<_PulsingGroupCard> createState() => _PulsingGroupCardState();
}

class _PulsingGroupCardState extends State<_PulsingGroupCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (_, child) =>
            Transform.scale(scale: _animation.value, child: child),
        child: widget.child,
      ),
    );
  }
}

// ==================== Reusable Share Button ====================

class _ShareButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _ShareButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: IconButton(
        icon: const Icon(Icons.share, size: 14),
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
