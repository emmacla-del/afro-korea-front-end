import 'package:flutter/foundation.dart';
import 'api_client.dart';

/// Service to verify backend API connectivity by testing the /health endpoint.
class HealthService {
  final ApiClient apiClient;

  HealthService({ApiClient? apiClient})
      : apiClient = apiClient ?? ApiClient();

  /// Tests connectivity to the backend by hitting the /health endpoint.
  ///
  /// Returns true if the backend is reachable and responds with status 200.
  /// Prints debug info about the connection attempt.
  Future<bool> checkBackendHealth() async {
    try {
      debugPrint('🏥 Health Check: Testing backend at ${apiClient.baseUri}...');

      final response = await apiClient.get<Map<String, dynamic>?>(
        '/health',
        decode: (json) =>
            json is Map<String, dynamic> ? json : null,
      );

      debugPrint('✅ Health Check: Backend is healthy!');
      debugPrint('   Response: $response');
      return true;
    } catch (e) {
      debugPrint('❌ Health Check: Failed to connect to backend');
      debugPrint('   Error: $e');
      debugPrint('   Base URL: ${apiClient.baseUri}');
      debugPrint(
        '   Hint: Ensure backend is running and reachable at that address.',
      );
      return false;
    }
  }

  /// Convenience getter for the current environment base URL.
  String get currentBaseUrl => apiClient.baseUri.toString();

  /// Prints the configured environment URL based on platform.
  void printEnvironmentInfo() {
    debugPrint('📡 Environment Configuration:');
    debugPrint('   Base URL: ${apiClient.baseUri}');
    debugPrint('   Platform: ${platformDescription()}');
  }

  /// Returns a human-readable description of the current platform.
  static String platformDescription() {
    try {
      // ignore: avoid_web_libraries_in_release
      // This will fail on web, but we're checking the real device/emulator
      if (identical(0, 0.0)) {
        return 'Web (not supported)';
      }
    } catch (e) {
      // Ignore
    }
    return 'Mobile device/emulator';
  }
}
