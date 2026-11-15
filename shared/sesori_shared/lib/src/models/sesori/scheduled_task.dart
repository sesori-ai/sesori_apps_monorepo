import "package:freezed_annotation/freezed_annotation.dart";

import "command_info.dart";
import "send_prompt_request.dart";
import "session_variant.dart";

part "scheduled_task.freezed.dart";
part "scheduled_task.g.dart";

/// A task the bridge runs headlessly, once or on repeat.
///
/// The bridge owns everything outside [definition]: whether the task is
/// [enabled], when it runs next and what its latest run did.
@Freezed(fromJson: true, toJson: true)
sealed class ScheduledTask with _$ScheduledTask {
  const factory({
    required String id,
    required ScheduledTaskDefinition definition,

    /// Whether the task runs on its schedule. A paused task keeps its
    /// definition and can still be run now.
    required bool enabled,

    /// When the task runs next. Null while it is paused or has nothing left to
    /// run.
    required ScheduledTaskInstant? nextRunAt,

    /// The newest run row, including skipped, missed and failed ones. Null
    /// before the first run.
    required ScheduledTaskRun? lastRun,
  }) = _ScheduledTask;

  factory fromJson(Map<String, dynamic> json) => _$ScheduledTaskFromJson(json);
}

/// What the user sets up for a task: the prompt, where it runs, when, and how
/// each run behaves. Create and update requests carry it whole; editing changes
/// future runs only.
@Freezed(fromJson: true, toJson: true)
sealed class ScheduledTaskDefinition with _$ScheduledTaskDefinition {
  const factory({
    /// Shown on the Scheduled page, run marks and pushes. Defaults to the
    /// prompt's first line in the editor.
    required String name,
    required ScheduledTaskPrompt prompt,
    required String projectId,
    required String pluginId,
    required String? agent,
    required PromptModel? model,
    required SessionVariant? variant,
    required bool fastMode,

    /// Whether each new-session run gets its own worktree. A same-session task
    /// keeps the one its session started with.
    required bool dedicatedWorktree,
    required TaskSchedule schedule,

    /// IANA zone name, such as `Europe/Bucharest`. Every [schedule] time is a
    /// wall-clock time in this zone, whatever zone the bridge's computer uses.
    required String timeZone,

    /// What happens when the bridge was off or asleep at a recurring run's
    /// time. A one-off task always runs when the bridge is back.
    @JsonKey(unknownEnumValue: TaskMissedRunPolicy.unknown) required TaskMissedRunPolicy missedRunPolicy,
    required TaskRunMode runMode,
    @JsonKey(unknownEnumValue: TaskApprovalMode.unknown) required TaskApprovalMode approvalMode,
  }) = _ScheduledTaskDefinition;

  factory fromJson(Map<String, dynamic> json) => _$ScheduledTaskDefinitionFromJson(json);
}

/// What each run sends. Tasks take no attachments.
@Freezed(unionKey: "kind", fallbackUnion: "unknown", fromJson: true, toJson: true, copyWith: false)
sealed class ScheduledTaskPrompt with _$ScheduledTaskPrompt {
  const factory text({required String text}) = ScheduledTaskPromptText;

  /// A slash command as the command picker listed it, with optional argument
  /// text.
  const factory command({
    required String name,
    @JsonKey(unknownEnumValue: CommandSource.unknown) required CommandSource source,
    required String? arguments,
  }) = ScheduledTaskPromptCommand;

  /// A prompt kind from a newer peer. Such a task is shown read-only.
  const factory unknown() = ScheduledTaskPromptUnknown;

  factory fromJson(Map<String, dynamic> json) => _$ScheduledTaskPromptFromJson(json);
}

/// When a task runs. Times are wall-clock times in the task's zone.
@Freezed(unionKey: "kind", fallbackUnion: "unknown", fromJson: true, toJson: true, copyWith: false)
sealed class TaskSchedule with _$TaskSchedule {
  const factory once({required TaskLocalDateTime at}) = TaskScheduleOnce;
  const factory daily({required TaskTimeOfDay time}) = TaskScheduleDaily;

  /// Monday to Friday.
  const factory weekdays({required TaskTimeOfDay time}) = TaskScheduleWeekdays;

  /// The chosen days, at least one.
  const factory weekly({required Set<TaskWeekday> days, required TaskTimeOfDay time}) = TaskScheduleWeekly;

  /// Every [hours] real hours (1 to 12) from [start], so the interval stays
  /// exact across daylight-saving changes.
  const factory everyHours({required int hours, required TaskLocalDateTime start}) = TaskScheduleEveryHours;

  /// A schedule kind from a newer peer. Such a task is shown read-only ("Edit
  /// on a newer app") instead of failing to decode the list.
  const factory unknown() = TaskScheduleUnknown;

  factory fromJson(Map<String, dynamic> json) => _$TaskScheduleFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class TaskTimeOfDay with _$TaskTimeOfDay {
  /// [hour] is 0 to 23 and [minute] 0 to 59.
  const factory({required int hour, required int minute}) = _TaskTimeOfDay;

  factory fromJson(Map<String, dynamic> json) => _$TaskTimeOfDayFromJson(json);
}

/// A calendar date and time of day with no zone; the task's zone applies.
@Freezed(fromJson: true, toJson: true)
sealed class TaskLocalDateTime with _$TaskLocalDateTime {
  /// [month] is 1 to 12, [day] 1 to the month's length, [hour] 0 to 23 and
  /// [minute] 0 to 59.
  const factory({
    required int year,
    required int month,
    required int day,
    required int hour,
    required int minute,
  }) = _TaskLocalDateTime;

