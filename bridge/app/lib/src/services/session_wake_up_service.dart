import "dart:async";

import "package:clock/clock.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginOperationException;
import "package:sesori_shared/sesori_shared.dart" show PermissionReply, TaskScheduleWeekly;
import "package:sesori_tool_interface/sesori_tool_interface.dart" show SesoriToolCaller;

import "../repositories/agent_approval_repository.dart";
import "../repositories/models/agent_approval_change.dart";
import "../repositories/models/session_notice.dart";
import "../repositories/models/session_operation.dart";
import "../repositories/models/session_wake_up.dart";
import "../repositories/models/stored_session.dart";
import "../repositories/session_repository.dart";
import "../repositories/session_wake_up_repository.dart";
import "permission_auto_approval_service.dart";
import "scheduled_command_service.dart";
import "scheduled_task_occurrence_calculator.dart";
import "session_mutation_dispatcher.dart";
import "session_notice_service.dart";
import "session_wake_up_description_builder.dart";
import "wake_up_command_description_builder.dart";

/// The wake-ups agents set through Sesori's MCP server: a prompt Sesori sends
/// the caller's root session later, once or on repeat, until it fires or is
/// cancelled. A wake-up needs no approval: it reaches only the session that
/// set it, under that session's own approval mode.
///
/// A wake-up may also run a shell command right before its prompt is sent,
/// and that does need approval: the user's Allow, unless the session approves
/// everything when it is set. A command set that way asks at its time once
/// the session no longer approves everything, so it never outlives the mode
/// that let it through.
///
/// A wake-up waits for the session's turn to end on every harness, so it
/// never cuts into one. Of an occurrence that a restart or crash interrupts,
/// the rule is the tasks' "lose, never duplicate": a one-shot is removed by
/// the claim right before its send, or before its command runs, and a
/// repeating one moves to its next time before either. Logs carry ids, never
/// labels, prompts or commands.
///
/// Every change to a session's wake-ups is announced on
/// [SessionMutationDispatcher.armingUpdated], so the app's marks follow it.
class SessionWakeUpService({
  required final SessionWakeUpRepository _wakeUps,
  required final SessionRepository _sessions,
  required final ScheduledTaskOccurrenceCalculator _calculator,
  required final SessionNoticeService _notices,
  required final SessionWakeUpDescriptionBuilder _descriptions,
  required final PermissionAutoApprovalService _autoApproval,
  required final AgentApprovalRepository _approvals,
  required final WakeUpCommandDescriptionBuilder _commandDescriptions,
  required final ScheduledCommandService _commands,
  required final SessionMutationDispatcher _mutations,

  /// The IANA name of the bridge computer's zone, or null when it cannot be
  /// told. Read at each request, so a changed zone applies to the next one.
  required final String? Function() _localTimeZone,
  required final Clock _clock,
}) {
  static const int maxLabelLength = 100;

  /// A week.
  static const int maxMinutes = 7 * 24 * 60;

  /// Wake-ups being delivered, or waiting for the user to allow their
  /// command. In memory only: a restart empties it, and a one-shot still
  /// waiting then fires again.
  final Set<String> _inFlight = {};

  /// Stores a wake-up for [caller]'s root session. [timeZone] applies to a
  /// calendar schedule; null means the bridge computer's. A [command] outside
  /// Approve everything is only asked for: the user's Allow stores it.
  Future<WakeUpScheduleResult> schedule({
    required SesoriToolCaller caller,
    required String label,
    required String prompt,
    required WakeUpRequestedTime when,
    required String? timeZone,
    required String? command,
  }) async {
    final rootSessionId = await _rootOf(sessionId: caller.sessionId);
    if (rootSessionId == null) return const WakeUpRefused(reason: WakeUpRefusal.callerGone);
    // The label is one line on the user's screen.
    final oneLine = label.replaceAll(RegExp(r"\s+"), " ").trim();
    if (oneLine.length > maxLabelLength) return const WakeUpRefused(reason: WakeUpRefusal.labelTooLong);

    final now = _clock.now().toUtc();
    final WakeUpSchedule schedule;
    final DateTime dueAt;
    switch (_resolve(when: when, timeZone: timeZone, now: now)) {
      case _Unresolved(:final reason):
        return WakeUpRefused(reason: reason);
      case _Resolved(schedule: final resolved, dueAt: final first):
        schedule = resolved;
        dueAt = first;
    }

    // Approve everything lets a command through only when it covers both the
    // session that wrote it and the root session it runs for.
    if (command != null &&
        !(await _autoApproval.isYolo(sessionId: caller.sessionId) &&
            await _autoApproval.isYolo(sessionId: rootSessionId))) {
      final session = await _sessions.getStoredSession(sessionId: rootSessionId);
      if (session == null) return const WakeUpRefused(reason: WakeUpRefusal.callerGone);
      final change = ScheduleCommandWakeUp(
        sessionId: rootSessionId,
        label: oneLine,
        prompt: prompt,
        command: command,
        when: when,
        timeZone: timeZone,
      );
      _approvals.add(
        sessionId: caller.sessionId,
        // A sub-agent's request shows on its root session, like its wake-up.
        displaySessionId: rootSessionId == caller.sessionId ? null : rootSessionId,
        change: change,
        description: _commandDescriptions.build(
          change: change,
          workingDirectory: _workingDirectory(session: session),
        ),
      );
      Log.i("Session ${caller.sessionId} asked to set a command wake-up for session $rootSessionId");
      return const WakeUpAwaitingApproval();
    }

    final wakeUp = await _wakeUps.add(
      sessionId: rootSessionId,
      label: oneLine,
      prompt: prompt,
      command: command == null ? null : WakeUpCommand(command: command, approval: WakeUpCommandApproval.byMode),
      schedule: schedule,
      nextDueAt: dueAt,
      createdAt: now,
    );
    Log.i("Session ${caller.sessionId} set wake-up ${wakeUp.id} for session $rootSessionId");
    await _mutations.armingUpdated(sessionId: rootSessionId);
    return WakeUpScheduled(wakeUp: wakeUp);
  }

  /// The wake-ups of [caller]'s root session, soonest first.
  Future<WakeUpListLookup> list({required SesoriToolCaller caller}) async {
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

  /// Applies the user's answer to a wake-up command request, then tells the
  /// session. A confirmed command runs in the background, so this returns
  /// before it ends.
  Future<void> applyCommandApproval({required WakeUpCommandChange change, required PermissionReply reply}) async {
    final allowed = reply != PermissionReply.reject;
    switch (change) {
      case ScheduleCommandWakeUp(:final sessionId) when !allowed:
        _tell(
          sessionId: sessionId,
          notice: _commandDescriptions.scheduleOutcome(change: change, scheduled: null),
        );
      case ScheduleCommandWakeUp(:final sessionId):
        if (await _storeAllowed(change: change) case final wakeUp?) {
          await _mutations.armingUpdated(sessionId: sessionId);
          _tell(
            sessionId: sessionId,
            notice: _commandDescriptions.scheduleOutcome(change: change, scheduled: wakeUp),
          );
        }
      case ConfirmByModeCommand(:final wakeUp) when !allowed:
        _inFlight.remove(wakeUp.id);
        if (await _wakeUps.remove(id: wakeUp.id)) {
          Log.i("Cancelled wake-up ${wakeUp.id}: the user did not allow its command");
          await _mutations.armingUpdated(sessionId: wakeUp.sessionId);
          _tell(
            sessionId: wakeUp.sessionId,
            notice: _commandDescriptions.confirmRejected(wakeUp: wakeUp),
          );
        }
      case ConfirmByModeCommand(:final wakeUp, :final firedAt):
        if (!await _wakeUps.markCommandAllowed(id: wakeUp.id)) {
          _inFlight.remove(wakeUp.id);
          Log.i("Wake-up ${wakeUp.id} was cancelled before its command was allowed");
          return;
        }
        unawaited(_fire(wakeUp: wakeUp, firedAt: firedAt, commandAllowed: true));
    }
  }

  /// Fires every wake-up whose time has come. A repeating one first moves to
  /// its first time after now, so missed times never pile up; one whose
  /// previous occurrence is still being delivered skips this one.
  Future<void> runDue() async {
    final now = _clock.now().toUtc();
    for (final wakeUp in await _wakeUps.due(now: now)) {
      try {
        final next = _nextAfter(wakeUp: wakeUp, now: now);
        // Before any command runs, so a restart during it never runs it
        // again for this time.
        if (next != null) {
          await _wakeUps.setNextDueAt(id: wakeUp.id, nextDueAt: next);
          await _mutations.armingUpdated(sessionId: wakeUp.sessionId);
        }
        if (!_inFlight.add(wakeUp.id)) {
          if (next != null) Log.i("Skipped an occurrence of wake-up ${wakeUp.id}: the previous one is still waiting");
          continue;
        }
        unawaited(
          _fire(
            wakeUp: wakeUp,
            firedAt: now,
            commandAllowed: wakeUp.command?.approval == WakeUpCommandApproval.allowed,
          ),
        );
      } on Object catch (error, stackTrace) {
        Log.w("Could not fire wake-up ${wakeUp.id}", error, stackTrace);
      }
    }
  }

  /// Delivers [wakeUp], first running its command when it has one.
  /// [commandAllowed] is false for a command set under Approve everything
  /// that no one allowed since.
  Future<void> _fire({
    required StoredSessionWakeUp wakeUp,
    required DateTime firedAt,
    required bool commandAllowed,
  }) async {
    var awaitsAnswer = false;
    try {
      switch (wakeUp.command) {
        case null:
          await _deliver(
            wakeUp: wakeUp,
            firedAt: firedAt,
            ran: null,
            claim: () => _claim(wakeUp: wakeUp),
          );
        case WakeUpCommand(:final command):
          final session = await _activeSession(sessionId: wakeUp.sessionId);
          if (session == null) {
            await _wakeUps.remove(id: wakeUp.id);
            Log.i("Removed wake-up ${wakeUp.id}: session ${wakeUp.sessionId} is archived or deleted");
            await _mutations.armingUpdated(sessionId: wakeUp.sessionId);
            return;
          }
          final workingDirectory = _workingDirectory(session: session);
          if (!commandAllowed && !await _autoApproval.isYolo(sessionId: wakeUp.sessionId)) {
            final change = ConfirmByModeCommand(wakeUp: wakeUp, command: command, firedAt: firedAt);
            _approvals.add(
              sessionId: wakeUp.sessionId,
              displaySessionId: null,
              change: change,
              description: _commandDescriptions.build(change: change, workingDirectory: workingDirectory),
            );
            // Stays in flight until the answer, so later times skip.
            awaitsAnswer = true;
            Log.i("Wake-up ${wakeUp.id} asks before its command runs: its session no longer approves everything");
            return;
          }
          // Commit the use before the command runs: a restart during it then
          // loses this time rather than running the command twice.
          if (!await _claim(wakeUp: wakeUp)) {
            Log.i("Wake-up ${wakeUp.id} was cancelled before its command ran");
            return;
          }
          final result = await _commands.run(
            outputKey: wakeUp.sessionId,
            command: command,
            workingDirectory: workingDirectory,
          );
          await _deliver(
            wakeUp: wakeUp,
            firedAt: firedAt,
            ran: (command: command, workingDirectory: workingDirectory, result: result),
            // A one-shot is already claimed; a repeating one is checked again,
            // so a cancel during the command wins.
            claim: switch (wakeUp.schedule) {
              WakeUpOnce() => null,
              WakeUpEvery() || WakeUpCalendar() => () => _wakeUps.exists(id: wakeUp.id),
            },
          );
      }
      await _mutations.armingUpdated(sessionId: wakeUp.sessionId);
    } on Object catch (error, stackTrace) {
      Log.w("Wake-up ${wakeUp.id} failed after its delivery", error, stackTrace);
    } finally {
      if (!awaitsAnswer) _inFlight.remove(wakeUp.id);
    }
  }

  Future<void> _deliver({
    required StoredSessionWakeUp wakeUp,
    required DateTime firedAt,
    required WakeUpCommandRun? ran,
    required Future<bool> Function()? claim,
  }) async {
    final outcome = await _notices.deliver(
      sessionId: wakeUp.sessionId,
      notice: _descriptions.notice(wakeUp: wakeUp, firedAt: firedAt, ran: ran),
      timing: SessionNoticeTiming.afterTurn,
      claim: claim,
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
  }

  /// A one-shot removes itself, and a repeating one checks that it was not
  /// cancelled. Runs on the session's lane right before the send, or before
  /// a command runs.
  Future<bool> _claim({required StoredSessionWakeUp wakeUp}) {
    return switch (wakeUp.schedule) {
      WakeUpOnce() => _wakeUps.remove(id: wakeUp.id),
      WakeUpEvery() || WakeUpCalendar() => _wakeUps.exists(id: wakeUp.id),
    };
  }

  /// Stores an allowed command wake-up, its first time counting from now.
  /// Null when its session is gone or archived meanwhile.
  Future<StoredSessionWakeUp?> _storeAllowed({required ScheduleCommandWakeUp change}) async {
    final sessionId = change.sessionId;
    if (await _activeSession(sessionId: sessionId) == null) {
      Log.i("Set no wake-up for session $sessionId: it was archived or deleted before its command was allowed");
      return null;
    }
    final now = _clock.now().toUtc();
    switch (_resolve(when: change.when, timeZone: change.timeZone, now: now)) {
      case _Unresolved(:final reason):
        // Only a change on this computer, such as its time zone, gets here.
        Log.w("Set no wake-up for session $sessionId: its allowed time no longer resolves ($reason)");
        return null;
      case _Resolved(:final schedule, :final dueAt):
        final wakeUp = await _wakeUps.add(
          sessionId: sessionId,
          label: change.label,
          prompt: change.prompt,
          command: WakeUpCommand(command: change.command, approval: WakeUpCommandApproval.allowed),
          schedule: schedule,
          nextDueAt: dueAt,
          createdAt: now,
        );
        Log.i("Set wake-up ${wakeUp.id} for session $sessionId once its command was allowed");
        return wakeUp;
    }
  }

  /// The schedule and first time of [when], counted from [now].
  _Resolution _resolve({required WakeUpRequestedTime when, required String? timeZone, required DateTime now}) {
    switch (when) {
      case WakeUpInMinutes(:final minutes) || WakeUpEveryMinutes(:final minutes)
          when minutes < 1 || minutes > maxMinutes:
        return const _Unresolved(reason: WakeUpRefusal.minutesOutOfRange);
      case WakeUpInMinutes(:final minutes):
        return _Resolved(
          schedule: const WakeUpSchedule.once(),
          dueAt: now.add(Duration(minutes: minutes)),
        );
      case WakeUpEveryMinutes(:final minutes):
        return _Resolved(
          schedule: WakeUpSchedule.every(minutes: minutes),
          dueAt: now.add(Duration(minutes: minutes)),
        );
      case WakeUpOnSchedule(schedule: TaskScheduleWeekly(:final days)) when days.isEmpty:
        return const _Unresolved(reason: WakeUpRefusal.noDays);
      case WakeUpOnSchedule(schedule: final calendar):
        final zone = timeZone ?? _localTimeZone();
        if (zone == null) return const _Unresolved(reason: WakeUpRefusal.timeZoneNeeded);
        if (!_calculator.isKnownTimeZone(timeZone: zone)) {
          return _Unresolved(reason: timeZone == null ? WakeUpRefusal.timeZoneNeeded : WakeUpRefusal.unknownTimeZone);
        }
        final first = _calculator.firstDueAt(schedule: calendar, timeZone: zone, now: now);
        if (first == null) return const _Unresolved(reason: WakeUpRefusal.noDays);
        return _Resolved(
          schedule: WakeUpSchedule.calendar(schedule: calendar, timeZone: zone),
          dueAt: first,
        );
    }
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

  void _tell({required String sessionId, required SessionNotice notice}) {
    unawaited(_notices.deliver(sessionId: sessionId, notice: notice, timing: SessionNoticeTiming.derived, claim: null));
  }

  /// [sessionId]'s row while it is neither archived nor deleted.
  Future<StoredSession?> _activeSession({required String sessionId}) async {
    final session = await _sessions.getStoredSession(sessionId: sessionId);
    return session == null || session.archivedAt != null ? null : session;
  }

  /// Where a command for [session] runs: its worktree when it has one.
  String _workingDirectory({required StoredSession session}) => session.worktreePath ?? session.directory;

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

sealed class const _Resolution();

final class const _Resolved({required final WakeUpSchedule schedule, required final DateTime dueAt})
    extends _Resolution;

final class const _Unresolved({required final WakeUpRefusal reason}) extends _Resolution;

sealed class const WakeUpScheduleResult();

final class const WakeUpScheduled({required final StoredSessionWakeUp wakeUp}) extends WakeUpScheduleResult;

/// The wake-up runs a command, so it waits for the user's Allow.
final class const WakeUpAwaitingApproval() extends WakeUpScheduleResult;

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
