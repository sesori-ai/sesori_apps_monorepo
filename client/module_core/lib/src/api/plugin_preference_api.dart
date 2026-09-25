import "package:injectable/injectable.dart";
import "package:sesori_persistence/sesori_persistence.dart";

import "../foundation/persistence/persistence_keys.dart";

// Auth server bridge IDs are globally unique, so no account prefix is needed.
// Revocation remints the ID and intentionally starts a fresh preference; stale
// keys have no deletion API because there is no concrete cleanup caller.
@lazySingleton
class PluginPreferenceApi({required final PersisterRepository _persister}) {
  Future<String?> readPluginId({required String bridgeId}) {
    return _persister.readString(key: PluginPreferenceKey(bridgeId: bridgeId));
  }

  Future<void> writePluginId({required String bridgeId, required String pluginId}) {
    return _persister.writeString(
      key: PluginPreferenceKey(bridgeId: bridgeId),
      value: pluginId,
    );
  }
}
