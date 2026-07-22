import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

@lazySingleton
class PluginPreferenceApi {
  final SecureStorage _storage;

  PluginPreferenceApi({required SecureStorage storage}) : _storage = storage;

  Future<String?> readPluginId({required String bridgeId}) {
    return _storage.read(key: _storageKey(bridgeId));
  }

  Future<void> writePluginId({required String bridgeId, required String pluginId}) {
    return _storage.write(key: _storageKey(bridgeId), value: pluginId);
  }

  Future<void> deletePluginId({required String bridgeId}) {
    return _storage.delete(key: _storageKey(bridgeId));
  }

  String _storageKey(String bridgeId) => "new_session_plugin_${Uri.encodeComponent(bridgeId)}";
}
