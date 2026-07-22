import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/repositories/plugin_preference_repository.dart";
import "package:sesori_dart_core/src/repositories/plugin_repository.dart";
import "package:sesori_dart_core/src/services/new_session_plugin_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockPluginRepository extends Mock implements PluginRepository {}

class MockPluginPreferenceRepository extends Mock implements PluginPreferenceRepository {}

const _defaultPlugin = PluginMetadata(
  id: "plugin-a",
  displayName: "Plugin A",
  isDefault: true,
  state: PluginLifecycleState.ready,
  actionHint: null,
);

const _savedPlugin = PluginMetadata(
  id: "plugin-b",
  displayName: "Plugin B",
  isDefault: false,
  state: PluginLifecycleState.degraded,
  actionHint: "Check the bridge console.",
);

void main() {
  late MockPluginRepository pluginRepository;
  late MockPluginPreferenceRepository preferenceRepository;
  late NewSessionPluginService service;

  setUp(() {
    pluginRepository = MockPluginRepository();
    preferenceRepository = MockPluginPreferenceRepository();
    service = NewSessionPluginService(
      pluginRepository: pluginRepository,
      pluginPreferenceRepository: preferenceRepository,
    );
  });

  test("exposes discovery and selects a saved routable plugin", () async {
    when(pluginRepository.listPlugins).thenAnswer(
      (_) async => ApiResponse.success(
        const PluginListResponse(
          bridgeId: "bridge-1",
          plugins: [_defaultPlugin, _savedPlugin],
        ),
      ),
    );
    when(
      () => preferenceRepository.readPluginId(bridgeId: "bridge-1"),
    ).thenAnswer((_) async => "plugin-b");

    final response = await service.discover();
    final discovery = (response as SuccessResponse<NewSessionPluginDiscovery>).data;

    expect(discovery.bridgeId, "bridge-1");
    expect(discovery.plugins, [_defaultPlugin, _savedPlugin]);
    expect(discovery.selected, _savedPlugin);
  });

  test("falls back to the response default when the saved plugin is not routable", () async {
    const unavailableSaved = PluginMetadata(
      id: "plugin-b",
      displayName: "Plugin B",
      isDefault: false,
      state: PluginLifecycleState.unavailable,
      actionHint: "Start the plugin.",
    );
    when(pluginRepository.listPlugins).thenAnswer(
      (_) async => ApiResponse.success(
        const PluginListResponse(
          bridgeId: "bridge-1",
          plugins: [_defaultPlugin, unavailableSaved],
        ),
      ),
    );
    when(
      () => preferenceRepository.readPluginId(bridgeId: "bridge-1"),
    ).thenAnswer((_) async => "plugin-b");

    final response = await service.discover();

    expect((response as SuccessResponse<NewSessionPluginDiscovery>).data.selected, _defaultPlugin);
  });

  test("does not read a preference when the bridge ID is absent", () async {
    when(pluginRepository.listPlugins).thenAnswer(
      (_) async => ApiResponse.success(
        const PluginListResponse(bridgeId: null, plugins: [_defaultPlugin, _savedPlugin]),
      ),
    );

    final response = await service.discover();

    final discovery = (response as SuccessResponse<NewSessionPluginDiscovery>).data;
    expect(discovery.bridgeId, isNull);
    expect(discovery.selected, _defaultPlugin);
    verifyNever(() => preferenceRepository.readPluginId(bridgeId: any(named: "bridgeId")));
  });

  test("logs preference read failures and falls back to the response default", () async {
    final error = StateError("secure storage unavailable");
    final logs = <String>[];
    when(pluginRepository.listPlugins).thenAnswer(
      (_) async => ApiResponse.success(
        const PluginListResponse(bridgeId: "bridge-1", plugins: [_defaultPlugin, _savedPlugin]),
      ),
    );
    when(() => preferenceRepository.readPluginId(bridgeId: "bridge-1")).thenThrow(error);

    final response = await runZoned(
      service.discover,
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => logs.add(line),
      ),
    );

    expect((response as SuccessResponse<NewSessionPluginDiscovery>).data.selected, _defaultPlugin);
    expect(logs, contains(allOf(contains("failed to read the plugin preference"), contains(error.toString()))));
  });

  test("records only a routable selection with a bridge ID", () async {
    when(
      () => preferenceRepository.writePluginId(bridgeId: "bridge-1", pluginId: "plugin-b"),
    ).thenAnswer((_) async {});

    service
      ..recordSelection(bridgeId: null, plugin: _savedPlugin)
      ..recordSelection(
        bridgeId: "bridge-1",
        plugin: const PluginMetadata(
          id: "unavailable",
          displayName: "Unavailable",
          isDefault: false,
          state: PluginLifecycleState.unavailable,
          actionHint: null,
        ),
      )
      ..recordSelection(bridgeId: "bridge-1", plugin: _savedPlugin);
    await untilCalled(
      () => preferenceRepository.writePluginId(bridgeId: "bridge-1", pluginId: "plugin-b"),
    );

    verify(
      () => preferenceRepository.writePluginId(bridgeId: "bridge-1", pluginId: "plugin-b"),
    ).called(1);
    verifyNoMoreInteractions(preferenceRepository);
  });

  test("logs unawaited persistence failures", () async {
    final error = StateError("secure storage unavailable");
    final logs = <String>[];
    when(
      () => preferenceRepository.writePluginId(bridgeId: "bridge-1", pluginId: "plugin-b"),
    ).thenThrow(error);

    await runZoned(
      () async {
        service.recordSelection(bridgeId: "bridge-1", plugin: _savedPlugin);
        await Future<void>.delayed(Duration.zero);
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => logs.add(line),
      ),
    );

    expect(logs, contains(allOf(contains("failed to persist the plugin preference"), contains(error.toString()))));
  });
}
