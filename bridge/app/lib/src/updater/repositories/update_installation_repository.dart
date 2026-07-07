import '../api/managed_runtime_manifest_api.dart';
import '../api/platform_update_api.dart';

/// Layer 2 aggregator for the installed managed runtime: the platform-specific
/// in-place applier plus the version manifest the npm bootstrap reads. Exposes
/// the swap/sweep/record operations the apply/reconcile services depend on.
class UpdateInstallationRepository {
  UpdateInstallationRepository({
    required PlatformUpdateApi platformUpdateApi,
    required ManagedRuntimeManifestApi manifestApi,
  }) : _platformUpdateApi = platformUpdateApi,
       _manifestApi = manifestApi;

  final PlatformUpdateApi _platformUpdateApi;
  final ManagedRuntimeManifestApi _manifestApi;

  /// Whether the platform applier supports a second in-place apply in the same
  /// session before a restart activates the first (see [PlatformUpdateApi]).
  bool get supportsInSessionChaining => _platformUpdateApi.supportsInSessionChaining;

  Future<void> applyInPlace({required String installRoot, required String stagingPath}) {
    return _platformUpdateApi.applyInPlace(installRoot: installRoot, stagingPath: stagingPath);
  }

  Future<void> sweepResidue({required String installRoot}) {
    return _platformUpdateApi.sweepResidue(installRoot: installRoot);
  }

  Future<void> recordManagedVersion({required String installRoot, required String version}) {
    return _manifestApi.writeVersion(installRoot: installRoot, version: version);
  }
}
