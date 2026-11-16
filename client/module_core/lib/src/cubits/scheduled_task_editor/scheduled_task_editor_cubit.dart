import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../foundation/models/product_analytics/product_analytics_event.dart";
import "../../foundation/platform/device_time_zone_source.dart";
import "../../logging/logging.dart";
import "../../repositories/models/analytics_delivery_result.dart";
import "../../repositories/models/scheduled_task_editability.dart";
import "../../repositories/models/scheduled_task_result.dart";
import "../../repositories/scheduled_task_repository.dart";
import "../../services/bridge_settings_service.dart";
import "../../services/product_analytics_service.dart";
import "../new_session/new_session_purpose.dart";
import "../scheduled_tasks/scheduled_task_refresh.dart";
import "scheduled_task_editor_state.dart";

/// The New task and Edit task screens' When and Each run choices, and Save.
///
/// The composer beside it holds the prompt and where the task runs; the screen
/// hands its saved [TaskComposerSubmission] to [save], which sends the whole
/// definition to the bridge.
class ScheduledTaskEditorCubit({
  required final ScheduledTaskRepository _repository,
  required final DeviceTimeZoneSource _timeZoneSource,
  required final BridgeSettingsService _bridgeSettingsService,
  required final ProductAnalyticsService _productAnalyticsService,

  /// The device's clock, for the next free time and the past check.
  required final DateTime Function() _now,

  /// The task to edit; null sets up a new one.
  required final String? taskId,
}) extends Cubit<ScheduledTaskEditorState> {
  this : super(const ScheduledTaskEditorState.loading()) {
    unawaited(_load());
  }

  /// A new task runs every day at this time until the user picks another.
  static const TaskTimeOfDay defaultTime = TaskTimeOfDay(hour: 9, minute: 0);

  /// The interval Every few hours starts at.
  static const int defaultHours = 2;

  /// The shortest and longest Every few hours intervals the computer accepts.
  static const int minHours = 1;
  static const int maxHours = 12;

  /// The longest name taken from a prompt's first line.
  static const int _maxNameLength = 80;

  /// Shows the loading state again and reloads, after a failed load.
  Future<void> retry() {
    emit(const ScheduledTaskEditorState.loading());
    return _load();
  }

  /// Switches the repeat preset, keeping the time of day. A one-off or
  /// interval start lands on the next time that clock time comes round,
  /// Weekly starts on today, and Every few hours on [defaultHours].
  void selectRepeat({required ScheduledTaskRepeat repeat}) {
    final ready = _ready;
    if (ready == null || ready.repeat == repeat) return;
    final time = _timeOf(schedule: ready.schedule);
    _update(
      ready: ready,
      schedule: switch (repeat) {
        ScheduledTaskRepeat.once => TaskSchedule.once(at: _nextOccurrence(time: time)),
        ScheduledTaskRepeat.daily => TaskSchedule.daily(time: time),
        ScheduledTaskRepeat.weekdays => TaskSchedule.weekdays(time: time),
        ScheduledTaskRepeat.weekly => TaskSchedule.weekly(days: {_today()}, time: time),
        ScheduledTaskRepeat.everyHours => TaskSchedule.everyHours(
          hours: defaultHours,
          start: _nextOccurrence(time: time),
        ),
      },
    );
  }

  /// Sets the time of day of a daily, weekday or weekly schedule.
  void setTime({required TaskTimeOfDay time}) {
    final ready = _ready;
    if (ready == null) return;
    _update(
      ready: ready,
      schedule: switch (ready.schedule) {
        TaskScheduleDaily() => TaskSchedule.daily(time: time),
        TaskScheduleWeekdays() => TaskSchedule.weekdays(time: time),
        TaskScheduleWeekly(:final days) => TaskSchedule.weekly(days: days, time: time),
        final other => other,
      },
    );
  }

  /// Sets a one-off task's date and time, or when an interval starts.
  void setDateTime({required TaskLocalDateTime at}) {
    final ready = _ready;
    if (ready == null) return;
    _update(
      ready: ready,
      schedule: switch (ready.schedule) {
        TaskScheduleOnce() => TaskSchedule.once(at: at),
        TaskScheduleEveryHours(:final hours) => TaskSchedule.everyHours(hours: hours, start: at),
        final other => other,
      },
    );
  }

  /// Adds or removes [day] from a weekly schedule. Removing the last day is
  /// allowed; Save then asks for one.
  void toggleWeekday({required TaskWeekday day}) {
    final ready = _ready;
    if (ready == null) return;
    if (ready.schedule case TaskScheduleWeekly(:final days, :final time)) {
      final next = days.contains(day) ? ({...days}..remove(day)) : {...days, day};
      _update(
        ready: ready,
        schedule: TaskSchedule.weekly(days: next, time: time),
      );
    }
  }

  /// Sets the Every few hours interval, held to 1 to 12 hours.
  void setHours({required int hours}) {
    final ready = _ready;
    if (ready == null) return;
    if (ready.schedule case TaskScheduleEveryHours(:final start)) {
      _update(
        ready: ready,
        schedule: TaskSchedule.everyHours(hours: hours.clamp(minHours, maxHours), start: start),
      );
    }
  }

  void setMissedRunPolicy({required TaskMissedRunPolicy policy}) {
    final ready = _ready;
    if (ready == null) return;
    _emitReady(ready: ready.copyWith(missedRunPolicy: policy));
  }

  /// Whether each run continues one session rather than starting its own.
  /// Continuing turns auto-compact on, or as the edited task had it; Save
  /// turns it off for a harness that cannot compact on request.
  void setSameSession({required bool sameSession}) {
    final ready = _ready;
    if (ready == null || (ready.runMode is TaskRunModeSameSession) == sameSession) return;
    _emitReady(
      ready: ready.copyWith(
        runMode: sameSession
            ? TaskRunMode.sameSession(
                autoCompact: switch (ready.editing?.definition.runMode) {
                  TaskRunModeSameSession(:final autoCompact) => autoCompact,
                  _ => true,
                },
              )
            : const TaskRunMode.newSession(),
      ),
    );
  }

  /// Whether a same-session task compacts its session between runs.
  void setAutoCompact({required bool autoCompact}) {
    final ready = _ready;
    if (ready == null || ready.runMode is! TaskRunModeSameSession) return;
    _emitReady(
      ready: ready.copyWith(runMode: TaskRunMode.sameSession(autoCompact: autoCompact)),
    );
  }

  void setApprovalMode({required TaskApprovalMode mode}) {
    final ready = _ready;
    if (ready == null) return;
    _emitReady(ready: ready.copyWith(approvalMode: mode));
  }

  /// Checks the task and sends it to the bridge with what the composer held
  /// at Save. A refusal shows on the editor, which stays editable.
  Future<void> save({required TaskComposerSubmission submission}) async {
    final ready = _ready;
    if (ready == null || ready.save is ScheduledTaskEditorSaving) return;
    final prompt = _promptOf(submission: submission);
    if (_problemOf(ready: ready, prompt: prompt) case final code?) {
      emit(ready.copyWith(save: ScheduledTaskEditorRefused(code: code)));
      return;
    }
    final editing = ready.editing;
    final definition = ScheduledTaskDefinition(
      name: _nameFor(editing: editing, prompt: prompt),
      prompt: prompt,
      projectId: submission.project.id,
      pluginId: submission.pluginId,
      agent: submission.agent,
      model: submission.model,
      variant: submission.variant,
      fastMode: submission.fastMode,
      dedicatedWorktree: submission.dedicatedWorktree,
      schedule: ready.schedule,
      timeZone: ready.timeZone,
      missedRunPolicy: ready.missedRunPolicy,
      runMode: switch (ready.runMode) {
        // The switch stays as chosen, so moving back to a harness that can
        // compact finds it unchanged; only what is saved follows the harness.
        TaskRunModeSameSession(:final autoCompact) => TaskRunMode.sameSession(
          autoCompact: autoCompact && submission.compactsOnRequest,
        ),
        final other => other,
      },
      approvalMode: ready.approvalMode,
    );
    emit(ready.copyWith(save: const ScheduledTaskEditorSaving()));
    final result = editing == null
        ? await _repository.create(definition: definition)
        : await _repository.update(taskId: editing.id, definition: definition);
    logScheduledTaskFailure(message: "Failed to save a scheduled task", result: result);
    // Logged even when the screen has gone meanwhile: the task is saved.
    if (result is ScheduledTaskSuccess) {
      _logSaved(
        definition: definition,
        action: editing == null ? AnalyticsScheduledTaskAction.created : AnalyticsScheduledTaskAction.edited,
      );
    }
    if (isClosed) return;
    final latest = _ready;
    if (latest == null) return;
    emit(
      latest.copyWith(
        save: switch (result) {
          ScheduledTaskSuccess(:final value) => ScheduledTaskEditorSaved(task: value),
          ScheduledTaskRefused(:final code) => ScheduledTaskEditorRefused(code: code),
          ScheduledTaskBridgeOutdated() => const ScheduledTaskEditorSaveBridgeOutdated(),
          ScheduledTaskFailure() => const ScheduledTaskEditorSaveFailed(),
        },
      ),
    );
  }

  ScheduledTaskEditorReady? get _ready => switch (state) {
    final ScheduledTaskEditorReady ready => ready,
    ScheduledTaskEditorLoading() || ScheduledTaskEditorUnavailable() => null,
  };

  Future<void> _load() async {
    final taskId = this.taskId;
    final next = taskId == null ? await _newTask() : await _editedTask(taskId: taskId);
    if (!isClosed) emit(next);
  }

  /// A new task's defaults: every day at 09:00 in this device's zone, run
  /// when back, a new session each run, and approvals as new sessions on this
  /// computer get them.
  Future<ScheduledTaskEditorState> _newTask() async {
    final String timeZone;
    try {
      timeZone = await _timeZoneSource.currentZoneName();
    } on Object catch (error, stackTrace) {
      logw("Could not read the device time zone for a new scheduled task", error, stackTrace);
      return const ScheduledTaskEditorState.unavailable(reason: ScheduledTaskEditorUnavailableReason.loadFailed);
    }
    return ScheduledTaskEditorState.ready(
      editing: null,
      schedule: const TaskSchedule.daily(time: defaultTime),
      missedRunPolicy: TaskMissedRunPolicy.runWhenBack,
      runMode: const TaskRunMode.newSession(),
      approvalMode: _bridgeSettingsService.yoloSettings.value.enabled
          ? TaskApprovalMode.approveAll
          : TaskApprovalMode.ask,
      timeZone: timeZone,
      save: const ScheduledTaskEditorSaveIdle(),
    );
  }

  Future<ScheduledTaskEditorState> _editedTask({required String taskId}) async {
    final result = await _repository.listTasks();
    logScheduledTaskFailure(message: "Failed to load scheduled task $taskId to edit", result: result);
    return switch (result) {
      ScheduledTaskSuccess(:final value) => switch (value.where((task) => task.id == taskId).firstOrNull) {
        null => const ScheduledTaskEditorState.unavailable(reason: ScheduledTaskEditorUnavailableReason.taskGone),
        final task when !task.definition.isEditableHere => const ScheduledTaskEditorState.unavailable(
          reason: ScheduledTaskEditorUnavailableReason.newerApp,
        ),
        final task => ScheduledTaskEditorState.ready(
          editing: task,
          schedule: task.definition.schedule,
          missedRunPolicy: task.definition.missedRunPolicy,
          runMode: task.definition.runMode,
          approvalMode: task.definition.approvalMode,
          timeZone: task.definition.timeZone,
          save: const ScheduledTaskEditorSaveIdle(),
        ),
      },
      ScheduledTaskBridgeOutdated() => const ScheduledTaskEditorState.unavailable(
        reason: ScheduledTaskEditorUnavailableReason.bridgeOutdated,
      ),
      ScheduledTaskRefused() || ScheduledTaskFailure() => const ScheduledTaskEditorState.unavailable(
        reason: ScheduledTaskEditorUnavailableReason.loadFailed,
      ),
    };
  }

  void _update({required ScheduledTaskEditorReady ready, required TaskSchedule schedule}) =>
      _emitReady(ready: ready.copyWith(schedule: schedule));

  /// Emits a changed choice, which also clears a refusal shown for the last
  /// Save.
  void _emitReady({required ScheduledTaskEditorReady ready}) => emit(
    switch (ready.save) {
      ScheduledTaskEditorSaving() || ScheduledTaskEditorSaved() => ready,
      _ => ready.copyWith(save: const ScheduledTaskEditorSaveIdle()),
    },
  );

  /// Why the bridge would refuse the task, checked here first so the editor
  /// can say so without a round trip.
  ScheduledTaskErrorCode? _problemOf({required ScheduledTaskEditorReady ready, required ScheduledTaskPrompt prompt}) {
    if (prompt case ScheduledTaskPromptText(:final text) when text.trim().isEmpty) {
      return ScheduledTaskErrorCode.emptyPrompt;
    }
    return switch (ready.schedule) {
      TaskScheduleWeekly(:final days) when days.isEmpty => ScheduledTaskErrorCode.invalidSchedule,
      // A new task's times are in this device's zone, so its clock judges
      // them; an edited task's zone may be another, which the bridge judges.
      TaskScheduleOnce(:final at) when ready.editing == null && !_localDateTime(at: at).isAfter(_now()) =>
        ScheduledTaskErrorCode.onceTimeInPast,
      _ => null,
    };
  }

  ScheduledTaskPrompt _promptOf({required TaskComposerSubmission submission}) => switch (submission.command) {
    CommandInfo(:final name, :final source) => ScheduledTaskPrompt.command(
      name: name,
      // A picker entry without a source is a plain slash command.
      source: source ?? CommandSource.command,
      arguments: submission.prompt.isEmpty ? null : submission.prompt,
    ),
    null => ScheduledTaskPrompt.text(text: submission.prompt),
  };

  /// A new task is named after its prompt's first line. An edit keeps a name
  /// the user chose, and follows the prompt when the name was the prompt's.
  String _nameFor({required ScheduledTask? editing, required ScheduledTaskPrompt prompt}) {
    final named = _nameOf(prompt: prompt);
    if (editing == null) return named;
    final previous = editing.definition;
    return previous.name == _nameOf(prompt: previous.prompt) ? named : previous.name;
  }

  static String _nameOf({required ScheduledTaskPrompt prompt}) {
    final text = switch (prompt) {
      ScheduledTaskPromptText(:final text) => text,
      ScheduledTaskPromptCommand(:final name, arguments: null) => "/$name",
      ScheduledTaskPromptCommand(:final name, :final arguments?) => "/$name $arguments",
      ScheduledTaskPromptUnknown() => "",
    };
    final firstLine = text.trim().split("\n").first.trim();
    return firstLine.length <= _maxNameLength ? firstLine : "${firstLine.substring(0, _maxNameLength).trimRight()}…";
  }

  void _logSaved({required ScheduledTaskDefinition definition, required AnalyticsScheduledTaskAction action}) {
    final event = ScheduledTaskSavedEvent.of(action: action, definition: definition);
    if (event == null) return;
    unawaited(
      _productAnalyticsService
          .logEvent(event: event, occurredAtUtc: DateTime.now().toUtc())
          .then<void>((result) {
            if (result == AnalyticsDeliveryResult.failed && _productAnalyticsService.state.isActive) {
              logw("Failed to deliver scheduled task analytics event");
            }
          })
          .catchError((Object error, StackTrace stackTrace) {
            logw("Failed to deliver scheduled task analytics event", error, stackTrace);
          }),
    );
  }

  static TaskTimeOfDay _timeOf({required TaskSchedule schedule}) => switch (schedule) {
    TaskScheduleOnce(:final at) || TaskScheduleEveryHours(start: final at) => TaskTimeOfDay(
      hour: at.hour,
      minute: at.minute,
    ),
    TaskScheduleDaily(:final time) || TaskScheduleWeekdays(:final time) || TaskScheduleWeekly(:final time) => time,
    TaskScheduleUnknown() => defaultTime,
  };

  /// The wall clock in the editor's zone now. A new task is in this device's
  /// zone. An edited task's zone may be another: its next or last run's
  /// offset, as the bridge reported it, converts this device's clock.
  // ponytail: a task that never ran and has no next run falls back to this
  // device's clock, and a DST change since the reported run can be an hour
  // off; the bridge would need to send the zone's current offset to fix that.
  DateTime get zoneNow {
    final now = _now();
    final known = switch (_ready?.editing) {
      final task? => task.nextRunAt ?? task.lastRun?.scheduledFor,
      null => null,
    };
    if (known == null) return now;
    final wall = now.toUtc().add(Duration(minutes: known.offsetMinutes));
    return DateTime(wall.year, wall.month, wall.day, wall.hour, wall.minute, wall.second);
  }

  /// The next time [time] comes round in the editor's zone: today when it is
  /// still ahead, else tomorrow.
  TaskLocalDateTime _nextOccurrence({required TaskTimeOfDay time}) {
    final now = zoneNow;
    final today = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    final next = today.isAfter(now) ? today : DateTime(now.year, now.month, now.day + 1, time.hour, time.minute);
    return TaskLocalDateTime(year: next.year, month: next.month, day: next.day, hour: next.hour, minute: next.minute);
  }

  TaskWeekday _today() => TaskWeekday.values.firstWhere((day) => day.isoWeekday == zoneNow.weekday);

  static DateTime _localDateTime({required TaskLocalDateTime at}) =>
      DateTime(at.year, at.month, at.day, at.hour, at.minute);
}
