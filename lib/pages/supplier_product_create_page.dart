import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/supplier_api.dart';

class SupplierProductCreatePage extends StatefulWidget {
  const SupplierProductCreatePage({super.key});

  @override
  State<SupplierProductCreatePage> createState() =>
      _SupplierProductCreatePageState();
}

class _SupplierProductCreatePageState extends State<SupplierProductCreatePage> {
  final SupplierApi _api = SupplierApi();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _skuController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();

  String _currency = 'XAF';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _skuController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final sku = _skuController.text.trim();
    final price = _parseDouble(_priceController.text);
    final stock = int.tryParse(_stockController.text.trim());

    if (price == null || price.isNaN || price.isInfinite || price < 0) {
      _showSnack('Invalid price');
      return;
    }
    if (stock == null || stock < 1) {
      _showSnack('Invalid stock');
      return;
    }

    setState(() => _isSubmitting = true);
    late final String productId;
    try {
      productId = await _api.createProduct(
        name: name,
        description: description.isEmpty ? null : description,
      );
    } catch (err) {
      if (!mounted) return;
      _showSnack('Create product failed: ${_formatError(err)}');
      setState(() => _isSubmitting = false);
      return;
    }

    try {
      await _api.createVariant(
        productId: productId,
        sku: sku,
        price: price,
        stock: stock,
      );

      if (!mounted) return;
      _showSnack('Product created');
      Navigator.of(context).pop(
        CreatedSupplierProduct(
          id: productId,
          name: name,
          currency: _currency,
          sku: sku,
          price: price,
          stock: stock,
        ),
      );
    } catch (err) {
      if (!mounted) return;
      _showSnack('Variant failed for created product: ${_formatError(err)}');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _formatError(Object err) {
    if (err is ApiException) {
      final m = err.message?.trim();
      if (m != null && m.isNotEmpty) return m;
      final body = _compactError(err.body);
      if (body.isNotEmpty) return '$body (${err.statusCode})';
      return 'Request failed (${err.statusCode})';
    }
    return _compactError(err.toString());
  }

  void _showSnack(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Quick Add Product')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Product details',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      enabled: !_isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'Product name',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Product name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      enabled: !_isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 2,
                      maxLines: 5,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    FormField<String>(
                      initialValue: _currency,
                      builder: (state) => InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Currency',
                          border: OutlineInputBorder(),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: state.value,
                            items: const [
                              DropdownMenuItem(
                                value: 'XAF',
                                child: Text('XAF'),
                              ),
                              DropdownMenuItem(
                                value: 'KRW',
                                child: Text('KRW'),
                              ),
                              DropdownMenuItem(
                                value: 'USD',
                                child: Text('USD'),
                              ),
                            ],
                            onChanged: _isSubmitting
                                ? null
                                : (v) {
                                    if (v == null) return;
                                    state.didChange(v);
                                    setState(() => _currency = v);
                                  },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'First variant',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _skuController,
                      enabled: !_isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'SKU',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'SKU is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            enabled: !_isSubmitting,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                            decoration: const InputDecoration(
                              labelText: 'Price',
                              border: OutlineInputBorder(),
                            ),
                            textInputAction: TextInputAction.next,
                            validator: (v) {
                              final parsed = _parseDouble(v ?? '');
                              if (parsed == null ||
                                  parsed.isNaN ||
                                  parsed.isInfinite ||
                                  parsed < 0) {
                                return 'Enter a valid price';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _stockController,
                            enabled: !_isSubmitting,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Initial stock',
                              border: OutlineInputBorder(),
                            ),
                            textInputAction: TextInputAction.done,
                            validator: (v) {
                              final parsed = int.tryParse((v ?? '').trim());
                              if (parsed == null || parsed < 1) {
                                return 'Enter stock of at least 1';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Creating...'),
                                ],
                              )
                            : const Text('Create'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CreatedSupplierProduct {
  final String id;
  final String name;
  final String currency;
  final String sku;
  final double price;
  final int stock;

  const CreatedSupplierProduct({
    required this.id,
    required this.name,
    required this.currency,
    required this.sku,
    required this.price,
    required this.stock,
  });
}

double? _parseDouble(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  final normalized = trimmed.replaceAll(',', '.');
  return double.tryParse(normalized);
}

String _compactError(String message) {
  final trimmed = message.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (trimmed.length <= 180) return trimmed;
  return '${trimmed.substring(0, 180)}...';
}
