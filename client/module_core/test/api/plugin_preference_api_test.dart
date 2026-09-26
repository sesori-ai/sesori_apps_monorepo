import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/src/api/plugin_preference_api.dart";
import "package:sesori_persistence/sesori_persistence.dart";
import "package:test/test.dart";

class _InMemoryPersister() extends Fake implements PersisterRepository {
  final Map<String, String> data = {};

  @override
  Future<String?> readString({required StringPersistenceKey key}) async => data[key.storageKey];

  @override
  Future<void> writeString({required StringPersistenceKey key, required String value}) async {
    data[key.storageKey] = value;
  }

  @override
  Future<void> deleteString({required StringPersistenceKey key}) async {
    data.remove(key.storageKey);
  }
}

void main() {
  group("PluginPreferenceApi", () {
    late _InMemoryPersister storage;
    late PluginPreferenceApi api;

    setUp(() {
      storage = _InMemoryPersister();
      api = PluginPreferenceApi(persister: storage);
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
