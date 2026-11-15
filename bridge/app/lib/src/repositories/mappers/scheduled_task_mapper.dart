import "dart:convert";

import "package:drift/drift.dart" show Value;
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
      nextDueAt: _instantOrNull(row.nextDueAt),
      targetSessionId: row.targetSessionId,
      completedAt: _instantOrNull(row.completedAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt, isUtc: true),
    );
  }

  /// The definition's columns, for an insert or an update.
  ScheduledTasksTableCompanion definitionColumns({required ScheduledTaskDefinition definition}) {
    final (runMode, autoCompact) = switch (definition.runMode) {
      TaskRunModeNewSession() => (ScheduledTaskRunModeKind.newSession, false),
      TaskRunModeSameSession(:final autoCompact) => (ScheduledTaskRunModeKind.sameSession, autoCompact),
      TaskRunModeUnknown() => throw ArgumentError.value(definition.runMode, "runMode", "unknown run mode"),
    };
    final model = definition.model;
    return ScheduledTasksTableCompanion(
      name: Value(definition.name),
      promptJson: Value(jsonEncode(definition.prompt.toJson())),
      projectId: Value(definition.projectId),
      pluginId: Value(definition.pluginId),
      agent: Value(definition.agent),
      modelJson: Value(model == null ? null : jsonEncode(model.toJson())),
      variant: Value(definition.variant?.id),
      fastMode: Value(definition.fastMode),
      dedicatedWorktree: Value(definition.dedicatedWorktree),
      scheduleJson: Value(jsonEncode(definition.schedule.toJson())),
      timeZone: Value(definition.timeZone),
      missedRunPolicy: Value(definition.missedRunPolicy),
      runMode: Value(runMode),
      autoCompact: Value(autoCompact),
      approvalMode: Value(definition.approvalMode),
    );
  }

  ScheduledTaskRun runFromDto({required ScheduledTaskRunDto row}) => ScheduledTaskRun(
    id: row.id,
    scheduledFor: ScheduledTaskInstant(at: row.scheduledFor, offsetMinutes: row.scheduledForOffsetMinutes),
    outcome: switch (row.outcome) {
      ScheduledTaskRunOutcomeKind.started => ScheduledTaskRunOutcome.started(sessionId: row.sessionId, late: row.late),
      ScheduledTaskRunOutcomeKind.skipped => const ScheduledTaskRunOutcome.skipped(),
      ScheduledTaskRunOutcomeKind.missed => const ScheduledTaskRunOutcome.missed(),
      ScheduledTaskRunOutcomeKind.failed => ScheduledTaskRunOutcome.failed(
        reason: row.reason ?? TaskRunFailureReason.unknown,
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
    final (kind, sessionId, late, reason) = switch (outcome) {
      ScheduledTaskRunStarted(:final sessionId, :final late) => (
        ScheduledTaskRunOutcomeKind.started,
        sessionId,
        late,
        null,
      ),
      ScheduledTaskRunSkipped() => (ScheduledTaskRunOutcomeKind.skipped, null, false, null),
      ScheduledTaskRunMissed() => (ScheduledTaskRunOutcomeKind.missed, null, false, null),
      ScheduledTaskRunFailed(:final reason) => (ScheduledTaskRunOutcomeKind.failed, null, false, reason),
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
      late: late,
      userPromptedAt: null,
      compactRequestedAt: null,
    );
  }

  static DateTime? _instantOrNull(int? milliseconds) =>
      milliseconds == null ? null : DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
}
