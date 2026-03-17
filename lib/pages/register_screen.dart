import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/user_store.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;
  final VoidCallback onGoToLogin;
  final String? initialReferralCode; // 👈 NEW

  const RegisterScreen({
    super.key,
    required this.onAuthenticated,
    required this.onGoToLogin,
    this.initialReferralCode,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController(); // for supplier
  final _cityController = TextEditingController();
  final _businessRegController = TextEditingController();
  // 👇 NEW controllers
  final _nameController = TextEditingController(); // for all users (optional)
  final _referralController = TextEditingController();

  String _role = 'CUSTOMER';
  String _country = 'Nigeria';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialReferralCode != null) {
      _referralController.text = widget.initialReferralCode!;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    _cityController.dispose();
    _businessRegController.dispose();
    _nameController.dispose(); // 👈
    _referralController.dispose(); // 👈
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSubmitting = true);
    try {
      Map<String, dynamic>? supplierData;
      if (_role == 'SUPPLIER') {
        supplierData = {
          'displayName': _displayNameController.text.trim(),
          'country': _country,
          if (_cityController.text.trim().isNotEmpty)
            'city': _cityController.text.trim(),
          if (_businessRegController.text.trim().isNotEmpty)
            'businessRegNumber': _businessRegController.text.trim(),
        };
      }
      final response = await ApiService.instance.register(
        _phoneController.text.trim(),
        _passwordController.text,
        role: _role,
        supplierData: supplierData,
        name: _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : null,
        referralCode: _referralController.text.trim().isNotEmpty
            ? _referralController.text.trim()
            : null,
      );
      final token = (response['access_token'] ?? '').toString().trim();
      final user = response['user'];
      if (token.isEmpty || user is! Map) {
        throw Exception('Invalid registration response from server');
      }
      final userId = (user['id'] ?? '').toString().trim();
      final role = (user['role'] ?? '').toString().trim().toUpperCase();
      if (userId.isEmpty || role.isEmpty) {
        throw Exception('Missing user information in registration response');
      }
      await UserStore.saveToken(token);
      await UserStore.saveUserId(userId);
      await UserStore.saveUserRole(role);
      ApiService.instance.setBearerToken(token);
      if (!mounted) return;
      widget.onAuthenticated();
    } catch (err) {
      if (!mounted) return;
      _showError(err is Exception ? err.toString() : 'Registration failed');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 👇 NEW: Full name (optional)
              TextFormField(
                controller: _nameController,
                enabled: !_isSubmitting,
                decoration: const InputDecoration(
                  labelText: 'Full Name (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _phoneController,
                enabled: !_isSubmitting,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Phone is required'
                    : null,
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _role,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'CUSTOMER', child: Text('Customer')),
                  DropdownMenuItem(value: 'SUPPLIER', child: Text('Supplier')),
                ],
                onChanged: _isSubmitting
                    ? null
                    : (v) {
                        if (v != null) setState(() => _role = v);
                      },
              ),
              const SizedBox(height: 12),

              if (_role == 'SUPPLIER') ...[
                TextFormField(
                  controller: _displayNameController,
                  enabled: !_isSubmitting,
                  decoration: const InputDecoration(
                    labelText: 'Business Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Business name is required'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _country,
                  decoration: const InputDecoration(
                    labelText: 'Country',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Nigeria',
                      child: Text('Nigeria 🇳🇬'),
                    ),
                    DropdownMenuItem(
                      value: 'Cameroon',
                      child: Text('Cameroon 🇨🇲'),
                    ),
                  ],
                  onChanged: _isSubmitting
                      ? null
                      : (v) {
                          if (v != null) setState(() => _country = v);
                        },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cityController,
                  enabled: !_isSubmitting,
                  decoration: const InputDecoration(
                    labelText: 'City (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _businessRegController,
                  enabled: !_isSubmitting,
                  decoration: const InputDecoration(
                    labelText: 'Business Registration Number (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // 👇 NEW: Referral code (optional)
              TextFormField(
                controller: _referralController,
                enabled: !_isSubmitting,
                decoration: const InputDecoration(
                  labelText: 'Referral Code (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _passwordController,
                enabled: !_isSubmitting,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'Password is required';
                  if (t.length < 6) return 'Minimum 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _confirmPasswordController,
                enabled: !_isSubmitting,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v != _passwordController.text
                    ? 'Passwords do not match'
                    : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),

              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Register'),
              ),
              const SizedBox(height: 8),

              TextButton(
                onPressed: _isSubmitting ? null : widget.onGoToLogin,
                child: const Text('Already have an account? Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
