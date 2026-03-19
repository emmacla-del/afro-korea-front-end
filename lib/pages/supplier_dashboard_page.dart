import 'dart:async';

import 'package:flutter/material.dart';
import '../api/supplier_api.dart';
import '../app/app_role.dart';
import '../services/api_service.dart';
import '../widgets/role_mode_banner.dart';
import 'catalog_import_page.dart';
import 'supplier_orders_page.dart';
import 'supplier_product_create_page.dart';
import 'supplier_products_page.dart';

// Statuses that allow requesting verification
const _requestableStatuses = {'UNVERIFIED', 'NOT_VERIFIED', 'NONE', 'REJECTED'};

class SupplierDashboardPage extends StatefulWidget {
  final AppRole currentRole;
  final ValueChanged<AppRole> onRoleChanged;
  final VoidCallback? onLogout;

  const SupplierDashboardPage({
    super.key,
    required this.currentRole,
    required this.onRoleChanged,
    this.onLogout,
  });

  @override
  State<SupplierDashboardPage> createState() => _SupplierDashboardPageState();
}

class _SupplierDashboardPageState extends State<SupplierDashboardPage> {
  SupplierDashboardStats _stats = SupplierDashboardStats.placeholder();
  bool _statsLoading = false;
  DateTime? _lastRefreshedAt;
  Timer? _ticker;

  Map<String, dynamic>? _userProfile;
  bool _profileLoading = true;
  String? _profileError;
  bool _requestingVerification = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _refreshStats();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadProfile() async {
    setState(() {
      _profileLoading = true;
      _profileError = null;
    });
    try {
      final profile = await ApiService.instance.getUserProfile();
      if (!mounted) return;
      setState(() {
        _userProfile = profile;
        _profileLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _profileError = e.toString();
        _profileLoading = false;
      });
    }
  }

  Future<void> _refreshStats() async {
    if (_statsLoading) return;
    setState(() => _statsLoading = true);
    try {
      final api = SupplierApi();
      final results = await Future.wait([
        api.getProductSummary(),
        api.getOrderSummary(),
        api.getLastCatalogImport(),
      ]);
      if (!mounted) return;
      final productSummary = results[0] as dynamic;
      final orderSummary = results[1] as dynamic;
      final latestImport = results[2] as dynamic;
      setState(() {
        _stats = SupplierDashboardStats(
          totalProducts: productSummary.total as int,
          openPoolProducts: productSummary.openPool as int,
          pendingPurchaseOrders: orderSummary.pending as int,
          shippedPurchaseOrders: orderSummary.shipped as int,
          lastCatalogImportAt: latestImport.lastImportedAt as DateTime?,
        );
        _lastRefreshedAt = DateTime.now();
      });
    } catch (_) {
      // Keep existing stats on error — no need to wipe the dashboard
    } finally {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  Future<void> _requestVerification() async {
    setState(() => _requestingVerification = true);
    try {
      final result = await ApiService.instance.requestSupplierVerification();
      if (!mounted) return;

      // Optimistic update: flip status to PENDING in local profile
      final updatedProfile = Map<String, dynamic>.from(_userProfile ?? {});
      final supplier = Map<String, dynamic>.from(
        (updatedProfile['supplier'] as Map?)?.cast<String, dynamic>() ?? {},
      );
      supplier['verificationStatus'] = 'PENDING';
      updatedProfile['supplier'] = supplier;

      setState(() => _userProfile = updatedProfile);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Verification request submitted'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _requestingVerification = false);
    }
  }

  // ── Verification card ──────────────────────────────────────────────────────

  Widget _buildVerificationCard() {
    if (_profileLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_profileError != null) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Could not load profile: $_profileError',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              TextButton(onPressed: _loadProfile, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final supplier = _userProfile?['supplier'];
    if (supplier == null) return const SizedBox.shrink();

    final status =
        (supplier['verificationStatus'] as String?)?.toUpperCase() ?? 'UNKNOWN';
    final canRequest = _requestableStatuses.contains(status);

    final (
      Color color,
      IconData icon,
      String label,
      String message,
    ) = switch (status) {
      'VERIFIED' => (
        Colors.green,
        Icons.verified,
        'Verified',
        'Your account is verified. You can create products and team deals.',
      ),
      'PENDING' => (
        Colors.orange,
        Icons.hourglass_top,
        'Pending review',
        'Your request is under review. We\'ll notify you once it\'s approved.',
      ),
      'REJECTED' => (
        Colors.red,
        Icons.cancel,
        'Rejected',
        'Your verification was rejected. You may apply again.',
      ),
      _ => (
        Colors.grey,
        Icons.help_outline,
        'Not verified',
        'Submit a verification request to start selling on the platform.',
      ),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Account Verification',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            if (canRequest) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _requestingVerification
                      ? null
                      : _requestVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: _requestingVerification
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, size: 16),
                  label: Text(
                    status == 'REJECTED'
                        ? 'Re-apply for Verification'
                        : 'Request Verification',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          RoleModeBanner(
            currentRole: widget.currentRole,
            onRoleChanged: widget.onRoleChanged,
          ),
          const SizedBox(height: 12),

          _buildVerificationCard(),

          _QuickAddCard(
            isLoading: _statsLoading,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SupplierProductCreatePage(),
              ),
            ),
          ),
          const SizedBox(height: 12),

          _DashboardStatRow(
            isLoading: _statsLoading,
            lastRefreshedAt: _lastRefreshedAt,
            onRefresh: _refreshStats,
          ),
          const SizedBox(height: 12),

          _DashboardNavCard(
            title: 'Products',
            subtitle:
                '${_stats.totalProducts} total · ${_stats.openPoolProducts} with open pools',
            leadingIcon: Icons.inventory_2,
            trailing: _CountPills(
              pills: [
                _Pill(label: 'Total', value: _stats.totalProducts),
                _Pill(label: 'Open', value: _stats.openPoolProducts),
              ],
            ),
            enabled: !_statsLoading,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SupplierProductsPage(),
              ),
            ),
          ),
          const SizedBox(height: 12),

