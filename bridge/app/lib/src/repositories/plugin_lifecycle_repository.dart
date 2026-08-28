import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../runtime/plugin_runtime.dart";

class PluginLifecycleRepository({required final PluginRuntime _runtime}) {
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
            gate: eligiblePluginIds.contains(snapshot.pluginId)
                ? PluginRuntimeAccessGate.enabled
                : PluginRuntimeAccessGate.disabled,
            startAllowed: startAllowedPluginIds.contains(snapshot.pluginId),
          ),
      ],
    );
  }

  Future<PluginRuntimeCommandResult> start({required String pluginId}) => _runtime.start(pluginId: pluginId);

  Stream<RuntimeProvisionProgress> installRuntime({required String pluginId}) =>
      _runtime.installRuntime(pluginId: pluginId);

  PluginRuntimeAuthenticationOperation authenticate({required String pluginId}) =>
      _runtime.authenticate(pluginId: pluginId);

  Future<PluginRuntimeCommandResult> prepareDisable({
    required String pluginId,
    required PluginStopIntent intent,
  }) => _runtime.prepareDisable(pluginId: pluginId, intent: intent);

  void commitDisable({required String pluginId}) => _runtime.commitDisable(pluginId: pluginId);

  void rollbackDisable({required String pluginId}) => _runtime.rollbackDisable(pluginId: pluginId);

  Future<PluginRuntimeCommandResult> stopSafely({required String pluginId}) {
    return _runtime.stop(pluginId: pluginId, intent: PluginStopIntent.safe);
  }

  Future<PluginRuntimeCommandResult> restart({
    required String pluginId,
    required PluginStopIntent intent,
  }) => _runtime.restart(pluginId: pluginId, intent: intent);

  Stream<List<PluginRuntimeSnapshot>> get snapshots => _runtime.snapshots;
  List<PluginRuntimeSnapshot> get snapshot => _runtime.snapshot;
}
