import "package:sesori_bridge/src/bridge/runtime/plugin_runtime.dart";
import "package:sesori_bridge/src/repositories/plugin_lifecycle_repository.dart";
import "package:sesori_bridge/src/routing/get_plugin_setup_handler.dart";
import "package:sesori_bridge/src/routing/get_plugins_handler.dart";
import "package:sesori_bridge/src/services/plugin_lifecycle_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/plugin_lifecycle_test_support.dart" show createTestBridgeSettingsRepository;
import "../../helpers/plugin_runtime_test_support.dart";
import "routing_test_helpers.dart";

void main() {
  group("GetPluginSetupHandler", () {
    late PluginLifecycleService lifecycleService;
    late PluginRuntime pluginRuntime;
    late GetPluginSetupHandler handler;
    late GetPluginsHandler selectableHandler;

    setUp(() async {
      pluginRuntime = createTestPluginRuntime(plugins: [_ReadyPluginApi()]);
      lifecycleService =
          PluginLifecycleService(
              lifecycleRepository: PluginLifecycleRepository(runtime: pluginRuntime),
              bridgeSettingsRepository: createTestBridgeSettingsRepository(),
              idleTimerScheduler: const PluginIdleTimerScheduler(),
            )
            ..registerPlugins(
              plugins: const [
                (id: "ready", displayName: "Ready"),
                (id: "blocked", displayName: "Blocked"),
              ],
            )
            ..initialize(
              disabledPluginIds: const {},
              setupById: const {
                "ready": PluginSetupReady(),
                "blocked": PluginSetupAuthenticationRequired(
                  actionHint: "Authenticate the backend locally, then retry.",
                ),
              },
            );
      await Future<void>.delayed(Duration.zero);
      handler = GetPluginSetupHandler(lifecycleService: lifecycleService);
      selectableHandler = GetPluginsHandler(lifecycleService: lifecycleService);
    });

    tearDown(() async {
      await lifecycleService.dispose();
      await pluginRuntime.dispose();
    });

    test("handles only GET /plugin/setup", () {
      expect(handler.canHandle(makeRequest("GET", "/plugin/setup")), isTrue);
      expect(handler.canHandle(makeRequest("POST", "/plugin/setup")), isFalse);
      expect(handler.canHandle(makeRequest("GET", "/plugin")), isFalse);
    });

    test("returns every registered plugin in stable order without changing activation", () async {
      final operationalBefore = pluginRuntime.activePluginIds;
      final response = await handler.handle(
        makeRequest("GET", "/plugin/setup"),
        pathParams: const {},
        queryParams: const {},
        fragment: null,
      );

      expect(response.plugins.map((plugin) => plugin.id), ["blocked", "ready"]);
      expect(response.plugins.first.state, PluginSetupState.authenticationRequired);
      expect(response.plugins.last.state, PluginSetupState.ready);
      expect(response.plugins.first.actionHint, "Authenticate the backend locally, then retry.");
      expect(pluginRuntime.activePluginIds, operationalBefore);
    });

    test("keeps setup-blocked registrations out of the compatible plugin list", () async {
      final response = await selectableHandler.handle(
        makeRequest("GET", "/plugin"),
        pathParams: const {},
        queryParams: const {},
        fragment: null,
      );

      expect(response.plugins.map((plugin) => plugin.id), ["ready"]);
      expect(response.plugins.single.isDefault, isTrue);
    });
  });
}

class _ReadyPluginApi extends NativeProjectsPluginApi {
  @override
  String get id => "ready";

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
