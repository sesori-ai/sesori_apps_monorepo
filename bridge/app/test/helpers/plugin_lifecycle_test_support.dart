import "package:sesori_bridge/src/bridge/runtime/plugin_runtime.dart";
import "package:sesori_bridge/src/repositories/plugin_lifecycle_repository.dart";
import "package:sesori_bridge/src/services/plugin_lifecycle_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show legacyMissingPluginId;

import "plugin_runtime_test_support.dart";

final Expando<PluginRuntime> _runtimes = Expando<PluginRuntime>();

Future<PluginLifecycleService> createSinglePluginLifecycleService({
  required BridgePluginApi plugin,
}) {
  return createPluginLifecycleService(plugins: [plugin]);
}

Future<PluginLifecycleService> createPluginLifecycleService({
  required List<BridgePluginApi> plugins,
}) async {
  final runtime = createTestPluginRuntime(plugins: plugins);
  final service =
      PluginLifecycleService(
          lifecycleRepository: PluginLifecycleRepository(runtime: runtime),
          preferredDefaultPluginId: legacyMissingPluginId,
        )
        ..registerPlugins(
          plugins: [for (final plugin in plugins) (id: plugin.id, displayName: plugin.id)],
        )
        ..initialize(
          disabledPluginIds: const {},
          setupById: {for (final plugin in plugins) plugin.id: const PluginSetupReady()},
        );
  _runtimes[service] = runtime;
  await Future<void>.delayed(Duration.zero);
  return service;
}

PluginRuntime runtimeForLifecycleService({required PluginLifecycleService service}) {
  final runtime = _runtimes[service];
  if (runtime == null) throw StateError("No test plugin runtime is registered for this lifecycle service.");
  return runtime;
}
