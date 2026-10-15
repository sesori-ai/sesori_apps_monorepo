import "package:injectable/injectable.dart";
import "package:sesori_persistence/sesori_persistence.dart";

import "../../foundation/persistence/persistence_keys.dart";
import "../../logging/logging.dart";

/// Persists the computer (bridge id) the relay connection targets, so the app
/// reconnects to the same computer across restarts. Cleared on logout together
/// with the room key.
@lazySingleton
class TargetBridgeStorage({required final PersisterRepository _persister}) {
  /// The stored target, or `null` when none is stored. A failed read is logged
  /// and treated as no target, so the connection still starts unpinned.
  Future<String?> read() async {
    try {
      return await _persister.readString(key: StringPreferenceKey.targetBridgeId);
    } on Object catch (error, stackTrace) {
      loge("Failed to read the target bridge id", error, stackTrace);
      return null;
    }
  }

  Future<void> write({required String bridgeId}) =>
      _persister.writeString(key: StringPreferenceKey.targetBridgeId, value: bridgeId);

  Future<void> clear() => _persister.deleteString(key: StringPreferenceKey.targetBridgeId);
}
