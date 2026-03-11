import 'package:flutter/material.dart';
import '../app/app_role.dart';

class HomePage extends StatefulWidget {
  final AppRole? currentRole;
  final ValueChanged<AppRole>? onRoleChanged;
  final VoidCallback? onLogout; // 👈 new parameter

  const HomePage({
    super.key,
    this.currentRole,
    this.onRoleChanged,
    this.onLogout,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Afro-Korea Pool App'),
        actions: [
          // Role switch button
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
              widget.onRoleChanged?.call(newRole);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Switched to ${newRole == AppRole.supplier ? 'Supplier' : 'Customer'} mode',
                  ),
                ),
              );
            },
          ),
          // Logout button
          if (widget.onLogout != null)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () => widget.onLogout!(),
            ),
        ],
        backgroundColor: widget.currentRole == AppRole.supplier
            ? Colors.green
            : null,
      ),
      body: Column(
        children: [
          if (widget.currentRole == AppRole.supplier)
            Container(
              width: double.infinity,
              color: Colors.green[50],
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
          Expanded(
            child: Center(
              child: Text(
                'Welcome, ${widget.currentRole == AppRole.supplier ? 'Supplier' : 'Customer'}!',
              ),
            ),
          ),
        ],
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
          // Navigate to cart/pools
        },
        child: Icon(Icons.shopping_cart),
      ),
    );
  }
}