  factory fromJson(Map<String, dynamic> json) => _$TaskLocalDateTimeFromJson(json);
}

enum TaskWeekday({required final int isoWeekday}) {
  monday(isoWeekday: DateTime.monday),
  tuesday(isoWeekday: DateTime.tuesday),
  wednesday(isoWeekday: DateTime.wednesday),
  thursday(isoWeekday: DateTime.thursday),
  friday(isoWeekday: DateTime.friday),
  saturday(isoWeekday: DateTime.saturday),
  sunday(isoWeekday: DateTime.sunday),
}

enum TaskMissedRunPolicy() {
  /// Run once when the bridge is back, marked late. Missed times never pile up.
  runWhenBack,

  /// Record one missed run and wait for the next time.
  waitForNext,
  unknown,
}

/// How each run answers permission requests. Questions always wait for the
/// user.
enum TaskApprovalMode() {
  ask,
  approveAll,
  unknown,
}

/// Where each run's prompt goes.
@Freezed(unionKey: "kind", fallbackUnion: "unknown", fromJson: true, toJson: true, copyWith: false)
sealed class TaskRunMode with _$TaskRunMode {
  /// Every run starts its own session.
  const factory newSession() = TaskRunModeNewSession;

  /// Every run continues one session. The bridge owns which session that is;
  /// when it is archived or deleted, the next run starts a fresh one.
  const factory sameSession({required bool autoCompact}) = TaskRunModeSameSession;

  /// A run mode from a newer peer. Such a task is shown read-only.
  const factory unknown() = TaskRunModeUnknown;

  factory fromJson(Map<String, dynamic> json) => _$TaskRunModeFromJson(json);
}

/// A moment the app shows in the task's wall-clock time without a time-zone
/// database.
@Freezed(fromJson: true, toJson: true)
sealed class ScheduledTaskInstant with _$ScheduledTaskInstant {
  const factory({
    /// UTC Unix milliseconds.
    required int at,

    /// The task zone's UTC offset at [at], in minutes east of UTC.
    required int offsetMinutes,
  }) = _ScheduledTaskInstant;

  factory fromJson(Map<String, dynamic> json) => _$ScheduledTaskInstantFromJson(json);
}

/// One entry in a task's run history.
@Freezed(fromJson: true, toJson: true)
sealed class ScheduledTaskRun with _$ScheduledTaskRun {
  const factory({
    required String id,

    /// The occurrence this run was for, or when Run now was tapped. Its offset
    /// is frozen when the row is written, so a later zone edit keeps past rows.
    required ScheduledTaskInstant scheduledFor,
    required ScheduledTaskRunOutcome outcome,
  }) = _ScheduledTaskRun;

  factory fromJson(Map<String, dynamic> json) => _$ScheduledTaskRunFromJson(json);
}

@Freezed(unionKey: "kind", fallbackUnion: "unknown", fromJson: true, toJson: true, copyWith: false)
sealed class ScheduledTaskRunOutcome with _$ScheduledTaskRunOutcome {
  /// The run's prompt went out. [sessionId] is null once that session has been
  /// deleted. [late] means it ran after the grace period, such as when the
  /// bridge was off at its time.
  const factory started({required String? sessionId, required bool late}) = ScheduledTaskRunStarted;

  /// The previous run was still going, so this one did not start.
  const factory skipped() = ScheduledTaskRunSkipped;

  /// The bridge was off or asleep at the time and the task waits for the next
  /// one.
  const factory missed() = ScheduledTaskRunMissed;

  /// The run could not start. The task stays enabled and tries again next time.
  const factory failed({
    @JsonKey(unknownEnumValue: TaskRunFailureReason.unknown) required TaskRunFailureReason reason,
  }) = ScheduledTaskRunFailed;

  /// An outcome from a newer peer.
  const factory unknown() = ScheduledTaskRunOutcomeUnknown;

  factory fromJson(Map<String, dynamic> json) => _$ScheduledTaskRunOutcomeFromJson(json);
}

enum TaskRunFailureReason() {
  projectMissing,
  harnessUnavailable,

  /// The task's model is no longer offered. A run never swaps in another one.
  modelUnavailable,
  startFailed,
  unknown,
}

/// Marks a session that a task run started.
@Freezed(fromJson: true, toJson: true)
sealed class SessionScheduledTaskMark with _$SessionScheduledTaskMark {
  const factory({
    required String taskId,
    required String name,
    @JsonKey(unknownEnumValue: ScheduledTaskKind.unknown) required ScheduledTaskKind kind,
  }) = _SessionScheduledTaskMark;

  factory fromJson(Map<String, dynamic> json) => _$SessionScheduledTaskMarkFromJson(json);
}

enum ScheduledTaskKind() {
  /// Shown with a repeat mark.
  recurring,

  /// Shown with a clock mark.
  once,
  unknown,
}
