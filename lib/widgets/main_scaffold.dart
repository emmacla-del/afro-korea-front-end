import 'package:flutter/material.dart';
import '../app/app_role.dart';
import '../pages/home_page.dart';
import '../pages/profile_page.dart';
import '../pages/supplier_dashboard_page.dart';
import '../pages/supplier_products_page.dart';
import '../pages/supplier_orders_page.dart';
import '../pages/admin_dashboard_page.dart';
import '../pages/my_orders_page.dart';
import '../pages/supplier_product_create_page.dart';
import '../pages/team_deals_page.dart'; // used for drawer
import '../services/api_service.dart';

class MainScaffold extends StatefulWidget {
  final AppRole role;
  final ValueChanged<AppRole> onRoleChanged;
  final VoidCallback onLogout;

  const MainScaffold({
    super.key,
    required this.role,
    required this.onRoleChanged,
    required this.onLogout,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  late List<({IconData icon, String label, Widget page})> _pages;

  @override
  void initState() {
    super.initState();
    _pages = _buildPagesForRole(widget.role);
  }

  @override
  void didUpdateWidget(covariant MainScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != widget.role) {
      setState(() {
        _pages = _buildPagesForRole(widget.role);
        _selectedIndex = 0;
      });
    }
  }

  List<({IconData icon, String label, Widget page})> _buildPagesForRole(
    AppRole role,
  ) {
    switch (role) {
      case AppRole.customer:
        return [
          (
            icon: Icons.home,
            label: 'Home',
            page: HomePage(
              currentRole: role,
              onRoleChanged: widget.onRoleChanged,
              onLogout: widget.onLogout,
              isAdmin: false,
            ),
          ),
          (
            icon: Icons.shopping_bag,
            label: 'My Orders',
            page: const MyOrdersPage(),
          ),
          (
            icon: Icons.person,
            label: 'Profile',
            page: ProfilePage(onLogout: widget.onLogout),
          ),
        ];
      case AppRole.supplier:
        // Suppliers get both customer and supplier tabs
        return [
          // Customer‑facing tabs
          (
            icon: Icons.home,
            label: 'Home',
            page: HomePage(
              currentRole: role,
              onRoleChanged: widget.onRoleChanged,
              onLogout: widget.onLogout,
              isAdmin: false,
            ),
          ),
          (
            icon: Icons.shopping_bag,
            label: 'My Orders',
            page: const MyOrdersPage(),
          ),
          // Supplier‑specific tabs
          (
            icon: Icons.dashboard,
            label: 'Dashboard',
            page: SupplierDashboardPage(
              currentRole: role,
              onRoleChanged: widget.onRoleChanged,
              onLogout: widget.onLogout,
            ),
          ),
          (
            icon: Icons.inventory_2,
            label: 'Products',
            page: const SupplierProductsPage(),
          ),
          (
            icon: Icons.person,
            label: 'Profile',
            page: ProfilePage(onLogout: widget.onLogout),
          ),
        ];
      case AppRole.admin:
        return [
          (
            icon: Icons.admin_panel_settings,
            label: 'Admin',
            page: AdminDashboardPage(onLogout: widget.onLogout),
          ),
          (
            icon: Icons.person,
            label: 'Profile',
            page: ProfilePage(onLogout: widget.onLogout),
          ),
        ];
    }
  }

  Widget? _buildFAB() {
    switch (widget.role) {
      case AppRole.supplier:
        return FloatingActionButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const SupplierProductCreatePage(),
            ),
          ),
          child: const Icon(Icons.add),
        );
      case AppRole.customer:
      case AppRole.admin:
        return null;
    }
  }

  String _getTitleForRole(AppRole role) {
    switch (role) {
      case AppRole.customer:
        return 'Afro Korea Pool';
      case AppRole.supplier:
        return 'Supplier Dashboard';
      case AppRole.admin:
        return 'Admin Dashboard';
    }
  }

  Future<void> _handleCheckIn() async {
    try {
      final result = await ApiService.instance.checkIn();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Check-in successful! Reward: ${result['reward'] ?? 'none'}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitleForRole(widget.role)),
        actions: [
          if (widget.role == AppRole.customer)
            IconButton(
              icon: const Icon(Icons.calendar_today),
              tooltip: 'Daily Check‑in',
              onPressed: _handleCheckIn,
            ),
          // Role switch button removed – now suppliers have combined navigation
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages.map((p) => p.page).toList(),
      ),
      bottomNavigationBar: SafeArea(
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: theme.primaryColor,
          unselectedItemColor: Colors.grey[600],
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
          items: _pages
              .map(
                (p) =>
                    BottomNavigationBarItem(icon: Icon(p.icon), label: p.label),
              )
              .toList(),
        ),
      ),
      floatingActionButton: _buildFAB(),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF00C471)),
              child: Text(
                'Menu',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            if (widget.role == AppRole.customer)
              ListTile(
                leading: const Icon(Icons.groups),
                title: const Text('My Team Deals'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TeamDealsPage()),
                  );
                },
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: widget.onLogout,
            ),
          ],
        ),
      ),
    );
  }
}
