/// Optional plugin capability for physically removing a deleted session's
/// persisted backend storage during bridge startup reconciliation.
///
/// The bridge invokes this only before catalog imports and client traffic can
/// load sessions into the backend process. Implementations must be idempotent:
/// an already-missing session is a successful cleanup.
abstract interface class PersistedSessionCleanupApi() {
  /// [directory] is null only for legacy tombstones that predate persisted
  /// directory attribution. Global-index implementations may ignore it.
  Future<void> deletePersistedSession({
    required String backendSessionId,
    required String? directory,
  });
}
