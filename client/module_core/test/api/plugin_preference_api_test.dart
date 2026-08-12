import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/plugin_preference_api.dart";
import "package:test/test.dart";

class _InMemorySecureStorage() implements SecureStorage {
  final Map<String, String> data = {};

  @override
  Future<String?> read({required String key}) async => data[key];

  @override
  Future<void> write({required String key, required String value}) async {
    data[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    data.remove(key);
  }
}

void main() {
  group("PluginPreferenceApi", () {
    late _InMemorySecureStorage storage;
    late PluginPreferenceApi api;

    setUp(() {
      storage = _InMemorySecureStorage();
      api = PluginPreferenceApi(storage: storage);
    });

    test("round-trips a plugin id under the encoded bridge key", () async {
      await api.writePluginId(bridgeId: "br_abc12345", pluginId: "codex");

      expect(storage.data, {"new_session_plugin_br_abc12345": "codex"});
      expect(await api.readPluginId(bridgeId: "br_abc12345"), "codex");
      expect(await api.readPluginId(bridgeId: "br_other"), isNull);
    });

    test("escapes bridge ids that are not storage-key safe", () async {
      await api.writePluginId(bridgeId: "bridge/with spaces", pluginId: "opencode");

      expect(storage.data.keys.single, "new_session_plugin_bridge%2Fwith%20spaces");
      expect(await api.readPluginId(bridgeId: "bridge/with spaces"), "opencode");
    });
  });
}
