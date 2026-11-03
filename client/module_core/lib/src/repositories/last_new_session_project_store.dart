import "package:injectable/injectable.dart";
import "package:sesori_persistence/sesori_persistence.dart";

import "../foundation/persistence/persistence_keys.dart";
import "../logging/logging.dart";

/// Persists, per computer, the project the user last picked in the
/// new-session composer or started a session in, so the next composer opens
/// there.
///
/// The value is an ordinary plaintext device preference and survives logout.
/// Bridge ids are globally unique, so no account prefix is needed.
@lazySingleton
class LastNewSessionProjectStore({required final PersisterRepository _persister}) {
  /// The stored project, or null when none was stored or storage fails.
  Future<String?> read({required String bridgeId}) async {
    try {
      return await _persister.readString(key: LastProjectPreferenceKey(bridgeId: bridgeId));
    } on Object catch (error, stackTrace) {
      logw("Failed to read the last new-session project for bridge $bridgeId", error, stackTrace);
      return null;
    }
  }

  /// A failed write only costs the project its persistence, so it is logged
  /// rather than surfaced.
  Future<void> write({required String bridgeId, required String projectId}) async {
    try {
      await _persister.writeString(
        key: LastProjectPreferenceKey(bridgeId: bridgeId),
        value: projectId,
      );
    } on Object catch (error, stackTrace) {
      logw("Failed to persist the last new-session project for bridge $bridgeId", error, stackTrace);
    }
  }
}
