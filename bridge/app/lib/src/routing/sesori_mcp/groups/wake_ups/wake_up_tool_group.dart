import "package:sesori_shared/sesori_shared.dart" show TaskSchedule, TaskTimeOfDay;
import "package:sesori_tool_interface/sesori_tool_interface.dart";

import "../../../../foundation/sesori_tool_group_ids.dart";
import "../../../../repositories/models/session_wake_up.dart";
import "../../../../services/session_wake_up_description_builder.dart";
import "../../../../services/session_wake_up_service.dart";
import "../../models/sesori_mcp_tool_arguments.dart";
import "../in_app_tool_texts.dart";
import "wake_up_tool.dart";

/// `schedule_wakeup` and its list and cancel: prompts Sesori sends this
/// session later.
class WakeUpToolGroup({required final SessionWakeUpService _wakeUps}) implements SesoriToolGroup {
  static const SesoriToolArgumentParser _arguments = SesoriToolArgumentParser(
    nestedPlaces: {},
    kindFields: {
      "when": {
        "in": ["minutes"],
        "every": ["minutes"],
        "daily": ["time"],
        "weekdays": ["time"],
        "weekly": ["days", "time"],
      },
    },
  );

  /// Wake-ups read the same in results as in the notice they send.
  static const SessionWakeUpDescriptionBuilder _wakeUpWords = SessionWakeUpDescriptionBuilder();

  static final RegExp _clockTimePattern = RegExp(r"^([01]?\d|2[0-3]):([0-5]\d)$");

  @override
  SesoriToolGroupId get id => SesoriToolGroupIds.wakeUps;

  @override
  String get title => "Wake-ups";

  @override
  String get summary => "Agents can schedule a prompt back to their own session for later.";

  @override
  String get instructions =>
      "schedule_wakeup has Sesori send this session a prompt later, as a message; use it instead of a harness "
      "timer, because the user can see and cancel it.";

  @override
  List<SesoriToolDefinition> get tools => [for (final tool in WakeUpTool.values) tool.definition];

  @override
  Future<SesoriToolResult> call({
    required String tool,
    required SesoriToolCaller caller,
    required Map<String, Object?> arguments,
  }) async {
    switch (WakeUpTool.values.firstWhere((candidate) => candidate.wireName == tool)) {
      case WakeUpTool.scheduleWakeUp:
        final args = _arguments.parse(json: arguments, fromJson: ScheduleWakeUpArguments.fromJson);
        return _wakeUpScheduled(
          result: await _wakeUps.schedule(
            caller: caller,
            label: requiredToolText(value: args.label, field: "label"),
            prompt: requiredToolText(value: args.prompt, field: "prompt"),
            when: _wakeUpTime(when: args.when),
            timeZone: optionalToolText(value: args.timeZone),
            command: optionalToolText(value: args.command),
          ),
        );
      case WakeUpTool.listWakeUps:
        return switch (await _wakeUps.list(caller: caller)) {
          WakeUpList(:final wakeUps) => SesoriToolSuccess(text: _wakeUpList(wakeUps: wakeUps)),
          WakeUpListCallerGone() => const SesoriToolFailure(text: callerGoneText),
        };
      case WakeUpTool.cancelWakeUp:
        final args = _arguments.parse(json: arguments, fromJson: CancelWakeUpArguments.fromJson);
        final wakeUpId = args.wakeUpId;
        return switch (await _wakeUps.cancel(sessionId: caller.sessionId, wakeUpId: wakeUpId)) {
          WakeUpCancelResult.cancelled => SesoriToolSuccess(text: "Cancelled wake-up $wakeUpId."),
          WakeUpCancelResult.notFound => SesoriToolFailure(
            text: "This session has no wake-up $wakeUpId. Find ids with list_wakeups.",
          ),
          WakeUpCancelResult.callerGone => const SesoriToolFailure(text: callerGoneText),
        };
    }
  }

