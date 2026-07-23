import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../bridge/runtime/plugin_runtime.dart";

class PluginLifecycleSnapshot {
  const PluginLifecycleSnapshot({
    required this.pluginId,
    required this.projectOwnership,
    required this.setup,
    required this.eligible,
    required this.state,
  });

  final String pluginId;
  final PluginProjectOwnership projectOwnership;
  final PluginSetupStatus setup;
  final bool eligible;
  final PluginRuntimeState state;
}

class PluginLifecycleRepository {
  PluginLifecycleRepository({required PluginRuntime runtime}) : _runtime = runtime;

  final PluginRuntime _runtime;

  Map<String, BridgePluginApi> get operationalPlugins => _runtime.operationalApis;

  Future<Map<String, PluginSetupStatus>> inspect({
    required Set<String> pluginIds,
    required bool markUnselectedNotInspected,
  }) {
    return _runtime.inspectSetup(
      pluginIds: pluginIds,
      markUnselectedNotInspected: markUnselectedNotInspected,
    );
  }

  void applyAccess({
    required Set<String> eligiblePluginIds,
    required Set<String> startAllowedPluginIds,
  }) {
    _runtime.applyAccess(
      entries: [
        for (final snapshot in _runtime.snapshot)
          PluginRuntimeAccess(
            pluginId: snapshot.pluginId,
            eligible: eligiblePluginIds.contains(snapshot.pluginId),
            startAllowed: startAllowedPluginIds.contains(snapshot.pluginId),
          ),
      ],
    );
  }

  Future<PluginRuntimeCommandResult> start({required String pluginId}) => _runtime.start(pluginId: pluginId);

  Future<PluginRuntimeCommandResult> stop({
    required String pluginId,
    required PluginStopIntent intent,
  }) => _runtime.stop(pluginId: pluginId, intent: intent);

  Future<PluginRuntimeCommandResult> restart({
    required String pluginId,
    required PluginStopIntent intent,
  }) => _runtime.restart(pluginId: pluginId, intent: intent);

  Stream<List<PluginLifecycleSnapshot>> get snapshots => _runtime.snapshots.map(_mapSnapshots);
  List<PluginLifecycleSnapshot> get snapshot => _mapSnapshots(_runtime.snapshot);

  List<PluginLifecycleSnapshot> _mapSnapshots(List<PluginRuntimeSnapshot> snapshots) {
    return List<PluginLifecycleSnapshot>.unmodifiable([
      for (final snapshot in snapshots)
        PluginLifecycleSnapshot(
          pluginId: snapshot.pluginId,
          projectOwnership: snapshot.projectOwnership,
          setup: snapshot.setup,
          eligible: snapshot.eligible,
          state: snapshot.state,
        ),
    ]);
  }
}
