import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../models/neighbourhood.dart';

class SupplierProductCreatePage extends StatefulWidget {
  const SupplierProductCreatePage({super.key});

  @override
  State<SupplierProductCreatePage> createState() =>
      _SupplierProductCreatePageState();
}

class _SupplierProductCreatePageState extends State<SupplierProductCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _currencyController = TextEditingController(text: 'XAF');

  List<Neighbourhood> _neighbourhoods = [];
  String? _selectedNeighbourhoodId;
  bool _neighbourhoodsLoading = true;
  String? _neighbourhoodsError;

  final List<XFile> _selectedImages = [];
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadNeighbourhoods();
  }

  Future<void> _loadNeighbourhoods() async {
    setState(() {
      _neighbourhoodsLoading = true;
      _neighbourhoodsError = null;
    });
    try {
      final neighbourhoods = await ApiService.instance.fetchNeighbourhoods();
      if (!mounted) return;
      setState(() {
        _neighbourhoods = neighbourhoods;
        _neighbourhoodsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _neighbourhoodsError = e.toString();
        _neighbourhoodsLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one image')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim();
      final price = double.parse(_priceController.text.trim());
      final stock = int.parse(_stockController.text.trim());
      final currency = _currencyController.text.trim().toUpperCase();

      final fields = {
        'product_name': name,
        if (description != null) 'description': description,
        'price': price.toString(),
        'stock': stock.toString(),
        'currency': currency,
        if (_selectedNeighbourhoodId != null)
          'neighbourhoodId': _selectedNeighbourhoodId!,
      };

      await ApiService.instance.createSupplierProductWithImages(
        fields,
        _selectedImages,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Product created successfully!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildImagePreview(XFile image, int index) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: kIsWeb
                ? Image.network(
                    image.path,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image),
                    ),
                  )
                : Image.file(
                    File(image.path),
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedImages.removeAt(index);
              });
            },
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Product'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Product Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a product name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Price',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a price';
                            }
                            if (double.tryParse(value) == null ||
                                double.parse(value) <= 0) {
                              return 'Enter a valid positive number';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _stockController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Stock',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter stock quantity';
                            }
                            if (int.tryParse(value) == null ||
                                int.parse(value) <= 0) {
                              return 'Enter a valid positive integer';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _currencyController,
                    decoration: const InputDecoration(
                      labelText: 'Currency (e.g., XAF)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter currency';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Neighbourhood dropdown
                  if (_neighbourhoodsLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_neighbourhoodsError != null)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Error loading neighbourhoods: $_neighbourhoodsError',
                          ),
                        ),
                        TextButton(
                          onPressed: _loadNeighbourhoods,
                          child: const Text('Retry'),
                        ),
                      ],
                    )
                  else
                    DropdownButtonFormField<String?>(
                      initialValue: _selectedNeighbourhoodId,
                      decoration: const InputDecoration(
                        labelText: 'Restrict to neighbourhood (optional)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Global (anywhere)'),
                        ),
                        ..._neighbourhoods.map(
                          (n) => DropdownMenuItem<String?>(
                            value: n.id,
                            child: Text(n.name),
                          ),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedNeighbourhoodId = val),
                    ),
                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    onPressed: _pickImages,
                    icon: const Icon(Icons.image),
                    label: const Text('Add Images'),
                  ),
                  if (_selectedImages.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedImages.length,
                        itemBuilder: (ctx, i) =>
                            _buildImagePreview(_selectedImages[i], i),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_selectedImages.length} image(s) selected',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
