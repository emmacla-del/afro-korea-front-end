import 'package:flutter/material.dart';
import '../app/app_role.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../widgets/product_card.dart';
import 'admin_dashboard_page.dart';

class HomePage extends StatefulWidget {
  final AppRole currentRole;
  final ValueChanged<AppRole> onRoleChanged;
  final VoidCallback onLogout;
  final bool isAdmin; // true for admin users

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Afro-Korea Pool App'),
        actions: [
          // Admin button – shown only for admins
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              tooltip: 'Admin Dashboard',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        AdminDashboardPage(onLogout: widget.onLogout),
                  ),
                );
              },
            ),
          // Role switch button – hidden for admins
          if (!widget.isAdmin)
            IconButton(
              tooltip: 'Switch role',
              icon: Icon(
                widget.currentRole == AppRole.supplier
                    ? Icons.person
                    : Icons.person_outline,
              ),
              onPressed: () {
                final newRole = widget.currentRole == AppRole.supplier
                    ? AppRole.customer
                    : AppRole.supplier;
                widget.onRoleChanged(newRole);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Switched to ${newRole == AppRole.supplier ? 'Supplier' : 'Customer'} mode',
                    ),
                  ),
                );
              },
            ),
          // Logout button – shown for everyone
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: widget.onLogout,
          ),
        ],
        backgroundColor: widget.currentRole == AppRole.supplier
            ? Colors.green
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: _loadProducts,
        child: CustomScrollView(
          slivers: [
            // Supplier mode banner (only if current role is supplier)
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
            // Product grid or loading/error
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
                        return ProductCard(
                          product: product,
                          onTap: () {
                            // TODO: Navigate to product details
                          },
                          onLongPress: () {},
                          onJoinPool: () {
                            // TODO: Join pool logic
                          },
                          onBuyNow: () {
                            // TODO: Buy now logic
                          },
                        );
                      }, childCount: _products.length),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'My Pools'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Navigate to cart/pools
        },
        child: Icon(Icons.shopping_cart),
      ),
    );
  }
}
