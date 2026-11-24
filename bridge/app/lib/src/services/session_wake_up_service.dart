import "dart:async";

import "package:clock/clock.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginOperationException;
import "package:sesori_shared/sesori_shared.dart" show TaskSchedule, TaskScheduleWeekly;

import "../repositories/models/sesori_mcp_caller.dart";
import "../repositories/models/session_operation.dart";
import "../repositories/models/session_wake_up.dart";
import "../repositories/session_repository.dart";
import "../repositories/session_wake_up_repository.dart";
import "scheduled_task_occurrence_calculator.dart";
import "session_mutation_dispatcher.dart";
import "session_notice_service.dart";
import "session_wake_up_description_builder.dart";

/// The wake-ups agents set through Sesori's MCP server: a prompt Sesori sends
/// the caller's root session later, once or on repeat, until it fires or is
/// cancelled. A wake-up needs no approval: it reaches only the session that
/// set it, under that session's own approval mode.
///
/// A wake-up waits for the session's turn to end on every harness, so it
/// never cuts into one. Of an occurrence that a restart or crash interrupts,
/// the rule is the tasks' "lose, never duplicate": a one-shot is removed by
/// the claim right before its send, and a repeating one moves to its next
/// time before it is sent. Logs carry ids, never labels or prompts.
///
/// Every change to a session's wake-ups is announced on
/// [SessionMutationDispatcher.armingUpdated], so the app's marks follow it.
class SessionWakeUpService({
  required final SessionWakeUpRepository _wakeUps,
  required final SessionRepository _sessions,
  required final ScheduledTaskOccurrenceCalculator _calculator,
  required final SessionNoticeService _notices,
  required final SessionWakeUpDescriptionBuilder _descriptions,
  required final SessionMutationDispatcher _mutations,

  /// The IANA name of the bridge computer's zone, or null when it cannot be
  /// told. Read at each request, so a changed zone applies to the next one.
  required final String? Function() _localTimeZone,
  required final Clock _clock,
}) {
  static const int maxLabelLength = 100;

  /// A week.
  static const int maxMinutes = 7 * 24 * 60;

  /// Wake-ups being delivered. In memory only: a restart empties it, and a
  /// one-shot still waiting then fires again.
  final Set<String> _inFlight = {};

  /// Stores a wake-up for [caller]'s root session. [timeZone] applies to a
  /// calendar schedule; null means the bridge computer's.
  Future<WakeUpScheduleResult> schedule({
    required SesoriMcpCaller caller,
    required String label,
    required String prompt,
    required WakeUpRequestedTime when,
    required String? timeZone,
  }) async {
    final rootSessionId = await _rootOf(sessionId: caller.sessionId);
    if (rootSessionId == null) return const WakeUpRefused(reason: WakeUpRefusal.callerGone);
    // The label is one line on the user's screen.
    final oneLine = label.replaceAll(RegExp(r"\s+"), " ").trim();
    if (oneLine.length > maxLabelLength) return const WakeUpRefused(reason: WakeUpRefusal.labelTooLong);

    final now = _clock.now().toUtc();
    final WakeUpSchedule schedule;
    final DateTime dueAt;
    switch (when) {
      case WakeUpInMinutes(:final minutes) || WakeUpEveryMinutes(:final minutes)
          when minutes < 1 || minutes > maxMinutes:
        return const WakeUpRefused(reason: WakeUpRefusal.minutesOutOfRange);
      case WakeUpInMinutes(:final minutes):
        schedule = const WakeUpSchedule.once();
        dueAt = now.add(Duration(minutes: minutes));
      case WakeUpEveryMinutes(:final minutes):
        schedule = WakeUpSchedule.every(minutes: minutes);
        dueAt = now.add(Duration(minutes: minutes));
      case WakeUpOnSchedule(schedule: TaskScheduleWeekly(:final days)) when days.isEmpty:
        return const WakeUpRefused(reason: WakeUpRefusal.noDays);
      case WakeUpOnSchedule(schedule: final calendar):
        final zone = timeZone ?? _localTimeZone();
        if (zone == null) return const WakeUpRefused(reason: WakeUpRefusal.timeZoneNeeded);
        if (!_calculator.isKnownTimeZone(timeZone: zone)) {
          return WakeUpRefused(
            reason: timeZone == null ? WakeUpRefusal.timeZoneNeeded : WakeUpRefusal.unknownTimeZone,
          );
        }
        final first = _calculator.firstDueAt(schedule: calendar, timeZone: zone, now: now);
        if (first == null) return const WakeUpRefused(reason: WakeUpRefusal.noDays);
        schedule = WakeUpSchedule.calendar(schedule: calendar, timeZone: zone);
        dueAt = first;
    }

    final wakeUp = await _wakeUps.add(
      sessionId: rootSessionId,
      label: oneLine,
      prompt: prompt,
      schedule: schedule,
      nextDueAt: dueAt,
      createdAt: now,
    );
    Log.i("Session ${caller.sessionId} set wake-up ${wakeUp.id} for session $rootSessionId");
    await _mutations.armingUpdated(sessionId: rootSessionId);
    return WakeUpScheduled(wakeUp: wakeUp);
  }

  /// The wake-ups of [caller]'s root session, soonest first.
  Future<WakeUpListLookup> list({required SesoriMcpCaller caller}) async {
    final rootSessionId = await _rootOf(sessionId: caller.sessionId);
    if (rootSessionId == null) return const WakeUpListCallerGone();
    return WakeUpList(wakeUps: await _wakeUps.forSession(sessionId: rootSessionId));
  }

  /// Cancels [wakeUpId] when it belongs to [sessionId]'s root session, for
  /// the agent in [sessionId] or the user in the app. A delivery still waiting
  /// for the session's turn to end sends nothing.
  Future<WakeUpCancelResult> cancel({required String sessionId, required String wakeUpId}) async {
    final rootSessionId = await _rootOf(sessionId: sessionId);
    if (rootSessionId == null) return WakeUpCancelResult.callerGone;
    if (!await _wakeUps.removeFromSession(id: wakeUpId, sessionId: rootSessionId)) return WakeUpCancelResult.notFound;
    Log.i("Cancelled wake-up $wakeUpId of session $rootSessionId, asked from session $sessionId");
    await _mutations.armingUpdated(sessionId: rootSessionId);
    return WakeUpCancelResult.cancelled;
  }

  /// Fires every wake-up whose time has come. A repeating one first moves to
  /// its first time after now, so missed times never pile up; one whose
  /// previous occurrence is still being delivered skips this one.
  Future<void> runDue() async {
    final now = _clock.now().toUtc();
    for (final wakeUp in await _wakeUps.due(now: now)) {
      try {
        final next = _nextAfter(wakeUp: wakeUp, now: now);
        if (next != null) {
          await _wakeUps.setNextDueAt(id: wakeUp.id, nextDueAt: next);
          await _mutations.armingUpdated(sessionId: wakeUp.sessionId);
        }
        if (!_inFlight.add(wakeUp.id)) {
          if (next != null) Log.i("Skipped an occurrence of wake-up ${wakeUp.id}: the previous one is still waiting");
          continue;
        }
        unawaited(_fire(wakeUp: wakeUp, firedAt: now));
      } on Object catch (error, stackTrace) {
        Log.w("Could not fire wake-up ${wakeUp.id}", error, stackTrace);
      }
    }
  }

  Future<void> _fire({required StoredSessionWakeUp wakeUp, required DateTime firedAt}) async {
    try {
      final outcome = await _notices.deliver(
        sessionId: wakeUp.sessionId,
        notice: _descriptions.notice(wakeUp: wakeUp, firedAt: firedAt),
        timing: SessionNoticeTiming.afterTurn,
        claim: () => _claim(wakeUp: wakeUp),
      );
      switch (outcome) {
        case SessionNoticeOutcome.sent:
          Log.i("Sent wake-up ${wakeUp.id} to session ${wakeUp.sessionId}");
        case SessionNoticeOutcome.skippedInactive:
          // Archiving ends a wake-up, repeating ones included.
          await _wakeUps.remove(id: wakeUp.id);
          Log.i("Removed wake-up ${wakeUp.id}: session ${wakeUp.sessionId} is archived or deleted");
        case SessionNoticeOutcome.claimLost:
          Log.i("Wake-up ${wakeUp.id} was cancelled before it was sent");
        case SessionNoticeOutcome.dropped:
          // The notice service logged why. A one-shot dropped after its claim
          // is gone; one dropped before it, and a repeating one, fire again.
          break;
      }
      await _mutations.armingUpdated(sessionId: wakeUp.sessionId);
    } on Object catch (error, stackTrace) {
      Log.w("Wake-up ${wakeUp.id} failed after its delivery", error, stackTrace);
    } finally {
      _inFlight.remove(wakeUp.id);
    }
  }

  /// Runs on the session's lane right before the send: a one-shot removes
  /// itself, and a repeating one checks that it was not cancelled.
  Future<bool> _claim({required StoredSessionWakeUp wakeUp}) {
    return switch (wakeUp.schedule) {
      WakeUpOnce() => _wakeUps.remove(id: wakeUp.id),
      WakeUpEvery() || WakeUpCalendar() => _wakeUps.exists(id: wakeUp.id),
    };
  }

  /// A repeating wake-up's first time strictly after [now]; null for a
  /// one-shot.
  DateTime? _nextAfter({required StoredSessionWakeUp wakeUp, required DateTime now}) {
    switch (wakeUp.schedule) {
      case WakeUpOnce():
        return null;
      case WakeUpEvery(:final minutes):
        final interval = Duration(minutes: minutes);
        final elapsed = now.difference(wakeUp.nextDueAt).inMilliseconds ~/ interval.inMilliseconds;
        return wakeUp.nextDueAt.add(interval * (elapsed + 1));
      case WakeUpCalendar(:final schedule, :final timeZone):
        final next = _calculator.nextDueAfterRun(schedule: schedule, timeZone: timeZone, now: now);
        // Scheduling refuses a calendar that never falls due.
        if (next == null) throw StateError("wake-up ${wakeUp.id} has no next time");
        return next;
    }
  }

  Future<String?> _rootOf({required String sessionId}) async {
    try {
      return (await _sessions.resolveSessionFamily(
        sessionId: sessionId,
        operation: SessionOperation.manageWakeUps,
      )).rootSessionId;
    } on PluginOperationException {
      return null;
    }
  }
}

