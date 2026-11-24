import "dart:async";

import "package:clock/clock.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/scheduled_task_record.dart";
import "../repositories/models/task_command_edit.dart";
import "../repositories/scheduled_task_repository.dart";
import "../repositories/session_repository.dart";
import "scheduled_task_occurrence_calculator.dart";
import "scheduled_task_request_exception.dart";
import "session_mutation_dispatcher.dart";

/// Creates, edits, pauses and deletes tasks, and keeps each task's next due
/// time. Every change is announced on [changes], and a change to a
/// same-session task also as its target session's arming.
class ScheduledTaskService({
  required final ScheduledTaskRepository _repository,
  required final SessionRepository _sessionRepository,
  required final SessionMutationDispatcher _mutations,
  required final ScheduledTaskOccurrenceCalculator _calculator,
  required final Clock _clock,
}) {
  final StreamController<void> _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;

  /// The tasks not yet done, each with its newest run.
  Future<ScheduledTaskListResponse> list() async {
    final records = await _repository.listUncompleted();
    final latestRuns = await _repository.latestRuns(taskIds: {for (final record in records) record.id});
    return ScheduledTaskListResponse(
      items: [for (final record in records) _toWire(record: record, lastRun: latestRuns[record.id])],
    );
  }

  /// [command] is the shell command each run runs first; only an allowed
  /// agent request sets one.
  Future<ScheduledTask> create({required ScheduledTaskDefinition definition, required String? command}) async {
    final now = _clock.now();
    final firstDueAt = await _validate(definition: definition, now: now);
    final record = await _repository.create(definition: definition, command: command, nextDueAt: firstDueAt, now: now);
    _changes.add(null);
    return _toWire(record: record, lastRun: null);
  }

  /// Replaces the definition and applies [command]; future runs only. A
  /// paused task stays paused. A slash-command prompt runs no shell command,
  /// so an app edit that turns the prompt into one removes it.
  Future<ScheduledTask> update({
    required String taskId,
    required ScheduledTaskDefinition definition,
    required TaskCommandEdit command,
  }) async {
    final existing = await _requireUncompleted(taskId: taskId);
    final now = _clock.now();
    final firstDueAt = await _validate(definition: definition, now: now);
    final record = await _repository.updateDefinition(
      taskId: taskId,
      definition: definition,
      command: definition.prompt is ScheduledTaskPromptCommand ? const TaskCommandRemoved() : command,
      nextDueAt: existing.enabled ? firstDueAt : null,
      clearTarget: !_keepsTargetSession(before: existing.definition, after: definition),
      now: now,
    );
    if (record == null) _refuse(code: ScheduledTaskErrorCode.taskNotFound);
    _changes.add(null);
    await _announceTarget(sessionId: existing.targetSessionId);
    return _toWire(
      record: record,
      lastRun: await _latestRun(taskId: taskId),
    );
  }

  /// Pausing clears the next due time; resuming computes it from now, so the
  /// paused period is never replayed.
  Future<ScheduledTask> setEnabled({required String taskId, required bool enabled}) async {
    final existing = await _requireUncompleted(taskId: taskId);
    if (existing.enabled == enabled) {
      return _toWire(
        record: existing,
        lastRun: await _latestRun(taskId: taskId),
      );
    }
    final now = _clock.now();
    final definition = existing.definition;
    final record = await _repository.setEnabled(
      taskId: taskId,
      enabled: enabled,
      nextDueAt: enabled
          ? _calculator.firstDueAt(schedule: definition.schedule, timeZone: definition.timeZone, now: now)
          : null,
      now: now,
    );
    if (record == null) _refuse(code: ScheduledTaskErrorCode.taskNotFound);
    _changes.add(null);
    await _announceTarget(sessionId: existing.targetSessionId);
    return _toWire(
      record: record,
      lastRun: await _latestRun(taskId: taskId),
    );
  }

  /// Deletes the task and its history. Its sessions stay as ordinary sessions.
  Future<void> delete({required String taskId}) async {
    final targetSessionId = (await _repository.get(taskId: taskId))?.targetSessionId;
    if (!await _repository.delete(taskId: taskId)) {
      _refuse(code: ScheduledTaskErrorCode.taskNotFound);
    }
    _changes.add(null);
    await _announceTarget(sessionId: targetSessionId);
  }

  /// A task that continues in a session moves or ends that session's arming
  /// when it changes.
  Future<void> _announceTarget({required String? sessionId}) async {
    if (sessionId != null) await _mutations.armingUpdated(sessionId: sessionId);
  }

  /// The task's run history, newest first. A done one-off task still has one.
  Future<ScheduledTaskRunListResponse> listRuns({required String taskId}) async {
    if (await _repository.get(taskId: taskId) == null) {
      _refuse(code: ScheduledTaskErrorCode.taskNotFound);
    }
    return ScheduledTaskRunListResponse(items: await _repository.listRuns(taskId: taskId));
  }

  /// Throws the [ScheduledTaskRequestException] that [create] or [update]
  /// would for [definition], so a proposal is checked before anyone approves
  /// it.
  Future<void> validate({required ScheduledTaskDefinition definition}) async {
    await _validate(definition: definition, now: _clock.now());
  }

  Future<void> dispose() => _changes.close();

  /// A done one-off task has left the list, so it can no longer be edited.
  Future<ScheduledTaskRecord> _requireUncompleted({required String taskId}) async {
    final record = await _repository.get(taskId: taskId);
    if (record == null || record.completedAt != null) {
      _refuse(code: ScheduledTaskErrorCode.taskNotFound);
    }
    return record;
  }

  Future<ScheduledTaskRun?> _latestRun({required String taskId}) async =>
      (await _repository.latestRuns(taskIds: {taskId}))[taskId];

  /// Refuses a definition the bridge cannot run and returns when it first
  /// falls due.
  Future<DateTime?> _validate({required ScheduledTaskDefinition definition, required DateTime now}) async {
    if (definition.name.trim().isEmpty) _refuse(code: ScheduledTaskErrorCode.emptyName);
    switch (definition.prompt) {
      case ScheduledTaskPromptText(:final text):
        if (text.trim().isEmpty) _refuse(code: ScheduledTaskErrorCode.emptyPrompt);
      case ScheduledTaskPromptCommand(:final name, :final source):
        if (name.trim().isEmpty) _refuse(code: ScheduledTaskErrorCode.emptyPrompt);
        if (source == CommandSource.unknown) _refuse(code: ScheduledTaskErrorCode.unsupportedByBridge);
      case ScheduledTaskPromptUnknown():
        _refuse(code: ScheduledTaskErrorCode.unsupportedByBridge);
    }
    if (definition.runMode is TaskRunModeUnknown ||
        definition.missedRunPolicy == TaskMissedRunPolicy.unknown ||
        definition.approvalMode == TaskApprovalMode.unknown) {
      _refuse(code: ScheduledTaskErrorCode.unsupportedByBridge);
    }
    _validateSchedule(schedule: definition.schedule);
    if (!_calculator.isKnownTimeZone(timeZone: definition.timeZone)) {
      _refuse(code: ScheduledTaskErrorCode.unknownTimeZone);
    }
    if (!_sessionRepository.isPluginEligible(pluginId: definition.pluginId)) {
      _refuse(code: ScheduledTaskErrorCode.unknownHarness);
    }
    if (await _sessionRepository.getProjectPath(projectId: definition.projectId) == null) {
      _refuse(code: ScheduledTaskErrorCode.unknownProject);
    }
    final firstDueAt = _calculator.firstDueAt(schedule: definition.schedule, timeZone: definition.timeZone, now: now);
    if (definition.schedule is TaskScheduleOnce && firstDueAt != null && !firstDueAt.isAfter(now)) {
      _refuse(code: ScheduledTaskErrorCode.onceTimeInPast);
    }
    return firstDueAt;
  }

  void _validateSchedule({required TaskSchedule schedule}) {
    final valid = switch (schedule) {
      TaskScheduleOnce(:final at) => _isValidLocalDateTime(local: at),
      TaskScheduleDaily(:final time) || TaskScheduleWeekdays(:final time) => _isValidTime(time: time),
      TaskScheduleWeekly(:final days, :final time) => days.isNotEmpty && _isValidTime(time: time),
      TaskScheduleEveryHours(:final hours, :final start) =>
        hours >= 1 && hours <= 12
            ? _isValidLocalDateTime(local: start)
            : _refuse(code: ScheduledTaskErrorCode.hoursOutOfRange),
      TaskScheduleUnknown() => _refuse(code: ScheduledTaskErrorCode.unsupportedByBridge),
    };
    if (!valid) _refuse(code: ScheduledTaskErrorCode.invalidSchedule);
  }

  static bool _isValidTime({required TaskTimeOfDay time}) => _isValidClock(hour: time.hour, minute: time.minute);

  static bool _isValidLocalDateTime({required TaskLocalDateTime local}) {
    // Years outside 1–9999 are not a real schedule, and DateTime rejects the
    // far ones outright.
    if (local.year < 1 || local.year > 9999) return false;
    if (local.month < 1 || local.month > 12 || local.day < 1) return false;
    // Day 0 of the next month is this month's last day.
    final daysInMonth = DateTime.utc(local.year, local.month + 1, 0).day;
    return local.day <= daysInMonth && _isValidClock(hour: local.hour, minute: local.minute);
  }

  static bool _isValidClock({required int hour, required int minute}) =>
      hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59;

  /// A same-session task keeps its session only while it still runs in the
  /// same project, harness and worktree setup; otherwise the next run starts a
  /// fresh session.
  static bool _keepsTargetSession({required ScheduledTaskDefinition before, required ScheduledTaskDefinition after}) =>
      before.runMode is TaskRunModeSameSession &&
      after.runMode is TaskRunModeSameSession &&
      before.projectId == after.projectId &&
      before.pluginId == after.pluginId &&
      before.dedicatedWorktree == after.dedicatedWorktree;

  static Never _refuse({required ScheduledTaskErrorCode code}) => throw ScheduledTaskRequestException(code: code);

  ScheduledTask _toWire({required ScheduledTaskRecord record, required ScheduledTaskRun? lastRun}) {
    final nextDueAt = record.nextDueAt;
    return ScheduledTask(
      id: record.id,
      definition: record.definition,
      enabled: record.enabled,
      command: record.command,
      nextRunAt: nextDueAt == null
          ? null
          : ScheduledTaskInstant(
              at: nextDueAt.millisecondsSinceEpoch,
              offsetMinutes: _calculator.offsetMinutesAt(instant: nextDueAt, timeZone: record.definition.timeZone),
            ),
      lastRun: lastRun,
    );
  }
}
