import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/services/new_session_plugin_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

void main() {
  group("NewSessionPluginService", () {
    const defaultPlugin = PluginMetadata(
      id: "plugin-a",
      displayName: "Plugin A",
      isDefault: true,
      state: PluginLifecycleState.ready,
      actionHint: null,
    );
    const otherPlugin = PluginMetadata(
      id: "plugin-b",
      displayName: "Plugin B",
      isDefault: false,
      state: PluginLifecycleState.ready,
      actionHint: null,
    );
    const failedPlugin = PluginMetadata(
      id: "plugin-c",
      displayName: "Plugin C",
      isDefault: false,
      state: PluginLifecycleState.failed,
      actionHint: "Restart the bridge.",
    );
    const degradedPlugin = PluginMetadata(
      id: "plugin-d",
      displayName: "Plugin D",
      isDefault: false,
      state: PluginLifecycleState.degraded,
      actionHint: "Check the bridge console.",
    );
    const plugins = [defaultPlugin, otherPlugin, failedPlugin, degradedPlugin];

    late MockPluginRepository pluginRepository;
    late MockPluginPreferenceRepository pluginPreferenceRepository;
    late NewSessionPluginService service;

    setUp(() {
      pluginRepository = MockPluginRepository();
      pluginPreferenceRepository = MockPluginPreferenceRepository();
      service = NewSessionPluginService(
        pluginRepository: pluginRepository,
        pluginPreferenceRepository: pluginPreferenceRepository,
      );

      when(pluginRepository.listPlugins).thenAnswer(
        (_) async => ApiResponse.success(const PluginListResponse(bridgeId: "br_test", plugins: plugins)),
      );
      when(
        () => pluginPreferenceRepository.readPluginId(bridgeId: any(named: "bridgeId")),
      ).thenAnswer((_) async => null);
      when(
        () => pluginPreferenceRepository.writePluginId(
          bridgeId: any(named: "bridgeId"),
          pluginId: any(named: "pluginId"),
        ),
      ).thenAnswer((_) async {});
    });

    Future<NewSessionPluginDiscovery> discover({
      String? currentSelectedPluginId,
      String? currentSelectionBridgeId,
    }) async {
      final response = await service.discover(
        currentSelectedPluginId: currentSelectedPluginId,
        currentSelectionBridgeId: currentSelectionBridgeId,
      );
      return (response as SuccessResponse<NewSessionPluginDiscovery>).data;
    }

    test("selects the saved preference when nothing is currently selected", () async {
      when(
        () => pluginPreferenceRepository.readPluginId(bridgeId: "br_test"),
      ).thenAnswer((_) async => "plugin-b");

      final discovery = await discover();

      expect(discovery.bridgeId, "br_test");
      expect(discovery.plugins, plugins);
      expect(discovery.selected, otherPlugin);
    });

    test("selects a degraded saved preference", () async {
      when(
        () => pluginPreferenceRepository.readPluginId(bridgeId: "br_test"),
      ).thenAnswer((_) async => "plugin-d");

      final discovery = await discover();

      expect(discovery.selected, degradedPlugin);
    });

    test("keeps the current selection from the same bridge over the saved preference", () async {
      when(
        () => pluginPreferenceRepository.readPluginId(bridgeId: "br_test"),
      ).thenAnswer((_) async => "plugin-d");

      final discovery = await discover(currentSelectedPluginId: "plugin-b", currentSelectionBridgeId: "br_test");

      expect(discovery.selected, otherPlugin);
      verifyNever(() => pluginPreferenceRepository.readPluginId(bridgeId: any(named: "bridgeId")));
    });

    test("does not leak a current selection carried from another bridge", () async {
      when(
        () => pluginPreferenceRepository.readPluginId(bridgeId: "br_test"),
      ).thenAnswer((_) async => "plugin-b");

      final discovery = await discover(currentSelectedPluginId: "plugin-d", currentSelectionBridgeId: "br_other");

      expect(discovery.selected, otherPlugin);
    });

    test("ignores a current selection that is no longer routable", () async {
      final discovery = await discover(currentSelectedPluginId: "plugin-c", currentSelectionBridgeId: "br_test");

      expect(discovery.selected, defaultPlugin);
    });

    test("falls back to the default when the saved preference is stale or unroutable", () async {
      when(
        () => pluginPreferenceRepository.readPluginId(bridgeId: "br_test"),
      ).thenAnswer((_) async => "plugin-c");

      final discovery = await discover();

      expect(discovery.selected, defaultPlugin);
    });

    test("degrades to the default when reading the preference fails", () async {
      when(
        () => pluginPreferenceRepository.readPluginId(bridgeId: "br_test"),
      ).thenThrow(Exception("keychain unavailable"));

      final discovery = await discover();

      expect(discovery.selected, defaultPlugin);
    });

    test("missing bridge identity selects the default without reading preferences", () async {
      when(pluginRepository.listPlugins).thenAnswer(
        (_) async => ApiResponse.success(const PluginListResponse(bridgeId: null, plugins: plugins)),
      );

      final discovery = await discover(currentSelectedPluginId: "plugin-b", currentSelectionBridgeId: null);

      expect(discovery.bridgeId, isNull);
      expect(discovery.selected, defaultPlugin);
      verifyNever(() => pluginPreferenceRepository.readPluginId(bridgeId: any(named: "bridgeId")));
    });

    test("passes discovery errors through unchanged", () async {
      final error = ApiError.nonSuccessCode(errorCode: 503, rawErrorString: null);
      when(pluginRepository.listPlugins).thenAnswer((_) async => ApiResponse.error(error));

      final response = await service.discover(currentSelectedPluginId: null, currentSelectionBridgeId: null);

      expect(response, ApiResponse<NewSessionPluginDiscovery>.error(error));
    });

    test("records the selection for the discovery bridge", () async {
      await service.recordSelection(bridgeId: "br_test", plugin: otherPlugin);

      verify(
        () => pluginPreferenceRepository.writePluginId(bridgeId: "br_test", pluginId: "plugin-b"),
      ).called(1);
    });

    test("does not record without a bridge identity", () async {
      await service.recordSelection(bridgeId: null, plugin: otherPlugin);

      verifyNever(
        () => pluginPreferenceRepository.writePluginId(
          bridgeId: any(named: "bridgeId"),
          pluginId: any(named: "pluginId"),
        ),
      );
    });

    test("never blocks session creation on a preference write failure", () async {
      when(
        () => pluginPreferenceRepository.writePluginId(
          bridgeId: any(named: "bridgeId"),
          pluginId: any(named: "pluginId"),
        ),
      ).thenThrow(Exception("keychain unavailable"));

      await expectLater(service.recordSelection(bridgeId: "br_test", plugin: otherPlugin), completes);
    });
  });
}
