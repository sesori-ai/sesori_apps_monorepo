import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/src/api/plugin_preference_api.dart";
import "package:sesori_dart_core/src/repositories/plugin_preference_repository.dart";
import "package:test/test.dart";

class MockPluginPreferenceApi extends Mock implements PluginPreferenceApi {}

void main() {
  late MockPluginPreferenceApi api;
  late PluginPreferenceRepository repository;

  setUp(() {
    api = MockPluginPreferenceApi();
    repository = PluginPreferenceRepository(api: api);
  });

  test("delegates nullable reads to the preference API", () async {
    when(() => api.readPluginId(bridgeId: "bridge-1")).thenAnswer((_) async => null);

    expect(await repository.readPluginId(bridgeId: "bridge-1"), isNull);
    verify(() => api.readPluginId(bridgeId: "bridge-1")).called(1);
  });

  test("delegates writes and deletes to the preference API", () async {
    when(
      () => api.writePluginId(bridgeId: "bridge-1", pluginId: "plugin-a"),
    ).thenAnswer((_) async {});
    when(() => api.deletePluginId(bridgeId: "bridge-1")).thenAnswer((_) async {});

    await repository.writePluginId(bridgeId: "bridge-1", pluginId: "plugin-a");
    await repository.deletePluginId(bridgeId: "bridge-1");

    verify(
      () => api.writePluginId(bridgeId: "bridge-1", pluginId: "plugin-a"),
    ).called(1);
    verify(() => api.deletePluginId(bridgeId: "bridge-1")).called(1);
  });
}
