import "package:sesori_shared/sesori_shared.dart" show HealthResponse;

/// Layer 2 repository producing the bridge health snapshot returned to clients.
///
/// Reports only bridge-level metadata captured at startup. Plugin lifecycle and
/// diagnostics are exposed through plugin-scoped APIs, not `/global/health`.
class HealthRepository {
  final String _bridgeVersion;
  final bool _filesystemAccessOk;

  HealthRepository({
    required String bridgeVersion,
    required bool filesystemAccessOk,
  }) : _bridgeVersion = bridgeVersion,
       _filesystemAccessOk = filesystemAccessOk;

  /// Returns the bridge health snapshot.
  HealthResponse getHealth() {
    return HealthResponse(
      healthy: true,
      version: _bridgeVersion,
      filesystemAccessDegraded: !_filesystemAccessOk,
    );
  }
}
