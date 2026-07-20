import "dart:async";

import "package:sesori_bridge/src/services/plugin_lifecycle_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

Future<PluginLifecycleService> createSinglePluginLifecycleService({
  required BridgePluginApi plugin,
}) {
  return createPluginLifecycleService(plugins: [plugin]);
}

Future<PluginLifecycleService> createPluginLifecycleService({
  required List<BridgePluginApi> plugins,
}) async {
  final service = PluginLifecycleService()
    ..registerSelection(
      knownPluginIds: plugins.map((plugin) => plugin.id).toSet(),
      enabledPlugins: [
        for (var index = 0; index < plugins.length; index++)
          (
            id: plugins[index].id,
            displayName: plugins[index].id,
            isDefault: index == 0,
          ),
      ],
    );
  await Future.wait([
    for (final plugin in plugins)
      service.registerStart(
        id: plugin.id,
        startFuture: Future.value(_TestBridgePlugin(plugin)),
        shutdownBudget: const Duration(seconds: 1),
      ),
  ]);
  return service;
}

class _TestBridgePlugin implements BridgePlugin {
  final StreamController<PluginStatus> _statuses = StreamController<PluginStatus>.broadcast();

  _TestBridgePlugin(this.api);

  @override
  final BridgePluginApi api;

  @override
  PluginStatus get currentStatus => const PluginReady();

  @override
  Stream<PluginStatus> get status => _statuses.stream;

  @override
  PluginDiagnostics describe() => PluginDiagnostics(pluginId: api.id, endpoint: null, details: const {});

  @override
  Future<void> shutdown({required Duration? budget}) => _statuses.close();
}
