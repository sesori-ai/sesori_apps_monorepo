import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

@lazySingleton
class PluginPreferenceApi({required final SecureStorage _storage}) {
  Future<String?> readPluginId({required String bridgeId}) {
    return _storage.read(key: _storageKey(bridgeId: bridgeId));
  }

  Future<void> writePluginId({required String bridgeId, required String pluginId}) {
    return _storage.write(
      key: _storageKey(bridgeId: bridgeId),
      value: pluginId,
    );
  }

  // Auth server bridge IDs are globally unique, so no account prefix is
  // needed. Revocation remints the ID and intentionally starts a fresh
  // preference; stale keys have no deletion API because there is no concrete
  // cleanup caller.
  String _storageKey({required String bridgeId}) => "new_session_plugin_${Uri.encodeComponent(bridgeId)}";
}
