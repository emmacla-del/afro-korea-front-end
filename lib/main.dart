import 'package:flutter/material.dart';

import 'app/app_role.dart';
import 'pages/home_page.dart';
import 'pages/login_screen.dart';
import 'pages/register_screen.dart';
import 'pages/supplier_dashboard_page.dart';
import 'pages/admin_dashboard_page.dart';
import 'services/api_service.dart';
import 'services/user_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Afro-Korea Pool App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _showRegister = false;
  bool _isAuthenticated = false;
  AppRole _role = AppRole.customer;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final token = await UserStore.getToken();
    final role = await UserStore.getUserRole();

    if (token != null && token.isNotEmpty) {
      ApiService.instance.setBearerToken(token);
      _isAuthenticated = true;
      _role = _parseRole(role);
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _onAuthenticated() async {
    final role = await UserStore.getUserRole();
    if (!mounted) return;
    setState(() {
      _isAuthenticated = true;
      _showRegister = false;
      _role = _parseRole(role);
    });
  }

  Future<void> _logout() async {
    await UserStore.clearAll();
    ApiService.instance.clearBearerToken();
    if (!mounted) return;
    setState(() {
      _isAuthenticated = false;
      _showRegister = false;
      _role = AppRole.customer;
    });
  }

  void _setRole(AppRole role) {
    if (role == _role) return;
    setState(() => _role = role);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isAuthenticated) {
      if (_showRegister) {
        return RegisterScreen(
          onAuthenticated: _onAuthenticated,
          onGoToLogin: () => setState(() => _showRegister = false),
        );
      }

      return LoginScreen(
        onAuthenticated: _onAuthenticated,
        onGoToRegister: () => setState(() => _showRegister = true),
      );
    }

    // Role-based routing
    if (_role == AppRole.admin) {
      // Admin sees home page with admin button
      return HomePage(
        currentRole: AppRole.customer,
        onRoleChanged: _setRole,
        onLogout: _logout,
        isAdmin: true,
      );
    } else if (_role == AppRole.supplier) {
      return SupplierDashboardPage(
        currentRole: _role,
        onRoleChanged: _setRole,
        onLogout: _logout,
      );
    } else {
      return HomePage(
        currentRole: _role,
        onRoleChanged: _setRole,
        onLogout: _logout,
        isAdmin: false,
      );
    }
  }
}

AppRole _parseRole(String? role) {
  final upper = (role ?? '').trim().toUpperCase();
  if (upper == 'SUPPLIER') {
    return AppRole.supplier;
  }
  if (upper == 'ADMIN') {
    return AppRole.admin;
  }
  return AppRole.customer;
}
