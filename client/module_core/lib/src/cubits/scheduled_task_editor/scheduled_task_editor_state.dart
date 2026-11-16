import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

part "scheduled_task_editor_state.freezed.dart";

/// The repeat presets the When sheet offers.
enum ScheduledTaskRepeat() {
  once,
  daily,
  weekdays,
  weekly,
  everyHours,
}

/// Why the editor has no task to show.
enum ScheduledTaskEditorUnavailableReason() {
  /// The device zone or the task could not be loaded; a retry may work.
  loadFailed,

  /// The computer's bridge predates scheduled tasks.
  bridgeOutdated,

  /// The task was deleted, or it was a one-off task that already ran.
  taskGone,

  /// The task has parts from a newer app, so this one cannot send it back.
  newerApp,
}

@Freezed()
sealed class ScheduledTaskEditorState with _$ScheduledTaskEditorState {
  const factory loading() = ScheduledTaskEditorLoading;

  const factory unavailable({required ScheduledTaskEditorUnavailableReason reason}) = ScheduledTaskEditorUnavailable;

  /// The When and Each run choices. The composer holds the prompt and where
  /// the task runs.
  const factory ready({
    /// The task being edited; null while setting up a new one.
    required ScheduledTask? editing,
    required TaskSchedule schedule,

    /// Kept while the schedule is Once, which always runs when the computer
    /// is back, so switching back to a repeat finds the choice unchanged.
    required TaskMissedRunPolicy missedRunPolicy,
    required TaskRunMode runMode,
    required TaskApprovalMode approvalMode,

    /// The IANA zone the times are in: this device's for a new task, the
    /// task's own for an edit.
    required String timeZone,

    /// This device's IANA zone; null when the platform cannot report it.
    required String? deviceTimeZone,
    required ScheduledTaskEditorSave save,
  }) = ScheduledTaskEditorReady;
}

extension ScheduledTaskEditorReadyX on ScheduledTaskEditorReady {
  ScheduledTaskRepeat get repeat => switch (schedule) {
    TaskScheduleOnce() => ScheduledTaskRepeat.once,
    TaskScheduleDaily() => ScheduledTaskRepeat.daily,
    TaskScheduleWeekdays() => ScheduledTaskRepeat.weekdays,
    TaskScheduleWeekly() => ScheduledTaskRepeat.weekly,
    TaskScheduleEveryHours() => ScheduledTaskRepeat.everyHours,
    // The editor only opens tasks whose every part this app knows.
    TaskScheduleUnknown() => ScheduledTaskRepeat.daily,
  };

  /// A one-off task always runs when the computer is back, so it has no
  /// missed-run choice.
  bool get offersMissedRunChoice => schedule is! TaskScheduleOnce;
}

/// Where the last Save stands.
sealed class const ScheduledTaskEditorSave();

final class const ScheduledTaskEditorSaveIdle() extends ScheduledTaskEditorSave;

final class const ScheduledTaskEditorSaving() extends ScheduledTaskEditorSave;

/// The editor or the bridge turned the task down for [code]. Client-side
/// checks use the bridge's codes: a past one-off time, a weekly schedule with
/// no days, or an empty prompt.
final class const ScheduledTaskEditorRefused({required final ScheduledTaskErrorCode code})
    extends ScheduledTaskEditorSave;

/// The computer's bridge predates scheduled tasks.
final class const ScheduledTaskEditorSaveBridgeOutdated() extends ScheduledTaskEditorSave;

/// The request failed, so nothing is known to be saved.
final class const ScheduledTaskEditorSaveFailed() extends ScheduledTaskEditorSave;

final class const ScheduledTaskEditorSaved({required final ScheduledTask task}) extends ScheduledTaskEditorSave;
