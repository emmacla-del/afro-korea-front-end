import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import '../api/api_client.dart';

class CatalogImportPage extends StatefulWidget {
  const CatalogImportPage({super.key});

  @override
  State<CatalogImportPage> createState() => _CatalogImportPageState();
}

class _CatalogImportPageState extends State<CatalogImportPage> {
  final ApiClient _apiClient = ApiClient();

  PlatformFile? _selectedFile;
  bool _isImporting = false;
  CatalogImportResult? _lastResult;

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  Future<void> _selectFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'xlsx'],
        withData: kIsWeb,
      );

      if (!mounted) return;
      if (result == null || result.files.isEmpty) return;

      final picked = result.files.single;
      final ext = (picked.extension ?? '')
          .trim()
          .toLowerCase();

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
    final uri = Uri.parse('${ApiClient.baseUrl}/supplier/catalog-imports');
    final request = http.MultipartRequest('POST', uri);

    final token = await _apiClient.tokenProvider();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers['accept'] = 'application/json';

    if (file.bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          file.bytes!,
          filename: file.name,
        ),
      );
    } else if (file.path != null && file.path!.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path!,
          filename: file.name,
        ),
      );
    } else {
      throw const FormatException('Selected file is not accessible.');
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        reasonPhrase: response.reasonPhrase,
        body: response.body,
        message: _extractBackendError(response.body),
      );
    }

    if (response.body.isEmpty) {
      throw ApiException(
        statusCode: response.statusCode,
        reasonPhrase: response.reasonPhrase,
        body: response.body,
        message: 'Empty response from server',
      );
    }

    final json = jsonDecode(response.body);
    if (json is! Map) {
      throw ApiException(
        statusCode: response.statusCode,
        reasonPhrase: response.reasonPhrase,
        body: response.body,
        message: 'Unexpected response shape',
      );
    }

    return CatalogImportResult.fromJson(Map<String, dynamic>.from(json));
  }

  String? _extractBackendError(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map) {
        final message = json['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
        final error = json['error'];
        if (error is String && error.trim().isNotEmpty) {
          return error.trim();
        }
      }
    } catch (_) {}
    final trimmed = body.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _errorMessage(Object err) {
    if (err is ApiException) {
      if (err.message != null && err.message!.trim().isNotEmpty) {
        return err.message!.trim();
      }
      return 'Import failed (${err.statusCode})';
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
                    file == null ? 'No file selected' : 'Selected: ${file.name}',
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
                      onPressed:
                          _isImporting || file == null ? null : _uploadAndImport,
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
    return CatalogImportResult(
      importId: (json['importId'] ?? '').toString(),
      createdProducts: _asInt(json['createdProducts']) ?? 0,
      createdVariants: _asInt(json['createdVariants']) ?? 0,
      errors: _asInt(json['errors']) ?? 0,
    );
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
