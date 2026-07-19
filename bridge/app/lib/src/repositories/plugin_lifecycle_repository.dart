import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../bridge/runtime/plugin_runtime.dart";

class PluginLifecycleSnapshot {
  const PluginLifecycleSnapshot({
    required this.pluginId,
    required this.projectOwnership,
    required this.setup,
    required this.accessGate,
    required this.startAllowed,
    required this.state,
    required this.workState,
    required this.leaseCount,
    required this.transitionSettled,
  });

  final String pluginId;
  final PluginProjectOwnership projectOwnership;
  final PluginSetupStatus setup;
  final PluginRuntimeAccessGate accessGate;
  bool get eligible => accessGate != PluginRuntimeAccessGate.disabled;
  final bool startAllowed;
  final PluginRuntimeState state;
  final PluginWorkState workState;
  final int leaseCount;
  final bool transitionSettled;
}

class PluginLifecycleRepository {
  PluginLifecycleRepository({required PluginRuntime runtime}) : _runtime = runtime;

  final PluginRuntime _runtime;

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

  Future<PluginRuntimeCommandResult> stop({
    required String pluginId,
    required PluginStopIntent intent,
  }) => _runtime.stop(pluginId: pluginId, intent: intent);

  Future<PluginRuntimeCommandResult> stopSafely({required String pluginId}) {
    return _runtime.stop(pluginId: pluginId, intent: PluginStopIntent.safe);
  }

  Future<PluginRuntimeCommandResult> disable({
    required String pluginId,
    required PluginStopIntent intent,
  }) => _runtime.disable(pluginId: pluginId, intent: intent);

  void commitDisabled({required String pluginId}) => _runtime.commitDisabled(pluginId: pluginId);

  void restoreEnabledAfterDisable({required String pluginId}) {
    _runtime.restoreEnabledAfterDisable(pluginId: pluginId);
  }

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
          accessGate: snapshot.accessGate,
          startAllowed: snapshot.startAllowed,
          state: snapshot.state,
          workState: snapshot.workState,
          leaseCount: snapshot.leaseCount,
          transitionSettled: snapshot.transition == PluginRuntimeTransition.none,
        ),
    ]);
  }
}
