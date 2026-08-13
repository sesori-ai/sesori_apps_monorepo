import "package:sesori_bridge/src/bridge/runtime/plugin_runtime.dart";
import "package:sesori_bridge/src/repositories/bridge_settings.dart";
import "package:sesori_bridge/src/repositories/bridge_settings_repository.dart";
import "package:sesori_bridge/src/repositories/plugin_lifecycle_repository.dart";
import "package:sesori_bridge/src/services/plugin_lifecycle_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show legacyMissingPluginId;

import "plugin_runtime_test_support.dart";
import "test_helpers.dart";

final Expando<PluginRuntime> _runtimes = Expando<PluginRuntime>();
final Expando<BridgeSettingsRepository> _settingsRepositories = Expando<BridgeSettingsRepository>();

const defaultManagementCapabilities = <PluginControlCapability>{
  PluginControlCapability.lifecycle,
  PluginControlCapability.setupRefresh,
  PluginControlCapability.idleTimeout,
};

Future<PluginLifecycleService> createSinglePluginLifecycleService({
  required BridgePluginApi plugin,
}) {
  return createPluginLifecycleService(plugins: [plugin]);
}

Future<PluginLifecycleService> createPluginLifecycleService({
  required List<BridgePluginApi> plugins,
}) async {
  final runtime = createTestPluginRuntime(plugins: plugins);
  final settingsRepository = createTestBridgeSettingsRepository();
  final service =
      PluginLifecycleService(
          lifecycleRepository: PluginLifecycleRepository(runtime: runtime),
          preferredDefaultPluginId: legacyMissingPluginId,
          bridgeSettingsRepository: settingsRepository,
          idleTimerScheduler: const PluginIdleTimerScheduler(),
          bridgeIdProvider: FakeBridgeIdProvider("br_test1234"),
        )
        ..registerPlugins(
          plugins: [
            for (final plugin in plugins)
              (
                id: plugin.id,
                displayName: plugin.id,
                activationPolicy: PluginActivationPolicy.onDemand,
                residencyPolicy: PluginResidencyPolicy.transient,
                sessionOptionsScope: PluginSessionOptionsScope.project,
                managementCapabilities: defaultManagementCapabilities,
                supportsPromptAttachments: false,
              ),
          ],
        )
        ..initialize(
          disabledPluginIds: const {},
          setupById: {for (final plugin in plugins) plugin.id: const PluginSetupReady()},
        );
  _runtimes[service] = runtime;
  _settingsRepositories[service] = settingsRepository;
  await Future<void>.delayed(Duration.zero);
  return service;
}

BridgeSettingsRepository createTestBridgeSettingsRepository({
  BridgeSettings settings = const BridgeSettings(),
}) => _TestBridgeSettingsRepository(settings: settings);

BridgeSettingsRepository settingsRepositoryForLifecycleService({required PluginLifecycleService service}) {
  final repository = _settingsRepositories[service];
  if (repository == null) throw StateError("No test bridge settings repository is registered for this service.");
  return repository;
}

Future<void> activateTestPlugin({
  required PluginLifecycleService service,
  required String pluginId,
}) async {
  await runtimeForLifecycleService(service: service).use<void>(
    pluginId: pluginId,
    operation: _TestPluginOperation.activate,
    body: (_) async {},
  );
}

PluginRuntime runtimeForLifecycleService({required PluginLifecycleService service}) {
  final runtime = _runtimes[service];
  if (runtime == null) throw StateError("No test plugin runtime is registered for this lifecycle service.");
  return runtime;
}

enum _TestPluginOperation() { activate }

class _TestBridgeSettingsRepository({required var BridgeSettings settings}) implements BridgeSettingsRepository {
  @override
  BridgeSettings get currentSettings => settings;

  @override
  Stream<BridgeSettingsChange> get settingsChanges => const Stream<BridgeSettingsChange>.empty();

  @override
  Future<BridgeSettings> loadSettings() async => settings;

  @override
  Future<BridgeSettings> mutateSettings({
    required BridgeSettings Function({required BridgeSettings current}) mutation,
  }) async {
    return settings = mutation(current: settings);
  }

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
