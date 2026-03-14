import 'package:flutter/material.dart';
import 'app/app_role.dart';
import 'pages/login_screen.dart';
import 'pages/register_screen.dart';
import 'services/api_service.dart';
import 'services/user_store.dart';
import 'widgets/main_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AfroKoreaApp());
}

class AfroKoreaApp extends StatelessWidget {
  const AfroKoreaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Afro Korea Pool',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
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
  AppRole? _role;
  bool _showRegister = false;

  void _onAuthenticated() async {
    // Read the role that LoginScreen saved to UserStore
    final roleStr = await UserStore.getUserRole();
    final role = switch (roleStr?.toUpperCase()) {
      'SUPPLIER' => AppRole.supplier,
      'ADMIN' => AppRole.admin,
      _ => AppRole.customer,
    };
    if (!mounted) return;
    setState(() {
      _role = role;
      _showRegister = false;
    });
  }

  void _onLogout() async {
    await UserStore.clearAll(); // Use clearAll() as defined in your UserStore
    ApiService.instance.clearBearerToken();
    if (!mounted) return;
    setState(() => _role = null);
  }

  void _onRoleChanged(AppRole newRole) {
    setState(() => _role = newRole);
  }

  @override
  Widget build(BuildContext context) {
    // Logged in
    if (_role != null) {
      return MainScaffold(
        role: _role!,
        onRoleChanged: _onRoleChanged,
        onLogout: _onLogout,
      );
    }

    // Register screen – note: using onAuthenticated, not onRegistered
    if (_showRegister) {
      return RegisterScreen(
        onAuthenticated: _onAuthenticated,
        onGoToLogin: () => setState(() => _showRegister = false),
      );
    }

    // Login screen (default)
    return LoginScreen(
      onAuthenticated: _onAuthenticated,
      onGoToRegister: () => setState(() => _showRegister = true),
    );
  }
}
