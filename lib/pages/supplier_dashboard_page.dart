import 'dart:async';

import 'package:flutter/material.dart';
import '../api/supplier_api.dart';
import '../app/app_role.dart';
import '../widgets/role_mode_banner.dart';
import '../widgets/role_switch_action.dart';
import 'catalog_import_page.dart';
import 'supplier_orders_page.dart';
import 'supplier_product_create_page.dart';
import 'supplier_products_page.dart';

class SupplierDashboardPage extends StatefulWidget {
  final AppRole currentRole;
  final ValueChanged<AppRole> onRoleChanged;

  const SupplierDashboardPage({
    super.key,
    required this.currentRole,
    required this.onRoleChanged,
  });

  @override
  State<SupplierDashboardPage> createState() => _SupplierDashboardPageState();
}

class _SupplierDashboardPageState extends State<SupplierDashboardPage> {
  SupplierDashboardStats _stats = SupplierDashboardStats.placeholder();
  bool _isLoading = false;
  DateTime? _lastRefreshedAt;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _refreshStats();

    // Keeps "last import" and other timestamps fresh, and makes it easy to
    // turn these into real-time API-driven stats later.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _refreshStats() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final api = SupplierApi();

      final productSummaryFuture = api.getProductSummary();
      final orderSummaryFuture = api.getOrderSummary();
      final latestImportFuture = api.getLastCatalogImport();

      final productSummary = await productSummaryFuture;
      final orderSummary = await orderSummaryFuture;
      final latestImport = await latestImportFuture;

      if (!mounted) return;
      setState(() {
        _stats = SupplierDashboardStats(
          totalProducts: productSummary.total,
          openPoolProducts: productSummary.openPool,
          pendingPurchaseOrders: orderSummary.pending,
          shippedPurchaseOrders: orderSummary.shipped,
          lastCatalogImportAt: latestImport.lastImportedAt,
        );
        _lastRefreshedAt = DateTime.now();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _stats = _stats;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier'),
        actions: [
          RoleSwitchAction(
            currentRole: widget.currentRole,
            onRoleChanged: widget.onRoleChanged,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshStats,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            RoleModeBanner(
              currentRole: widget.currentRole,
              onRoleChanged: widget.onRoleChanged,
            ),
            const SizedBox(height: 12),
            _QuickAddCard(
              isLoading: _isLoading,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SupplierProductCreatePage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _DashboardStatRow(
              isLoading: _isLoading,
              lastRefreshedAt: _lastRefreshedAt,
              onRefresh: () => _refreshStats(),
            ),
            const SizedBox(height: 12),
            _DashboardNavCard(
              title: 'Products',
              subtitle:
                  '${_stats.totalProducts} total | ${_stats.openPoolProducts} with OPEN pools',
              leadingIcon: Icons.inventory_2,
              trailing: _CountPills(
                pills: [
                  _Pill(label: 'Total', value: _stats.totalProducts),
                  _Pill(label: 'Open', value: _stats.openPoolProducts),
                ],
              ),
              enabled: !_isLoading,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SupplierProductsPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _DashboardNavCard(
              title: 'Purchase Orders',
              subtitle:
                  '${_stats.pendingPurchaseOrders} pending | ${_stats.shippedPurchaseOrders} shipped',
              leadingIcon: Icons.receipt_long,
              trailing: _CountPills(
                pills: [
                  _Pill(label: 'Pending', value: _stats.pendingPurchaseOrders),
                  _Pill(label: 'Shipped', value: _stats.shippedPurchaseOrders),
                ],
              ),
              enabled: !_isLoading,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SupplierOrdersPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _DashboardNavCard(
              title: 'Catalog Import',
              subtitle: _stats.lastCatalogImportAt == null
                  ? 'No imports yet'
                  : 'Last import: ${_formatDateTime(_stats.lastCatalogImportAt!)}',
              leadingIcon: Icons.upload_file,
              trailing: Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.outline,
              ),
              enabled: !_isLoading,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CatalogImportPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class SupplierDashboardStats {
  final int totalProducts;
  final int openPoolProducts;
  final int pendingPurchaseOrders;
  final int shippedPurchaseOrders;
  final DateTime? lastCatalogImportAt;

  const SupplierDashboardStats({
    required this.totalProducts,
    required this.openPoolProducts,
    required this.pendingPurchaseOrders,
    required this.shippedPurchaseOrders,
    required this.lastCatalogImportAt,
  });

  factory SupplierDashboardStats.placeholder() {
    // TODO(API): Replace with real counts from the backend.
    return SupplierDashboardStats(
      totalProducts: 12,
      openPoolProducts: 3,
      pendingPurchaseOrders: 5,
      shippedPurchaseOrders: 2,
      lastCatalogImportAt: DateTime.now().subtract(const Duration(days: 2)),
    );
  }
}

class _QuickAddCard extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _QuickAddCard({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.add_box_outlined, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Add Product',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Create a product and its first variant',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: isLoading ? null : onPressed,
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardStatRow extends StatelessWidget {
  final bool isLoading;
  final DateTime? lastRefreshedAt;
  final VoidCallback onRefresh;

  const _DashboardStatRow({
    required this.isLoading,
    required this.lastRefreshedAt,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final text = isLoading
        ? 'Refreshing...'
        : lastRefreshedAt == null
        ? 'Pull to refresh'
        : 'Updated ${_formatRelative(lastRefreshedAt!)}';

    return Row(
      children: [
        Icon(
          isLoading ? Icons.sync : Icons.info_outline,
          size: 16,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: isLoading ? null : onRefresh,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Refresh'),
        ),
      ],
    );
  }
}

class _DashboardNavCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData leadingIcon;
  final Widget trailing;
  final bool enabled;
  final VoidCallback onTap;

  const _DashboardNavCard({
    required this.title,
    required this.subtitle,
    required this.leadingIcon,
    required this.trailing,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: ListTile(
        enabled: enabled,
        onTap: enabled ? onTap : null,
        leading: Icon(leadingIcon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: trailing,
      ),
    );
  }
}

class _CountPills extends StatelessWidget {
  final List<_Pill> pills;

  const _CountPills({required this.pills});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: pills
          .map(
            (p) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withAlpha(60),
                ),
              ),
              child: Text(
                '${p.label}: ${p.value}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _Pill {
  final String label;
  final int value;

  const _Pill({required this.label, required this.value});
}

String _formatDateTime(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm';
}

String _formatRelative(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 10) return 'just now';
  if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
