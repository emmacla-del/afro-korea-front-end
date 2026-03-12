import '../models/pool_summary.dart';
import 'api_service.dart';

/// Pool operations (minimal, MVP).
///
/// Backend endpoints:
/// - `POST /pools/:id/commit` (requires `x-user-id`)
class PoolService {
  PoolService();

  Future<PoolSummary> commitToPool({
    required String poolId,
    required int qty,
  }) async {
    final json = await ApiService.instance.commitToPool(
      poolId,
      body: {'qty': qty},
    );
    return PoolSummary.fromApiJson(json);
  }
}
