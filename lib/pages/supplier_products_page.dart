import 'package:flutter/material.dart';
import '../api/supplier_api.dart';
import '../models/supplier_product.dart';
import 'supplier_product_edit_page.dart';

class SupplierProductsPage extends StatefulWidget {
  const SupplierProductsPage({super.key});

  @override
  State<SupplierProductsPage> createState() => _SupplierProductsPageState();
}

class _SupplierProductsPageState extends State<SupplierProductsPage> {
  final SupplierApi _api = SupplierApi();
  final ScrollController _scrollController = ScrollController();

  final List<SupplierProduct> _items = [];

  int _page = 1;
  static const int _pageSize = 20;
  int _total = 0;

  bool _isInitialLoading = false;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;

  bool get _hasMore => _items.length < _total;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initialLoad();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore) return;
    if (_isInitialLoading || _isRefreshing || _isLoadingMore) return;

    final threshold = 400.0;
    if (_scrollController.position.extentAfter < threshold) {
      _loadMore();
    }
  }

  Future<void> _initialLoad() async {
    if (_isInitialLoading) return;
    setState(() => _isInitialLoading = true);

    try {
      final res = await _api.getSupplierProducts(page: 1, pageSize: _pageSize);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(res.items);
        _page = res.page;
        _total = res.total;
      });
    } catch (err) {
      if (!mounted) return;
      _showError(err);
    } finally {
      if (mounted) setState(() => _isInitialLoading = false);
    }
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      final res = await _api.getSupplierProducts(page: 1, pageSize: _pageSize);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(res.items);
        _page = res.page;
        _total = res.total;
      });
    } catch (err) {
      if (!mounted) return;
      _showError(err);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _page + 1;
      final res = await _api.getSupplierProducts(
        page: nextPage,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(res.items);
        _page = res.page;
        _total = res.total;
      });
    } catch (err) {
      if (!mounted) return;
      _showError(err);
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _showError(Object err) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_compactError(err.toString()))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _isInitialLoading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 48,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No products yet',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Create your first product to start receiving pooled orders.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length + (_isLoadingMore ? 1 : 0),
                    separatorBuilder: (_, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index >= _items.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final product = _items[index];
                      final tile = Card(
                        elevation: 1,
                        child: ListTile(
                          onTap: () async {
                            final updated =
                                await Navigator.of(context).push<SupplierProduct>(
                              MaterialPageRoute<SupplierProduct>(
                                builder: (_) =>
                                    SupplierProductEditPage(product: product),
                              ),
                            );

                            if (!mounted) return;
                            if (updated == null) return;

                            setState(() {
                              final idx = _items.indexWhere(
                                (p) => p.id == updated.id,
                              );
                              if (idx >= 0) _items[idx] = updated;
                            });
                          },
                          title: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SKU: ${product.sku}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text(
                                      '${_formatPrice(product.price)} ${product.currency}',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Stock: ${product.stock}',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          trailing: _PoolStatusBadge(status: product.poolStatus),
                        ),
                      );

                      return product.isActive ? tile : Opacity(opacity: 0.6, child: tile);
                    },
                  ),
      ),
    );
  }
}

class _PoolStatusBadge extends StatelessWidget {
  final String status;

  const _PoolStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toUpperCase();
    final isOpen = normalized == 'OPEN';

    final bg = isOpen ? Colors.green : Colors.grey;
    final fg = Colors.white;
    final label = isOpen ? 'OPEN' : 'CLOSED';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

String _formatPrice(double value) {
  final isInt = value == value.roundToDouble();
  return isInt ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
}

String _compactError(String message) {
  final trimmed = message.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (trimmed.length <= 180) return trimmed;
  return '${trimmed.substring(0, 180)}...';
}
