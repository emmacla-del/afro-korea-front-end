import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../services/api_service.dart';

class CatalogImportPage extends StatefulWidget {
  const CatalogImportPage({super.key});

  @override
  State<CatalogImportPage> createState() => _CatalogImportPageState();
}

class _CatalogImportPageState extends State<CatalogImportPage> {
  PlatformFile? _selectedFile;
  bool _isImporting = false;
  CatalogImportResult? _lastResult;

  Future<void> _selectFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'xlsx'],
        withData: true,
      );

      if (!mounted) return;
      if (result == null || result.files.isEmpty) return;

      final picked = result.files.single;
      final ext = (picked.extension ?? '').trim().toLowerCase();

      if (ext != 'csv' && ext != 'xlsx') {
        _showSnackBar('Only .csv and .xlsx files are supported.');
        return;
      }

      setState(() {
        _selectedFile = picked;
      });
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Failed to open file picker.');
    }
  }

  Future<void> _uploadAndImport() async {
    final file = _selectedFile;
    if (file == null) return;
    if (_isImporting) return;

    setState(() => _isImporting = true);
    try {
      final result = await _uploadCatalogImport(file);
      if (!mounted) return;

      setState(() {
        _lastResult = result;
        _selectedFile = null;
      });
      _showSnackBar('Import completed');
    } catch (err) {
      if (!mounted) return;
      _showSnackBar(_errorMessage(err));
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<CatalogImportResult> _uploadCatalogImport(PlatformFile file) async {
    final ext = (file.extension ?? '').trim().toLowerCase();
    if (ext != 'csv') {
      throw const FormatException(
        'Only CSV imports are supported by this backend endpoint.',
      );
    }

    final csvText = _readCsvText(file);
    final body = <String, Object?>{
      'products': _buildProductsPayloadFromCsv(csvText),
    };

    final json = await ApiService.instance.post(
      '/supplier/catalog/import',
      data: Map<String, dynamic>.from(body),
    );
    return CatalogImportResult.fromJson(json);
  }

  String _errorMessage(Object err) {
    if (err is ApiException) {
      if (err.message.trim().isNotEmpty) {
        return err.message.trim();
      }
      return err.statusCode == null
          ? 'Import failed'
          : 'Import failed (${err.statusCode})';
    }
    if (err is FormatException) {
      final msg = err.message.trim();
      return msg.isEmpty ? 'Invalid file.' : msg;
    }
    return 'Import failed. Please try again.';
  }

  void _showSnackBar(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = _selectedFile;

    return Scaffold(
      appBar: AppBar(title: const Text('Catalog Import')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Bulk import products from a CSV or Excel (.xlsx) file. '
            'The file is uploaded to the backend for validation and processing.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FilledButton.icon(
                    onPressed: _isImporting ? null : _selectFile,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Select file (CSV / Excel)'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    file == null
                        ? 'No file selected'
                        : 'Selected: ${file.name}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: file == null
                          ? theme.colorScheme.outline
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isImporting || file == null
                          ? null
                          : _uploadAndImport,
                      child: _isImporting
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
                                Text('Importing...'),
                              ],
                            )
                          : const Text('Upload & Import'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_lastResult != null) ...[
            const SizedBox(height: 12),
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last Import Summary',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SummaryRow(
                      label: 'Products created',
                      value: _lastResult!.createdProducts.toString(),
                    ),
                    const SizedBox(height: 8),
                    _SummaryRow(
                      label: 'Variants created',
                      value: _lastResult!.createdVariants.toString(),
                    ),
                    const SizedBox(height: 8),
                    _SummaryRow(
                      label: 'Errors',
                      value: _lastResult!.errors.toString(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class CatalogImportResult {
  final String importId;
  final int createdProducts;
  final int createdVariants;
  final int errors;

  const CatalogImportResult({
    required this.importId,
    required this.createdProducts,
    required this.createdVariants,
    required this.errors,
  });

  factory CatalogImportResult.fromJson(Map<String, dynamic> json) {
    final imported = json['imported'];
    final errors = json['errors'];

    int importedProducts = 0;
    int importedVariants = 0;
    if (imported is List) {
      importedProducts = imported.length;
      for (final item in imported.whereType<Map>()) {
        final mapped = Map<String, dynamic>.from(item);
        importedVariants += _asInt(mapped['createdVariants']) ?? 0;
      }
    }

    final errorCount = errors is List
        ? errors.length
        : (_asInt(json['errors']) ?? 0);

    return CatalogImportResult(
      importId: (json['importId'] ?? '').toString(),
      createdProducts: _asInt(json['createdProducts']) ?? importedProducts,
      createdVariants: _asInt(json['createdVariants']) ?? importedVariants,
      errors: errorCount,
    );
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String _readCsvText(PlatformFile file) {
  final bytes = file.bytes;
  if (bytes == null || bytes.isEmpty) {
    throw const FormatException('Selected file could not be read.');
  }
  return utf8.decode(bytes, allowMalformed: true);
}

List<Map<String, Object?>> _buildProductsPayloadFromCsv(String csvText) {
  final lines = csvText
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  if (lines.length < 2) {
    throw const FormatException(
      'CSV must include a header row and at least one data row.',
    );
  }

  final headers = _splitCsvLine(
    lines.first,
  ).map((h) => h.trim().toLowerCase()).toList();
  final idxName = headers.indexOf('product_name');
  final idxDescription = headers.indexOf('description');
  final idxCategory = headers.indexOf('category');
  final idxSku = headers.indexOf('sku');
  final idxUnitPrice = headers.indexOf('unitpricexaf');
  final idxThreshold = headers.indexOf('thresholdqty');
  final idxLeadTime = headers.indexOf('leadtimedays');

  if (idxName < 0 || idxSku < 0 || idxUnitPrice < 0 || idxThreshold < 0) {
    throw const FormatException(
      'CSV headers must include: product_name, sku, unitPriceXaf, thresholdQty',
    );
  }

  final grouped = <String, Map<String, Object?>>{};
  for (final line in lines.skip(1)) {
    final cols = _splitCsvLine(line);
    final productName = _col(cols, idxName).trim();
    final sku = _col(cols, idxSku).trim();
    final unitPrice = int.tryParse(_col(cols, idxUnitPrice).trim());
    final threshold = int.tryParse(_col(cols, idxThreshold).trim());

    if (productName.isEmpty ||
        sku.isEmpty ||
        unitPrice == null ||
        threshold == null) {
      continue;
    }

    final key = productName.toLowerCase();
    final product = grouped.putIfAbsent(key, () {
      return <String, Object?>{
        'product_name': productName,
        if (idxDescription >= 0 && _col(cols, idxDescription).trim().isNotEmpty)
          'description': _col(cols, idxDescription).trim(),
        if (idxCategory >= 0 && _col(cols, idxCategory).trim().isNotEmpty)
          'category': _col(cols, idxCategory).trim(),
        'variants': <Map<String, Object?>>[],
      };
    });

    final variants = product['variants'] as List<Map<String, Object?>>;
    variants.add({
      'sku': sku,
      'unitPriceXaf': unitPrice,
      'thresholdQty': threshold,
      if (idxLeadTime >= 0)
        if (int.tryParse(_col(cols, idxLeadTime).trim()) != null)
          'leadTimeDays': int.parse(_col(cols, idxLeadTime).trim()),
    });
  }

  final products = grouped.values.toList();
  if (products.isEmpty) {
    throw const FormatException('No valid rows found in CSV for import.');
  }

  return products;
}

List<String> _splitCsvLine(String line) {
  final result = <String>[];
  final current = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        current.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }

    if (ch == ',' && !inQuotes) {
      result.add(current.toString());
      current.clear();
      continue;
    }

    current.write(ch);
  }
  result.add(current.toString());
  return result;
}

String _col(List<String> cols, int index) {
  if (index < 0 || index >= cols.length) return '';
  return cols[index];
}
