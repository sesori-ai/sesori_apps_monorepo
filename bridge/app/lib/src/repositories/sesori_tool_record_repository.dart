import "dart:convert";

import "package:clock/clock.dart";
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;
import "package:sesori_tool_interface/sesori_tool_interface.dart" show SesoriToolGroupId, SesoriToolSessionRecord;

import "../api/database/daos/sesori_tool_record_dao.dart";
import "../api/database/database.dart";

/// The records Sesori tool groups keep across restarts, each a JSON object
/// in its group's own format. A session's records go with the session.
class SesoriToolRecordRepository({required final SesoriToolRecordDao _dao, required final Clock _clock}) {
  Future<Map<String, Object?>?> getSessionRecord({
    required SesoriToolGroupId groupId,
    required String sessionId,
    required String key,
  }) async {
    final row = await _dao.getSessionRecord(groupId: groupId.value, sessionId: sessionId, recordKey: key);
    return row == null ? null : jsonDecodeMap(row.valueJson);
  }

  Future<void> putSessionRecord({
    required SesoriToolGroupId groupId,
    required String sessionId,
    required String key,
    required Map<String, Object?> value,
  }) async {
    await _dao.upsertSessionRecord(
      row: SesoriToolSessionRecordDto(
        groupId: groupId.value,
        sessionId: sessionId,
        recordKey: key,
        valueJson: jsonEncode(value),
        updatedAt: _clock.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<bool> deleteSessionRecord({
    required SesoriToolGroupId groupId,
    required String sessionId,
    required String key,
  }) => _dao.deleteSessionRecord(groupId: groupId.value, sessionId: sessionId, recordKey: key);

  Future<Map<String, Map<String, Object?>>> listRecordsOfSession({
    required SesoriToolGroupId groupId,
    required String sessionId,
  }) async {
    return {
      for (final row in await _dao.listRecordsOfSession(groupId: groupId.value, sessionId: sessionId))
        row.recordKey: jsonDecodeMap(row.valueJson),
    };
  }

  Future<List<SesoriToolSessionRecord>> listSessionRecords({required SesoriToolGroupId groupId}) async {
    return [
      for (final row in await _dao.listSessionRecords(groupId: groupId.value))
        SesoriToolSessionRecord(sessionId: row.sessionId, key: row.recordKey, value: jsonDecodeMap(row.valueJson)),
    ];
  }

  Future<Map<String, Object?>?> getRecord({required SesoriToolGroupId groupId, required String key}) async {
    final row = await _dao.getRecord(groupId: groupId.value, recordKey: key);
    return row == null ? null : jsonDecodeMap(row.valueJson);
  }

  Future<void> putRecord({
    required SesoriToolGroupId groupId,
    required String key,
    required Map<String, Object?> value,
  }) async {
    await _dao.upsertRecord(
      row: SesoriToolRecordDto(
        groupId: groupId.value,
        recordKey: key,
        valueJson: jsonEncode(value),
        updatedAt: _clock.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<bool> deleteRecord({required SesoriToolGroupId groupId, required String key}) =>
      _dao.deleteRecord(groupId: groupId.value, recordKey: key);

  Future<Map<String, Map<String, Object?>>> listRecords({required SesoriToolGroupId groupId}) async {
    return {
      for (final row in await _dao.listRecords(groupId: groupId.value)) row.recordKey: jsonDecodeMap(row.valueJson),
    };
  }
}
