import "dart:convert";

import "package:sesori_shared/sesori_shared.dart";

import "../../api/database/database.dart";
import "../../api/database/tables/scheduled_task_runs_table.dart";
import "../../api/database/tables/scheduled_tasks_table.dart";
import "../models/scheduled_task_record.dart";

/// Maps task and run rows to their records and wire shapes. Callers validate
/// definitions first, so an unknown variant reaching storage is a bug.
class const ScheduledTaskMapper() {
  ScheduledTaskRecord recordFromDto({required ScheduledTaskDto row}) {
    final modelJson = row.modelJson;
    final variant = row.variant;
    return ScheduledTaskRecord(
      id: row.id,
      definition: ScheduledTaskDefinition(
        name: row.name,
        prompt: ScheduledTaskPrompt.fromJson(jsonDecodeMap(row.promptJson)),
        projectId: row.projectId,
        pluginId: row.pluginId,
        agent: row.agent,
        model: modelJson == null ? null : PromptModel.fromJson(jsonDecodeMap(modelJson)),
        variant: variant == null ? null : SessionVariant(id: variant),
        fastMode: row.fastMode,
        dedicatedWorktree: row.dedicatedWorktree,
        schedule: TaskSchedule.fromJson(jsonDecodeMap(row.scheduleJson)),
        timeZone: row.timeZone,
        missedRunPolicy: row.missedRunPolicy,
        runMode: switch (row.runMode) {
          ScheduledTaskRunModeKind.newSession => const TaskRunMode.newSession(),
          ScheduledTaskRunModeKind.sameSession => TaskRunMode.sameSession(autoCompact: row.autoCompact),
        },
        approvalMode: row.approvalMode,
      ),
      enabled: row.enabled,
      command: row.command,
      nextDueAt: _instantOrNull(row.nextDueAt),
      targetSessionId: row.targetSessionId,
      completedAt: _instantOrNull(row.completedAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt, isUtc: true),
    );
  }

  /// A task row holding [definition], its [command] and the given bridge
  /// state, in storage units.
  ScheduledTaskDto taskDto({
    required String id,
    required ScheduledTaskDefinition definition,
    required bool enabled,
    required String? command,
    required int? nextDueAt,
    required String? targetSessionId,
    required int? completedAt,
    required int createdAt,
    required int updatedAt,
  }) {
    final (runMode, autoCompact) = switch (definition.runMode) {
      TaskRunModeNewSession() => (ScheduledTaskRunModeKind.newSession, false),
      TaskRunModeSameSession(:final autoCompact) => (ScheduledTaskRunModeKind.sameSession, autoCompact),
      TaskRunModeUnknown() => throw ArgumentError.value(definition.runMode, "runMode", "unknown run mode"),
    };
    final model = definition.model;
    return ScheduledTaskDto(
      id: id,
      name: definition.name,
      promptJson: jsonEncode(definition.prompt.toJson()),
      projectId: definition.projectId,
      pluginId: definition.pluginId,
      agent: definition.agent,
      modelJson: model == null ? null : jsonEncode(model.toJson()),
      variant: definition.variant?.id,
      fastMode: definition.fastMode,
      dedicatedWorktree: definition.dedicatedWorktree,
      scheduleJson: jsonEncode(definition.schedule.toJson()),
      timeZone: definition.timeZone,
      missedRunPolicy: definition.missedRunPolicy,
      runMode: runMode,
      autoCompact: autoCompact,
      approvalMode: definition.approvalMode,
      enabled: enabled,
      command: command,
      nextDueAt: nextDueAt,
      targetSessionId: targetSessionId,
      completedAt: completedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// [sessionProjectId] is the project the run's session is in now.
  ScheduledTaskRun runFromDto({required ScheduledTaskRunDto row, required String? sessionProjectId}) =>
      ScheduledTaskRun(
        id: row.id,
        scheduledFor: ScheduledTaskInstant(at: row.scheduledFor, offsetMinutes: row.scheduledForOffsetMinutes),
        outcome: switch (row.outcome) {
          ScheduledTaskRunOutcomeKind.started => ScheduledTaskRunOutcome.started(
            session: switch ((row.sessionId, sessionProjectId)) {
              (final id?, final projectId?) => ScheduledTaskRunSession(id: id, projectId: projectId),
              _ => null,
            },
            late: row.late,
          ),
          ScheduledTaskRunOutcomeKind.skipped => const ScheduledTaskRunOutcome.skipped(),
          ScheduledTaskRunOutcomeKind.missed => const ScheduledTaskRunOutcome.missed(),
          ScheduledTaskRunOutcomeKind.failed => ScheduledTaskRunOutcome.failed(
            reason: row.reason ?? TaskRunFailureReason.unknown,
            attempt: switch (row.attemptJson) {
              final json? => ScheduledTaskRunAttempt.fromJson(jsonDecodeMap(json)),
              null => null,
            },
          ),
        },
      );

  ScheduledTaskRunDto runToDto({
    required String id,
    required String taskId,
    required ScheduledTaskInstant scheduledFor,
    required ScheduledTaskRunOutcome outcome,
    required DateTime firedAt,
  }) {
    final (kind, sessionId, late, reason, attempt) = switch (outcome) {
      ScheduledTaskRunStarted(:final session, :final late) => (
        ScheduledTaskRunOutcomeKind.started,
        session?.id,
        late,
        null,
        null,
      ),
      ScheduledTaskRunSkipped() => (ScheduledTaskRunOutcomeKind.skipped, null, false, null, null),
      ScheduledTaskRunMissed() => (ScheduledTaskRunOutcomeKind.missed, null, false, null, null),
      ScheduledTaskRunFailed(:final reason, :final attempt) => (
        ScheduledTaskRunOutcomeKind.failed,
        null,
        false,
        reason,
        attempt,
      ),
      ScheduledTaskRunOutcomeUnknown() => throw ArgumentError.value(outcome, "outcome", "unknown run outcome"),
    };
    return ScheduledTaskRunDto(
      id: id,
      taskId: taskId,
      sessionId: sessionId,
      scheduledFor: scheduledFor.at,
      scheduledForOffsetMinutes: scheduledFor.offsetMinutes,
      firedAt: firedAt.millisecondsSinceEpoch,
      outcome: kind,
      reason: reason,
      attemptJson: attemptToJson(attempt: attempt),
      late: late,
      userPromptedAt: null,
      compactRequestedAt: null,
    );
  }

  static DateTime? _instantOrNull(int? milliseconds) =>
      milliseconds == null ? null : DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);

  String? attemptToJson({required ScheduledTaskRunAttempt? attempt}) =>
      attempt == null ? null : jsonEncode(attempt.toJson());
}
