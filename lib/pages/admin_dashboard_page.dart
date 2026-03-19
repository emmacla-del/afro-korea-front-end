import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AdminDashboardPage extends StatefulWidget {
  final VoidCallback onLogout;

  const AdminDashboardPage({super.key, required this.onLogout});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // ── Suppliers tab state ───────────────────────────────────────────────────
  List<Map<String, dynamic>> _pendingSuppliers = [];
  bool _suppliersLoading = true;
  String? _suppliersError;

  // ── Users tab state ───────────────────────────────────────────────────────
  List<Map<String, dynamic>> _users = [];
  bool _usersLoading = true;
  String? _usersError;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPendingSuppliers();
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadPendingSuppliers() async {
    setState(() {
      _suppliersLoading = true;
      _suppliersError = null;
    });
    try {
      final suppliers = await ApiService.instance.fetchPendingSuppliers();
      if (!mounted) return;
      setState(() {
        _pendingSuppliers = suppliers;
        _suppliersLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _suppliersError = e.toString();
        _suppliersLoading = false;
      });
    }
  }

  Future<void> _loadUsers() async {
    setState(() {
      _usersLoading = true;
      _usersError = null;
    });
    try {
      final users = await ApiService.instance.fetchAllUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _usersLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _usersError = e.toString();
        _usersLoading = false;
      });
    }
  }

  // ── Supplier actions ──────────────────────────────────────────────────────

  Future<void> _verifySupplier(String supplierId) async {
    try {
      await ApiService.instance.verifySupplier(supplierId);
      _loadPendingSuppliers();
      _showSnack('Supplier verified', color: Colors.green);
    } catch (e) {
      _showSnack('Error: $e', color: Colors.red);
    }
  }

  Future<void> _rejectSupplier(String supplierId) async {
    try {
      await ApiService.instance.rejectSupplier(supplierId);
      _loadPendingSuppliers();
      _showSnack('Supplier rejected');
    } catch (e) {
      _showSnack('Error: $e', color: Colors.red);
    }
  }

  // ── User block/unblock actions ────────────────────────────────────────────

  Future<void> _toggleBlock(Map<String, dynamic> user) async {
    final isBlocked = user['isBlocked'] as bool? ?? false;
    final userId = user['id'] as String;
    final name = user['name'] ?? user['phone'] ?? userId;

    // Confirm before blocking
    if (!isBlocked) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Block user?'),
          content: Text('This will immediately lock $name out of the app.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Block'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      if (isBlocked) {
        await ApiService.instance.unblockUser(userId);
        _showSnack('$name unblocked', color: Colors.green);
      } else {
        await ApiService.instance.blockUser(userId);
        _showSnack('$name blocked');
      }
      _loadUsers();
    } catch (e) {
      _showSnack('Error: $e', color: Colors.red);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _showSnack(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    final q = _searchQuery.toLowerCase();
    return _users.where((u) {
      final name = (u['name'] ?? '').toString().toLowerCase();
      final phone = (u['phone'] ?? '').toString().toLowerCase();
      return name.contains(q) || phone.contains(q);
    }).toList();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadPendingSuppliers();
              _loadUsers();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.pending_actions),
              text: 'Suppliers (${_pendingSuppliers.length})',
            ),
            const Tab(icon: Icon(Icons.people), text: 'Users'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildSuppliersTab(), _buildUsersTab()],
      ),
    );
  }

  // ── Suppliers tab ─────────────────────────────────────────────────────────

  Widget _buildSuppliersTab() {
    if (_suppliersLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_suppliersError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_suppliersError'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPendingSuppliers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadPendingSuppliers,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Overview card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Overview',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Pending',
                          _pendingSuppliers.length.toString(),
                          Icons.pending_actions,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Total Users',
                          _users.length.toString(),
                          Icons.people,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Blocked',
                          _users
                              .where((u) => u['isBlocked'] == true)
                              .length
                              .toString(),
                          Icons.block,
                          Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Pending Supplier Verifications',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_pendingSuppliers.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No pending suppliers'),
              ),
            )
          else
            ..._pendingSuppliers.map(_buildSupplierTile),
        ],
      ),
    );
  }

  Widget _buildSupplierTile(Map<String, dynamic> supplier) {
    final owner = supplier['owner'] as Map<String, dynamic>?;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              supplier['displayName'] ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text('Country: ${supplier['country'] ?? 'N/A'}'),
            Text('City: ${supplier['city'] ?? 'N/A'}'),
            Text('Business Reg: ${supplier['businessRegNumber'] ?? 'N/A'}'),
            if (owner != null) Text('Phone: ${owner['phone'] ?? 'N/A'}'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _verifySupplier(supplier['id']),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Verify'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _rejectSupplier(supplier['id']),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Users tab ─────────────────────────────────────────────────────────────

  Widget _buildUsersTab() {
    if (_usersLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_usersError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_usersError'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadUsers, child: const Text('Retry')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or phone…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(
            child: _filteredUsers.isEmpty
                ? const Center(child: Text('No users found'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: _filteredUsers.length,
                    itemBuilder: (_, i) => _buildUserTile(_filteredUsers[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final isBlocked = user['isBlocked'] as bool? ?? false;
    final role = (user['role'] ?? 'CUSTOMER').toString();
    final name = user['name'] as String?;
    final phone = user['phone'] as String? ?? 'No phone';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isBlocked
            ? BorderSide(color: Colors.red.shade200)
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isBlocked
              ? Colors.red.shade50
              : _roleColor(role).withValues(alpha: 0.1),
          child: Icon(
            isBlocked ? Icons.block : _roleIcon(role),
            color: isBlocked ? Colors.red.shade600 : _roleColor(role),
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                name ?? phone,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            _RolePill(role: role),
            if (isBlocked) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  'Blocked',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: name != null
            ? Text(phone, style: const TextStyle(fontSize: 12))
            : null,
        trailing: IconButton(
          tooltip: isBlocked ? 'Unblock user' : 'Block user',
          icon: Icon(
            isBlocked ? Icons.lock_open : Icons.block,
            color: isBlocked ? Colors.green : Colors.red.shade400,
          ),
          onPressed: () => _toggleBlock(user),
        ),
      ),
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────────────

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(title, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  IconData _roleIcon(String role) {
    return switch (role) {
      'ADMIN' => Icons.admin_panel_settings,
      'SUPPLIER' => Icons.store,
      _ => Icons.person,
    };
  }

  Color _roleColor(String role) {
    return switch (role) {
      'ADMIN' => Colors.purple,
      'SUPPLIER' => const Color(0xFF00C471),
      _ => Colors.blue,
    };
  }
}

// ── Role pill widget ──────────────────────────────────────────────────────────

class _RolePill extends StatelessWidget {
  final String role;
  const _RolePill({required this.role});

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      'ADMIN' => Colors.purple,
      'SUPPLIER' => const Color(0xFF00C471),
      _ => Colors.blue,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
