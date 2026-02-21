/*
AFRO-KOREA POOL - DUAL SUPPLY MARKETS
Buyers in Cameroon pool orders from:
1. 🇳🇬 Nigerian suppliers (faster, cheaper)
2. 🇰🇷 Korean suppliers (premium, unique)
Features:
- Supplier origin filtering
- MOQ pooling with progress bars
- Mobile Money payments (MTN, Orange)
- Real-time pool tracking
*/

import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/supplier_dashboard_page.dart';
import 'app/app_role.dart';
import 'services/user_store.dart';

/// Initialize UserStore: check for saved supplier UUID, or save test UUID if none exists
Future<void> _initializeUserStore() async {
  final existingUserId = await UserStore.getUserId();
  
  if (existingUserId != null && existingUserId.isNotEmpty) {
    debugPrint('✅ UserStore: Using existing supplier UUID: $existingUserId');
    return;
  }
  
  // No user ID found, save test supplier UUID
  const testSupplierUuid = '550e8400-e29b-41d4-a716-446655440000';
  await UserStore.saveUserId(testSupplierUuid);
  debugPrint('✅ UserStore: Initialized with test supplier UUID: $testSupplierUuid');
  debugPrint('💡 Tip: All API calls to /supplier/* endpoints will now include x-user-id header');
}

// Main app entry point - initialize UserStore before running app
void main() async {
  await _initializeUserStore();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  AppRole _role = AppRole.customer;

  void _setRole(AppRole role) {
    if (role == _role) return;
    setState(() => _role = role);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Afro-Korea Pool App',
      // FIXED: Change theme dynamically based on role (customer: blue, supplier: green)
      theme: ThemeData(primarySwatch: _role == AppRole.supplier ? Colors.green : Colors.blue),
      home: _role == AppRole.customer
          ? HomePage(
              currentRole: _role,
              onRoleChanged: _setRole,
            )
          : SupplierDashboardPage(
              currentRole: _role,
              onRoleChanged: _setRole,
            ),
    );
  }
}
