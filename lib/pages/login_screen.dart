import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/user_store.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;
  final VoidCallback onGoToRegister;

  const LoginScreen({
    super.key,
    required this.onAuthenticated,
    required this.onGoToRegister,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    try {
      final response = await ApiService.instance.login(
        _phoneController.text.trim(),
        _passwordController.text,
      );

      final token = (response['access_token'] ?? '').toString().trim();
      final user = response['user'];
      if (token.isEmpty || user is! Map) {
        throw ApiException(message: 'Invalid login response from server');
      }

      final userId = (user['id'] ?? '').toString().trim();
      final role = (user['role'] ?? '').toString().trim().toUpperCase();
      if (userId.isEmpty || role.isEmpty) {
        throw ApiException(
          message: 'Missing user information in login response',
        );
      }

      await UserStore.saveToken(token);
      await UserStore.saveUserId(userId);
      await UserStore.saveUserRole(role);
      ApiService.instance.setBearerToken(token);

      if (!mounted) return;
      widget.onAuthenticated();
    } catch (err) {
      if (!mounted) return;
      final message = err is ApiException ? err.message : 'Login failed';
      _showError(message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                enabled: !_isSubmitting,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Phone is required';
                  }
                  return null;
                },
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
                validator: (value) {
                  final trimmed = (value ?? '').trim();
                  if (trimmed.isEmpty) return 'Password is required';
                  if (trimmed.length < 6) return 'Minimum 6 characters';
                  return null;
                },
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
                    : const Text('Login'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isSubmitting ? null : widget.onGoToRegister,
                child: const Text('Create an account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
