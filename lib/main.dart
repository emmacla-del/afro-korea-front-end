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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00C471),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(0),
            side: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFF5F5F5),
          thickness: 8,
        ),
      ),
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
  String? _initialReferralCode; // 👈 stores referral code from deep link

  @override
  void initState() {
    super.initState();
    _parseInitialReferralCode();
  }

  /// Reads the initial URI and extracts the 'ref' query parameter.
  void _parseInitialReferralCode() {
    try {
      final uri = Uri.base;
      final ref = uri.queryParameters['ref'];
      if (ref != null && ref.isNotEmpty) {
        _initialReferralCode = ref;
        debugPrint('📩 Initial referral code: $_initialReferralCode');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to parse referral code: $e');
    }
  }

  void _onAuthenticated() async {
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
    await UserStore.clearAll();
    ApiService.instance.clearBearerToken();
    if (!mounted) return;
    setState(() => _role = null);
  }

  void _onRoleChanged(AppRole newRole) {
    setState(() => _role = newRole);
  }

  @override
  Widget build(BuildContext context) {
    if (_role != null) {
      return MainScaffold(
        role: _role!,
        onRoleChanged: _onRoleChanged,
        onLogout: _onLogout,
      );
    }
    if (_showRegister) {
      return RegisterScreen(
        onAuthenticated: _onAuthenticated,
        onGoToLogin: () => setState(() => _showRegister = false),
        initialReferralCode:
            _initialReferralCode, // 👈 pass code to register screen
      );
    }
    return LoginScreen(
      onAuthenticated: _onAuthenticated,
      onGoToRegister: () => setState(() => _showRegister = true),
    );
  }
}
