import 'package:flutter/material.dart';
import '../api/supplier_api.dart';
import '../models/supplier_product.dart';
import '../services/api_service.dart';

class SupplierProductEditPage extends StatefulWidget {
  final SupplierProduct product;

  const SupplierProductEditPage({super.key, required this.product});

  @override
  State<SupplierProductEditPage> createState() =>
      _SupplierProductEditPageState();
}

class _SupplierProductEditPageState extends State<SupplierProductEditPage> {
  final SupplierApi _api = SupplierApi();

  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;

  late bool _isActive;
  late String _poolStatus;

  bool _isSaving = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _priceController = TextEditingController(
      text: _formatPrice(widget.product.price),
    );
    _stockController = TextEditingController(
      text: widget.product.stock.toString(),
    );
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

  // -------------------------------------------------------------------------
  // Delete product
  // -------------------------------------------------------------------------
  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text(
          'Are you sure you want to delete "${widget.product.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    try {
      await _api.deleteProduct(widget.product.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Product deleted')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error deleting: $e')));
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  // -------------------------------------------------------------------------
  // Save product
  // -------------------------------------------------------------------------
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
    final nextPoolStatus = normalizedPoolStatus == 'OPEN' ? 'OPEN' : 'CLOSED';

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // -------------------------------------------------------------------------
  // Create Team Deal Dialog (unchanged)
  // -------------------------------------------------------------------------
  void _showCreateTeamDealDialog() {
    final teamPriceController = TextEditingController();
    final minBuyersController = TextEditingController(text: '2');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Team Deal'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: teamPriceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Team Price (FCFA)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a team price';
                  }
                  if (int.tryParse(value) == null || int.parse(value) <= 0) {
                    return 'Enter a valid positive number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: minBuyersController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Minimum Buyers',
                  border: OutlineInputBorder(),
                  hintText: '2',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter minimum buyers';
                  }
                  final intValue = int.tryParse(value);
                  if (intValue == null || intValue < 2) {
                    return 'Minimum must be at least 2';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              if (widget.product.variantId == null) {
                Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        '❌ This product has no variant. Cannot create team deal.',
                      ),
                    ),
                  );
                }
                return;
              }

              Navigator.pop(dialogContext);

              BuildContext? loadingContext;
              if (mounted) {
                await showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) {
                    loadingContext = ctx;
                    return const Center(child: CircularProgressIndicator());
                  },
                );
              }

              try {
                await ApiService.instance.createTeamDeal(
                  variantId: widget.product.variantId!,
                  teamPrice: int.parse(teamPriceController.text),
                  minBuyers: int.parse(minBuyersController.text),
                );

                if (!mounted) return;
                if (loadingContext != null &&
                    Navigator.canPop(loadingContext!)) {
                  Navigator.pop(loadingContext!);
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Team deal created!')),
                );
              } catch (e) {
                if (!mounted) return;
                if (loadingContext != null &&
                    Navigator.canPop(loadingContext!)) {
                  Navigator.pop(loadingContext!);
                }
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
              }
            },
            child: const Text('Launch Deal'),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = widget.product;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Product'),
        actions: [
          // Delete button
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _isSaving || _isDeleting ? null : _confirmDelete,
          ),
          // Save button
          TextButton(
            onPressed: (_isSaving || _isDeleting) ? null : _save,
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
      body: _isDeleting
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Image gallery
                if (product.images?.isNotEmpty == true) ...[
                  _buildImageGallery(product.images!),
                  const SizedBox(height: 12),
                ],
                // SKU & currency card
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
                // Edit fields card
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
                                keyboardType:
                                    const TextInputType.numberWithOptions(
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
                          onChanged: _isSaving
                              ? null
                              : (v) => setState(() => _isActive = v),
                          title: const Text('Active'),
                          subtitle: Text(
                            _isActive ? 'Visible to customers' : 'Hidden',
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 12),
                        Text('Pool status', style: theme.textTheme.titleSmall),
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
                                  final v = selection.isEmpty
                                      ? 'CLOSED'
                                      : selection.first;
                                  setState(() => _poolStatus = v);
                                },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Team Deal card
                Card(
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Team Deal', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          'Create a time-limited group deal where customers get a discount when enough people join.',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _isSaving
                              ? null
                              : _showCreateTeamDealDialog,
                          icon: const Icon(Icons.groups),
                          label: const Text('Create Team Deal'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // -------------------------------------------------------------------------
  // Image gallery builder
  // -------------------------------------------------------------------------
  Widget _buildImageGallery(List<String> images) {
    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Product Images',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemBuilder: (ctx, i) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      images[i], // already absolute Cloudinary URL
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 120,
                        height: 120,
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------------
// Helpers
// -------------------------------------------------------------------------
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
    variantId: statusBase.variantId,
    name: name,
    sku: statusBase.sku,
    price: price,
    currency: statusBase.currency,
    stock: stock,
    poolStatus: poolStatus,
    isActive: isActive,
    createdAt: statusBase.createdAt,
    images: original.images, // preserve images
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
