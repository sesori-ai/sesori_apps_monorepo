import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/plugin_preference_api.dart";
import "package:test/test.dart";

class MockSecureStorage extends Mock implements SecureStorage {}

void main() {
  late MockSecureStorage storage;
  late PluginPreferenceApi api;

  setUp(() {
    storage = MockSecureStorage();
    api = PluginPreferenceApi(storage: storage);
  });

  test("reads the raw plugin ID from an encoded per-bridge key", () async {
    when(
      () => storage.read(key: "new_session_plugin_bridge%2Fone%20two"),
    ).thenAnswer((_) async => "plugin/a");

    expect(await api.readPluginId(bridgeId: "bridge/one two"), "plugin/a");
    verify(() => storage.read(key: "new_session_plugin_bridge%2Fone%20two")).called(1);
  });

  test("writes and deletes the raw preference through the same encoded key", () async {
    when(
      () => storage.write(key: "new_session_plugin_bridge%3Aone", value: "plugin-b"),
    ).thenAnswer((_) async {});
    when(
      () => storage.delete(key: "new_session_plugin_bridge%3Aone"),
    ).thenAnswer((_) async {});

    await api.writePluginId(bridgeId: "bridge:one", pluginId: "plugin-b");
    await api.deletePluginId(bridgeId: "bridge:one");

    verify(
      () => storage.write(key: "new_session_plugin_bridge%3Aone", value: "plugin-b"),
    ).called(1);
    verify(() => storage.delete(key: "new_session_plugin_bridge%3Aone")).called(1);
  });
}
