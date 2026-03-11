import 'package:flutter/material.dart';

import '../api/supplier_api.dart';
import '../models/supplier_order.dart';

class SupplierOrdersPage extends StatefulWidget {
  const SupplierOrdersPage({super.key});

  @override
  State<SupplierOrdersPage> createState() => _SupplierOrdersPageState();
}

class _SupplierOrdersPageState extends State<SupplierOrdersPage> {
  final SupplierApi _api = SupplierApi();
  final ScrollController _scrollController = ScrollController();

  static const int _pageSize = 20;

  final List<SupplierOrder> _orders = <SupplierOrder>[];
  int _page = 1;
  int _total = 0;

  bool _isLoadingInitial = false;
  bool _isLoadingMore = false;
  final Set<String> _shippingOrderIds = <String>{};

  bool get _hasMore => _orders.length < _total;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_isLoadingInitial || _isLoadingMore) return;
    if (!_hasMore) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    if (_isLoadingInitial) return;
    setState(() => _isLoadingInitial = true);
    try {
      final response = await _api.getSupplierOrders(
        page: 1,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _orders
          ..clear()
          ..addAll(response.items);
        _page = response.page;
        _total = response.total;
      });
    } catch (err) {
      if (!mounted) return;
      _showError(err);
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _refresh() async {
    try {
      final response = await _api.getSupplierOrders(
        page: 1,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _orders
          ..clear()
          ..addAll(response.items);
        _page = response.page;
        _total = response.total;
      });
    } catch (err) {
      if (!mounted) return;
      _showError(err);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    if (!_hasMore) return;

    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final response = await _api.getSupplierOrders(
        page: nextPage,
        pageSize: _pageSize,
      );

      if (!mounted) return;
      setState(() {
        _orders.addAll(response.items);
        _page = response.page;
        _total = response.total;
      });
    } catch (err) {
      if (!mounted) return;
      _showError(err);
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _confirmAndShip(SupplierOrder order) async {
    if (_shippingOrderIds.contains(order.id)) return;
    if (order.status.toUpperCase() != 'PENDING') return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as shipped?'),
        content: Text(
          'This will update ${order.orderNumber} to SHIPPED. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _shippingOrderIds.add(order.id));
    try {
      final result = await _api.markOrderAsShipped(order.id);
      if (!mounted) return;
      setState(() {
        final index = _orders.indexWhere((o) => o.id == order.id);
        if (index >= 0) {
          _orders[index] = _orders[index].copyWith(
            status: result.status.isEmpty ? 'SHIPPED' : result.status,
            shippedAt: result.shippedAt ?? _orders[index].shippedAt,
          );
        }
      });
      _showSnackBar('Order marked as shipped');
    } catch (err) {
      if (!mounted) return;
      _showError(err);
    } finally {
      if (mounted) {
        setState(() => _shippingOrderIds.remove(order.id));
      }
    }
  }

  void _showError(Object err) {
    final message = err is ApiException
        ? (err.message?.isNotEmpty == true
              ? err.message!
              : 'Request failed (${err.statusCode})')
        : 'Something went wrong. Please try again.';
    _showSnackBar(message);
  }

  void _showSnackBar(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = !_isLoadingInitial && _orders.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Purchase Orders')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _isLoadingInitial
            ? const Center(child: CircularProgressIndicator())
            : isEmpty
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 120),
                  Icon(
                    Icons.receipt_long,
                    size: 44,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No purchase orders yet',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              )
            : ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _orders.length + (_isLoadingMore ? 1 : 0),
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index >= _orders.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final order = _orders[index];
                  final status = order.status.toUpperCase();
                  final canShip = status == 'PENDING';
                  final isShipping = _shippingOrderIds.contains(order.id);

                  return Card(
                    elevation: 1,
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              order.orderNumber.isEmpty
                                  ? 'Purchase Order'
                                  : order.orderNumber,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _StatusChip(status: status),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (order.buyerName.isNotEmpty)
                              Text('Buyer: ${order.buyerName}'),
                            Text(
                              'Total: ${_formatMoney(order.totalAmount)} ${order.currency}',
                            ),
                            Text('Created: ${_formatDate(order.createdAt)}'),
                            if (order.shippedAt != null)
                              Text('Shipped: ${_formatDate(order.shippedAt!)}'),
                          ],
                        ),
                      ),
                      children: [
                        const Divider(height: 1),
                        if (order.items.isEmpty)
                          const ListTile(title: Text('No line items'))
                        else
                          ...order.items.map(
                            (item) => ListTile(
                              title: Text(item.productName),
                              subtitle: Text(
                                'Qty: ${item.quantity} | Unit: ${_formatMoney(item.unitPrice)}',
                              ),
                            ),
                          ),
                        if (canShip)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: isShipping
                                    ? null
                                    : () => _confirmAndShip(order),
                                icon: isShipping
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.local_shipping_outlined),
                                label: const Text('Mark as shipped'),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final statusUpper = status.toUpperCase();

    final (label, color) = switch (statusUpper) {
      'PENDING' => ('PENDING', Colors.orange),
      'SHIPPED' => ('SHIPPED', Colors.green),
      _ => (statusUpper.isEmpty ? 'UNKNOWN' : statusUpper, Colors.grey),
    };

    return Chip(
      label: Text(
        label,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      visualDensity: VisualDensity.compact,
      backgroundColor: color,
      side: BorderSide(color: Colors.black.withAlpha(20)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}

String _formatDate(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String _formatMoney(double amount) {
  final rounded = amount.toStringAsFixed(2);
  if (rounded.endsWith('.00')) return rounded.substring(0, rounded.length - 3);
  return rounded;
}