/// When a requested wake-up fires.
sealed class const WakeUpRequestedTime();

/// Once, [minutes] from now.
final class const WakeUpInMinutes({required final int minutes}) extends WakeUpRequestedTime;

/// Every [minutes], the first [minutes] from now.
final class const WakeUpEveryMinutes({required final int minutes}) extends WakeUpRequestedTime;

/// On a daily, weekdays or weekly [schedule].
final class const WakeUpOnSchedule({required final TaskSchedule schedule}) extends WakeUpRequestedTime;

sealed class const WakeUpScheduleResult();

final class const WakeUpScheduled({required final StoredSessionWakeUp wakeUp}) extends WakeUpScheduleResult;

final class const WakeUpRefused({required final WakeUpRefusal reason}) extends WakeUpScheduleResult;

enum WakeUpRefusal() {
  /// The caller's session row is gone.
  callerGone,
  labelTooLong,
  minutesOutOfRange,

  /// A weekly schedule without days.
  noDays,
  unknownTimeZone,

  /// A calendar schedule without a time zone, on a computer whose zone the
  /// bridge cannot tell.
  timeZoneNeeded,
}

sealed class const WakeUpListLookup();

final class const WakeUpList({required final List<StoredSessionWakeUp> wakeUps}) extends WakeUpListLookup;

final class const WakeUpListCallerGone() extends WakeUpListLookup;

enum WakeUpCancelResult() {
  cancelled,

  /// No wake-up of the caller's root session has that id.
  notFound,
  callerGone,
}
