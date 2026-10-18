import "package:injectable/injectable.dart";
import "package:sesori_persistence/sesori_persistence.dart";

import "../foundation/persistence/persistence_keys.dart";
import "../logging/logging.dart";

/// Persists the last "New worktree" choice a session was started with, so the
/// next new-session composer opens with the same value.
///
/// The value is an ordinary plaintext device preference and survives logout.
@lazySingleton
class DedicatedWorktreePreferenceStore({required final PersisterRepository _persister}) {
  /// The last choice, or `true` when nothing was ever chosen or storage fails.
  Future<bool> read() async {
    try {
      return await _persister.readBoolOrDefault(key: BoolPreferenceKey.dedicatedWorktree, defaultValue: true);
    } on Object catch (error, stackTrace) {
      logw("Failed to read the stored dedicated worktree choice", error, stackTrace);
      return true;
    }
  }

  /// A failed write only costs the choice its persistence, so it is logged
  /// rather than surfaced.
  Future<void> write({required bool value}) async {
    try {
      await _persister.writeBool(key: BoolPreferenceKey.dedicatedWorktree, value: value);
    } on Object catch (error, stackTrace) {
      logw("Failed to persist the dedicated worktree choice", error, stackTrace);
    }
  }
}
