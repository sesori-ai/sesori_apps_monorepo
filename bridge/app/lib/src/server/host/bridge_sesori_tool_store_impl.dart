import "package:sesori_tool_interface/sesori_tool_interface.dart";

import "../../repositories/sesori_tool_record_repository.dart";

/// One tool group's [SesoriToolStore]: its records, scoped to [_groupId].
class BridgeSesoriToolStoreImpl({
  required final SesoriToolGroupId _groupId,
  required final SesoriToolRecordRepository _records,
}) implements SesoriToolStore {
  @override
  Future<Map<String, Object?>?> getSessionRecord({required String sessionId, required String key}) =>
      _records.getSessionRecord(groupId: _groupId, sessionId: sessionId, key: key);

  @override
  Future<void> putSessionRecord({
    required String sessionId,
    required String key,
    required Map<String, Object?> value,
  }) => _records.putSessionRecord(groupId: _groupId, sessionId: sessionId, key: key, value: value);

  @override
  Future<bool> deleteSessionRecord({required String sessionId, required String key}) =>
      _records.deleteSessionRecord(groupId: _groupId, sessionId: sessionId, key: key);

  @override
  Future<Map<String, Map<String, Object?>>> listRecordsOfSession({required String sessionId}) =>
      _records.listRecordsOfSession(groupId: _groupId, sessionId: sessionId);

  @override
  Future<List<SesoriToolSessionRecord>> listSessionRecords() => _records.listSessionRecords(groupId: _groupId);

  @override
  Future<Map<String, Object?>?> getRecord({required String key}) => _records.getRecord(groupId: _groupId, key: key);

  @override
  Future<void> putRecord({required String key, required Map<String, Object?> value}) =>
      _records.putRecord(groupId: _groupId, key: key, value: value);

  @override
  Future<bool> deleteRecord({required String key}) => _records.deleteRecord(groupId: _groupId, key: key);

  @override
  Future<Map<String, Map<String, Object?>>> listRecords() => _records.listRecords(groupId: _groupId);
}
