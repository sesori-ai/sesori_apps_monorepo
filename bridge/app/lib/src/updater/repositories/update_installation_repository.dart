import '../api/platform_update_api.dart';

/// Layer 2 wrapper over the platform-specific in-place applier. Aggregates the
/// single [PlatformUpdateApi] data source and exposes the swap/sweep operations
/// the apply/reconcile services depend on.
class UpdateInstallationRepository {
  UpdateInstallationRepository({required PlatformUpdateApi platformUpdateApi})
    : _platformUpdateApi = platformUpdateApi;

  final PlatformUpdateApi _platformUpdateApi;

  Future<void> applyInPlace({required String installRoot, required String stagingPath}) {
    return _platformUpdateApi.applyInPlace(installRoot: installRoot, stagingPath: stagingPath);
  }

  Future<void> sweepResidue({required String installRoot}) {
    return _platformUpdateApi.sweepResidue(installRoot: installRoot);
  }
}
