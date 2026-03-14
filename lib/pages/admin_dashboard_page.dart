import 'package:flutter/material.dart';

class AdminDashboardPage extends StatelessWidget {
  final VoidCallback onLogout;

  const AdminDashboardPage({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Admin Dashboard - Coming Soon',
        style: TextStyle(fontSize: 24),
      ),
    );
  }
}