  SesoriToolResult _wakeUpScheduled({required WakeUpScheduleResult result}) {
    return switch (result) {
      WakeUpScheduled(:final wakeUp) => SesoriToolSuccess(text: _wakeUpSet(wakeUp: wakeUp)),
      WakeUpAwaitingApproval() => const SesoriToolSuccess(
        text:
            "Sent to the user for approval, because it runs a command. Nothing is set unless they allow it. "
            "$answerFollowsText End your turn now; don't wait or poll.",
      ),
      WakeUpRefused(:final reason) => SesoriToolFailure(
        text: switch (reason) {
          WakeUpRefusal.callerGone => callerGoneText,
          WakeUpRefusal.labelTooLong => "label is longer than ${SessionWakeUpService.maxLabelLength} characters.",
          WakeUpRefusal.minutesOutOfRange => "when.minutes must be 1 to ${SessionWakeUpService.maxMinutes} (a week).",
          WakeUpRefusal.noDays => "when.days needs at least one day.",
          WakeUpRefusal.unknownTimeZone => "Unknown time_zone; use an IANA name such as Europe/Bucharest.",
          WakeUpRefusal.timeZoneNeeded =>
            "The bridge cannot tell this computer's time zone; pass time_zone, such as Europe/Bucharest.",
        },
      ),
    };
  }

  String _wakeUpSet({required StoredSessionWakeUp wakeUp}) {
    final repeats = _wakeUpWords.repeats(schedule: wakeUp.schedule);
    return [
      "Wake-up ${wakeUp.id} is set for ${_wakeUpWords.instant(at: wakeUp.nextDueAt)}.",
      "Sesori sends this session its prompt then, once the session's turn has ended.",
      if (wakeUp.command != null) "Right before, it runs the command and adds its result to the prompt.",
      if (repeats != null) "It repeats $repeats until you call cancel_wakeup.",
      "End your turn now; don't wait or poll.",
    ].join(" ");
  }

  String _wakeUpList({required List<StoredSessionWakeUp> wakeUps}) {
    if (wakeUps.isEmpty) return "This session has no wake-ups.";
    return [
      for (final wakeUp in wakeUps)
        [
          "- ${wakeUp.label} (id: ${wakeUp.id})",
          "  next: ${_wakeUpWords.instant(at: wakeUp.nextDueAt)}",
          "  repeats: ${_wakeUpWords.repeats(schedule: wakeUp.schedule) ?? "no"}",
          if (wakeUp.command != null) "  runs a command first",
        ].join("\n"),
    ].join("\n");
  }

  WakeUpRequestedTime _wakeUpTime({required WakeUpWhenArgument when}) {
    return switch (when) {
      WakeUpWhenAfterArgument(:final minutes) => WakeUpInMinutes(minutes: minutes),
      WakeUpWhenEveryArgument(:final minutes) => WakeUpEveryMinutes(minutes: minutes),
      WakeUpWhenDailyArgument(:final time) => WakeUpOnSchedule(
        schedule: TaskSchedule.daily(time: _clockTime(text: time)),
      ),
      WakeUpWhenWeekdaysArgument(:final time) => WakeUpOnSchedule(
        schedule: TaskSchedule.weekdays(time: _clockTime(text: time)),
      ),
      WakeUpWhenWeeklyArgument(:final days, :final time) => WakeUpOnSchedule(
        schedule: TaskSchedule.weekly(
          days: days,
          time: _clockTime(text: time),
        ),
      ),
    };
  }

  /// [text] as `HH:MM`, 24-hour.
  TaskTimeOfDay _clockTime({required String text}) {
    return switch (_clockTimePattern.firstMatch(text.trim())?.groups([1, 2])) {
      [final String hour, final String minute] => TaskTimeOfDay(hour: int.parse(hour), minute: int.parse(minute)),
      _ => throw const InvalidToolArguments(reason: "when.time must be HH:MM, from 00:00 to 23:59."),
    };
  }
}
