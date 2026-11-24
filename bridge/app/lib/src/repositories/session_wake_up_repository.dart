import "dart:convert";
import "dart:math";

import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

import "../api/database/daos/session_wake_up_dao.dart";
import "../api/database/database.dart";
import "models/session_wake_up.dart";
import "random_hex_id.dart";

/// The wake-ups agents set, kept across a bridge restart. Ids are random, so
/// a stale id can never cancel a newer wake-up.
class SessionWakeUpRepository({required final SessionWakeUpDao _dao}) {
  static final Random _secureRandom = Random.secure();

  /// Stores a new wake-up for [sessionId] and returns it. The session row
  /// must exist.
  Future<StoredSessionWakeUp> add({
    required String sessionId,
    required String label,
    required String prompt,
    required WakeUpSchedule schedule,
    required DateTime nextDueAt,
    required DateTime createdAt,
  }) async {
    final wakeUp = StoredSessionWakeUp(
      id: generateRandomHexId(secureRandom: _secureRandom, prefix: "wakeup-", byteLength: 8),
      sessionId: sessionId,
      label: label,
      prompt: prompt,
      schedule: schedule,
      nextDueAt: nextDueAt,
      createdAt: createdAt,
    );
    await _dao.insertWakeUp(
      row: SessionWakeUpDto(
        id: wakeUp.id,
        sessionId: sessionId,
        label: label,
        prompt: prompt,
        scheduleJson: jsonEncode(schedule.toJson()),
        nextDueAt: nextDueAt.millisecondsSinceEpoch,
        createdAt: createdAt.millisecondsSinceEpoch,
      ),
    );
    return wakeUp;
  }

  /// [sessionId]'s wake-ups, soonest first.
  Future<List<StoredSessionWakeUp>> forSession({required String sessionId}) async {
    return [for (final row in await _dao.listForSession(sessionId: sessionId)) _fromRow(row: row)];
  }

  /// The wake-ups due at or before [now], soonest first.
  Future<List<StoredSessionWakeUp>> due({required DateTime now}) async {
    return [for (final row in await _dao.listDue(nowMs: now.millisecondsSinceEpoch)) _fromRow(row: row)];
  }

  Future<bool> exists({required String id}) => _dao.exists(id: id);

  /// Removes wake-up [id]; true when it existed, so of concurrent removals
  /// only one wins.
  Future<bool> remove({required String id}) => _dao.deleteWakeUp(id: id);

  /// Removes wake-up [id] when it belongs to [sessionId]; true when it did.
  Future<bool> removeFromSession({required String id, required String sessionId}) =>
      _dao.deleteSessionWakeUp(id: id, sessionId: sessionId);

  Future<void> setNextDueAt({required String id, required DateTime nextDueAt}) =>
      _dao.setNextDueAt(id: id, nextDueAtMs: nextDueAt.millisecondsSinceEpoch);

  StoredSessionWakeUp _fromRow({required SessionWakeUpDto row}) {
    return StoredSessionWakeUp(
      id: row.id,
      sessionId: row.sessionId,
      label: row.label,
      prompt: row.prompt,
      schedule: WakeUpSchedule.fromJson(jsonDecodeMap(row.scheduleJson)),
      nextDueAt: DateTime.fromMillisecondsSinceEpoch(row.nextDueAt, isUtc: true),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true),
    );
  }
}
