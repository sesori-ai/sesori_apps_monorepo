import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/src/api/plugin_preference_api.dart";
import "package:sesori_dart_core/src/repositories/plugin_preference_repository.dart";
import "package:test/test.dart";

class MockPluginPreferenceApi() extends Mock implements PluginPreferenceApi;

void main() {
  group("PluginPreferenceRepository", () {
    late MockPluginPreferenceApi api;
    late PluginPreferenceRepository repository;

    setUp(() {
      api = MockPluginPreferenceApi();
      repository = PluginPreferenceRepository(api: api);
    });

    test("delegates reads to the api", () async {
      when(() => api.readPluginId(bridgeId: "br_abc12345")).thenAnswer((_) async => "codex");

      expect(await repository.readPluginId(bridgeId: "br_abc12345"), "codex");
      verify(() => api.readPluginId(bridgeId: "br_abc12345")).called(1);
    });

    test("delegates writes to the api", () async {
      when(() => api.writePluginId(bridgeId: "br_abc12345", pluginId: "codex")).thenAnswer((_) async {});

      await repository.writePluginId(bridgeId: "br_abc12345", pluginId: "codex");

      verify(() => api.writePluginId(bridgeId: "br_abc12345", pluginId: "codex")).called(1);
    });
  });
}
