import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show BridgePluginApi;
import "package:sesori_shared/sesori_shared.dart" show HealthResponse, PluginHealth;

/// Layer 2 aggregator producing the bridge health snapshot returned to phones.
///
/// Combines the plugin's liveness check with bridge-level metadata captured at
/// startup (version and whether filesystem access was found to be degraded, so
/// the phone can proactively warn the user about missing macOS Full Disk
/// Access).
class HealthRepository {
  final List<String> _enabledPluginIds;
  final Map<String, BridgePluginApi> _operationalPlugins;
  final String _bridgeVersion;
  final bool _filesystemAccessOk;
  final Duration _aggregateSourceDeadline;

  HealthRepository({
    required List<String> enabledPluginIds,
    required Map<String, BridgePluginApi> operationalPlugins,
    required String bridgeVersion,
    required bool filesystemAccessOk,
    required Duration aggregateSourceDeadline,
  }) : _enabledPluginIds = enabledPluginIds,
       _operationalPlugins = operationalPlugins,
       _bridgeVersion = bridgeVersion,
       _filesystemAccessOk = filesystemAccessOk,
       _aggregateSourceDeadline = aggregateSourceDeadline;

  /// Returns the bridge health snapshot.
  ///
  Future<HealthResponse> getHealth() async {
    final plugins = await Future.wait(
      _enabledPluginIds.map((pluginId) async {
        final plugin = _operationalPlugins[pluginId];
        if (plugin == null) return PluginHealth(pluginId: pluginId, healthy: false);
        try {
          return PluginHealth(
            pluginId: pluginId,
            healthy: await plugin.healthCheck().timeout(_aggregateSourceDeadline),
          );
        } on Object {
          return PluginHealth(pluginId: pluginId, healthy: false);
        }
      }),
    );
    return HealthResponse(
      healthy: true,
      version: _bridgeVersion,
      plugins: plugins,
      filesystemAccessDegraded: !_filesystemAccessOk,
    );
  }
}
