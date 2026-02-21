import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/health_service.dart';

/// Example widget demonstrating API integration with the backend.
///
/// This shows:
/// - How to initialize the ApiClient
/// - How to make GET/POST requests
/// - How to verify backend health
/// - How to handle errors
class ApiExampleWidget extends StatefulWidget {
  const ApiExampleWidget({Key? key}) : super(key: key);

  @override
  State<ApiExampleWidget> createState() => _ApiExampleWidgetState();
}

class _ApiExampleWidgetState extends State<ApiExampleWidget> {
  late final ApiClient _apiClient;
  late final HealthService _healthService;

  String _status = '⏳ Initializing...';
  String _baseUrl = '';
  bool _isHealthy = false;

  @override
  void initState() {
    super.initState();
    _initializeApi();
  }

  /// Initialize the API client with environment-aware base URL.
  void _initializeApi() {
    _apiClient = ApiClient();
    _healthService = HealthService(apiClient: _apiClient);

    setState(() {
      _baseUrl = _apiClient.baseUri.toString();
      _status = 'ℹ️ Base URL: $_baseUrl';
    });

    _healthService.printEnvironmentInfo();
  }

  /// Test backend connectivity by calling /health endpoint.
  Future<void> _testBackendConnection() async {
    setState(() {
      _status = '⏳ Connecting to backend...';
    });

    final isHealthy = await _healthService.checkBackendHealth();

    setState(() {
      _isHealthy = isHealthy;
      _status = isHealthy
          ? '✅ Backend is reachable!'
          : '❌ Cannot reach backend';
    });
  }

  /// Example: Fetch supplier data (replace with actual endpoint).
  Future<void> _exampleGetSuppliers() async {
    setState(() {
      _status = '⏳ Fetching suppliers...';
    });

    try {
      // Example: GET /suppliers or similar endpoint
      // Adjust the path to match your actual backend endpoint
      final response = await _apiClient.get<List<dynamic>?>(
        '/suppliers',
        decode: (json) => json is List ? json : null,
      );

      setState(() {
        _status = '✅ Suppliers fetched: ${response?.length ?? 0} items';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
      });
    }
  }

  /// Example: Create a user (replace with actual endpoint).
  Future<void> _examplePostUser() async {
    setState(() {
      _status = '⏳ Creating user...';
    });

    try {
      // Example: POST /dev/users (development endpoint)
      final response = await _apiClient.post<Map<String, dynamic>?>(
        '/dev/users',
        body: {
          'phone': '+237123456789',
          'role': 'CUSTOMER',
        },
        decode: (json) =>
            json is Map<String, dynamic> ? json : null,
      );

      setState(() {
        _status = '✅ User created: ${response?['id'] ?? 'unknown'}';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
      });
    }
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Example'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status display
            Card(
              color: _isHealthy ? Colors.green[50] : Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Connection Status',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _isHealthy ? Colors.green[700] : Colors.red[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Base URL info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Backend Base URL',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _baseUrl,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action buttons
            const Text(
              'Test Actions',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _testBackendConnection,
              icon: const Icon(Icons.health_and_safety),
              label: const Text('Check Backend Health (/health)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _exampleGetSuppliers,
              icon: const Icon(Icons.shop),
              label: const Text('Fetch Suppliers (GET /suppliers)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _examplePostUser,
              icon: const Icon(Icons.person_add),
              label: const Text('Create User (POST /dev/users)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 24),

            // Documentation
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Integration Guide',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. Import ApiClient:\n'
                      '   import \'../services/api_client.dart\';\n\n'
                      '2. Create instance:\n'
                      '   final client = ApiClient();\n\n'
                      '3. Make requests:\n'
                      '   final data = await client.get(\'/endpoint\');\n\n'
                      '4. API base URL used by the app:\n'
                      '   https://afro-korea-pool-server.onrender.com (production)',
                      style: TextStyle(fontSize: 12, color: Colors.blue[900]),
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
