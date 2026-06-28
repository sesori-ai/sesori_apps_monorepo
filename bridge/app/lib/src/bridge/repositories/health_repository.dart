import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show BridgePluginApi;
import "package:sesori_shared/sesori_shared.dart" show HealthResponse;

/// Thrown by [HealthRepository.getHealth] when the backend reports unhealthy.
/// The handler maps this to a 503 response.
class BackendUnhealthyException implements Exception {
  @override
  String toString() => "BackendUnhealthyException: backend unhealthy";
}

/// Layer 2 aggregator producing the bridge health snapshot returned to phones.
///
/// Combines the plugin's liveness check with bridge-level metadata captured at
/// startup (version and whether filesystem access was found to be degraded, so
/// the phone can proactively warn the user about missing macOS Full Disk
/// Access).
class HealthRepository {
  final BridgePluginApi _plugin;
  final String _bridgeVersion;
  final bool _filesystemAccessOk;

  HealthRepository({
    required BridgePluginApi plugin,
    required String bridgeVersion,
    required bool filesystemAccessOk,
  }) : _plugin = plugin,
       _bridgeVersion = bridgeVersion,
       _filesystemAccessOk = filesystemAccessOk;

  /// Returns the bridge health snapshot.
  ///
  /// Throws [BackendUnhealthyException] when the backend is unhealthy.
  Future<HealthResponse> getHealth() async {
    final healthy = await _plugin.healthCheck();
    if (!healthy) {
      throw BackendUnhealthyException();
    }
    return HealthResponse(
      healthy: true,
      version: _bridgeVersion,
      filesystemAccessDegraded: !_filesystemAccessOk,
    );
  }
}