          _DashboardNavCard(
            title: 'Purchase Orders',
            subtitle:
                '${_stats.pendingPurchaseOrders} pending · ${_stats.shippedPurchaseOrders} shipped',
            leadingIcon: Icons.receipt_long,
            trailing: _CountPills(
              pills: [
                _Pill(label: 'Pending', value: _stats.pendingPurchaseOrders),
                _Pill(label: 'Shipped', value: _stats.shippedPurchaseOrders),
              ],
            ),
            enabled: !_statsLoading,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SupplierOrdersPage(),
              ),
            ),
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
            enabled: !_statsLoading,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CatalogImportPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

String _formatDateTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  return '${dt.day}/${dt.month}/${dt.year}';
}

// ── Sub-widgets (unchanged from your original) ────────────────────────────────

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
    this.lastCatalogImportAt,
  });

  factory SupplierDashboardStats.placeholder() => const SupplierDashboardStats(
    totalProducts: 0,
    openPoolProducts: 0,
    pendingPurchaseOrders: 0,
    shippedPurchaseOrders: 0,
  );
}

class _Pill {
  final String label;
  final int value;
  const _Pill({required this.label, required this.value});
}

class _CountPills extends StatelessWidget {
  final List<_Pill> pills;
  const _CountPills({required this.pills});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: pills
          .map(
            (p) => Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${p.value} ${p.label}',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          )
          .toList(),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.add_box, color: Color(0xFF00C471)),
        title: const Text(
          'Add New Product',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text('Create a product listing'),
        trailing: const Icon(Icons.chevron_right),
        enabled: !isLoading,
        onTap: onPressed,
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
    final label = lastRefreshedAt == null
        ? 'Never refreshed'
        : 'Updated ${_formatDateTime(lastRefreshedAt!)}';
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        const Spacer(),
        if (isLoading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: onRefresh,
            tooltip: 'Refresh',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          leadingIcon,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: trailing,
        enabled: enabled,
        onTap: onTap,
      ),
    );
  }
}
