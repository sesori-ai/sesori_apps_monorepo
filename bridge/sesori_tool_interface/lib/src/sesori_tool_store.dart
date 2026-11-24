/// A group's records, kept by the bridge across restarts. Each value is a
/// JSON object whose format the group owns.
///
/// A session record belongs to one session and is deleted with it. A bridge
/// record belongs to the group alone. Keys are the group's own; the store
/// scopes them to the group, so two groups never see each other's records.
abstract interface class SesoriToolStore() {
  Future<Map<String, Object?>?> getSessionRecord({required String sessionId, required String key});

  /// Writes the record, replacing one with the same key. The session must
  /// exist.
  Future<void> putSessionRecord({
    required String sessionId,
    required String key,
    required Map<String, Object?> value,
  });

  /// Deletes the record; true when it existed.
  Future<bool> deleteSessionRecord({required String sessionId, required String key});

  /// [sessionId]'s records, by key.
  Future<Map<String, Map<String, Object?>>> listRecordsOfSession({required String sessionId});

  /// Every session's records, for resuming after a restart.
  Future<List<SesoriToolSessionRecord>> listSessionRecords();

  Future<Map<String, Object?>?> getRecord({required String key});

  /// Writes the record, replacing one with the same key.
  Future<void> putRecord({required String key, required Map<String, Object?> value});

  /// Deletes the record; true when it existed.
  Future<bool> deleteRecord({required String key});

  /// The group's bridge records, by key.
  Future<Map<String, Map<String, Object?>>> listRecords();
}

final class const SesoriToolSessionRecord({
  required final String sessionId,
  required final String key,
  required final Map<String, Object?> value,
});
