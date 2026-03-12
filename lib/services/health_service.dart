import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Service to verify backend API connectivity by testing the /health endpoint.
class HealthService {
  static const String _baseUrl = 'https://afro-korea-pool-server.onrender.com';

  /// Tests connectivity to the backend by hitting the /health endpoint.
  ///
  /// Returns true if the backend is reachable and responds with status 200.
  /// Prints debug info about the connection attempt.
  Future<bool> checkBackendHealth() async {
    try {
      debugPrint('Health Check: Testing backend at $_baseUrl...');
      final response = await ApiService.instance.checkHealth();
      final isHealthy = response != null;

      if (isHealthy) {
        debugPrint('Health Check: Backend is healthy!');
        debugPrint('   Response: $response');
      } else {
        debugPrint('Health Check: Backend returned no health payload');
      }
      return isHealthy;
    } catch (e) {
      debugPrint('Health Check: Failed to connect to backend');
      debugPrint('   Error: $e');
      debugPrint('   Base URL: $_baseUrl');
      debugPrint(
        '   Hint: Ensure backend is running and reachable at that address.',
      );
      return false;
    }
  }

  /// Convenience getter for the current environment base URL.
  String get currentBaseUrl => _baseUrl;

  /// Prints the configured environment URL based on platform.
  void printEnvironmentInfo() {
    debugPrint('Environment Configuration:');
    debugPrint('   Base URL: $_baseUrl');
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
