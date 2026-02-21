import '../models/pool_summary.dart';
import 'api_client.dart';

/// Pool operations (minimal, MVP).
///
/// Backend endpoints:
/// - `POST /pools/:id/commit` (requires `x-user-id`)
class PoolService {
  final ApiClient _api;

  PoolService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  Future<PoolSummary> commitToPool({
    required String poolId,
    required int qty,
  }) async {
    final json = await _api.post<Object?>(
      '/pools/$poolId/commit',
      body: {'qty': qty},
      timeout: const Duration(seconds: 10),
    );

    if (json is! Map) {
      throw ApiException(
        statusCode: 200,
        reasonPhrase: 'OK',
        body: json?.toString() ?? 'null',
        message: 'Unexpected response from commit endpoint',
      );
    }

    return PoolSummary.fromApiJson(Map<String, dynamic>.from(json));
  }
}

