import 'package:flutter/material.dart';
import '../api/supplier_api.dart';
import '../models/supplier_product.dart';

class SupplierProductEditPage extends StatefulWidget {
  final SupplierProduct product;

  const SupplierProductEditPage({super.key, required this.product});

  @override
  State<SupplierProductEditPage> createState() => _SupplierProductEditPageState();
}

class _SupplierProductEditPageState extends State<SupplierProductEditPage> {
  final SupplierApi _api = SupplierApi();

  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;

  late bool _isActive;
  late String _poolStatus;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _priceController = TextEditingController(text: _formatPrice(widget.product.price));
    _stockController = TextEditingController(text: widget.product.stock.toString());
    _isActive = widget.product.isActive;
    _poolStatus = widget.product.poolStatus.trim().toUpperCase();
    if (_poolStatus != 'OPEN' && _poolStatus != 'CLOSED') {
      _poolStatus = 'CLOSED';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final original = widget.product;

    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim());
    final stock = int.tryParse(_stockController.text.trim());

    if (name.isEmpty) {
      _showSnack('Name is required');
      return;
    }
    if (price == null || price.isNaN || price.isInfinite || price < 0) {
      _showSnack('Invalid price');
      return;
    }
    if (stock == null || stock < 0) {
      _showSnack('Invalid stock');
      return;
    }

    final normalizedPoolStatus = _poolStatus.trim().toUpperCase();
    final nextPoolStatus =
        normalizedPoolStatus == 'OPEN' ? 'OPEN' : 'CLOSED';

    final nameChanged = name != original.name;
    final priceChanged = price != original.price;
    final stockChanged = stock != original.stock;
    final isActiveChanged = _isActive != original.isActive;
    final poolStatusChanged =
        nextPoolStatus != original.poolStatus.trim().toUpperCase();

    if (!nameChanged &&
        !priceChanged &&
        !stockChanged &&
        !isActiveChanged &&
        !poolStatusChanged) {
      Navigator.of(context).pop(original);
      return;
    }

    setState(() => _isSaving = true);

    try {
      SupplierProduct? serverProduct;
      if (nameChanged || priceChanged || stockChanged || isActiveChanged) {
        serverProduct = await _api.patchProduct(
          id: original.id,
          name: nameChanged ? name : null,
          price: priceChanged ? price : null,
          stock: stockChanged ? stock : null,
          isActive: isActiveChanged ? _isActive : null,
        );
      }

      SupplierProduct? serverStatusProduct;
      if (poolStatusChanged) {
        serverStatusProduct = await _api.patchProductPoolStatus(
          id: original.id,
          poolStatus: nextPoolStatus,
        );
      }

      final updated = _mergeUpdatedProduct(
        original: original,
        name: name,
        price: price,
        stock: stock,
        isActive: _isActive,
        poolStatus: nextPoolStatus,
        serverProduct: serverProduct,
        serverStatusProduct: serverStatusProduct,
      );

      if (!mounted) return;
      _showSnack('Saved');
      Navigator.of(context).pop(updated);
    } catch (err) {
      if (!mounted) return;
      _showSnack(_compactError(err.toString()));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = widget.product;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Product'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SKU: ${product.sku}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Currency: ${product.currency}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
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
                  TextField(
                    controller: _nameController,
                    enabled: !_isSaving,
                    decoration: const InputDecoration(
                      labelText: 'Product name',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _priceController,
                          enabled: !_isSaving,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Price',
                            border: OutlineInputBorder(),
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _stockController,
                          enabled: !_isSaving,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Stock',
                            border: OutlineInputBorder(),
                          ),
                          textInputAction: TextInputAction.done,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _isActive,
                    onChanged: _isSaving ? null : (v) => setState(() => _isActive = v),
                    title: const Text('Active'),
                    subtitle: Text(_isActive ? 'Visible to customers' : 'Hidden'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Pool status',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value: 'OPEN',
                        label: Text('OPEN'),
                      ),
                      ButtonSegment<String>(
                        value: 'CLOSED',
                        label: Text('CLOSED'),
                      ),
                    ],
                    selected: {_poolStatus},
                    onSelectionChanged: _isSaving
                        ? null
                        : (selection) {
                            final v = selection.isEmpty ? 'CLOSED' : selection.first;
                            setState(() => _poolStatus = v);
                          },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

SupplierProduct _mergeUpdatedProduct({
  required SupplierProduct original,
  required String name,
  required double price,
  required int stock,
  required bool isActive,
  required String poolStatus,
  required SupplierProduct? serverProduct,
  required SupplierProduct? serverStatusProduct,
}) {
  final base = serverProduct ?? original;
  final statusBase = serverStatusProduct ?? base;

  return SupplierProduct(
    id: statusBase.id,
    name: name,
    sku: statusBase.sku,
    price: price,
    currency: statusBase.currency,
    stock: stock,
    poolStatus: poolStatus,
    isActive: isActive,
    createdAt: statusBase.createdAt,
  );
}

String _formatPrice(double value) {
  final isInt = value == value.roundToDouble();
  return isInt ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
}

String _compactError(String message) {
  final trimmed = message.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (trimmed.length <= 180) return trimmed;
  return '${trimmed.substring(0, 180)}...';
}

