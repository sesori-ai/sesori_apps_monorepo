import "dart:async";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show buildSessionNotice;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show BridgeSseSessionIdle, Log, PluginBusyPromptHandling;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/normalized_bridge_event.dart";
import "../repositories/models/session_notice.dart";
import "../repositories/models/session_operation.dart";
import "../repositories/models/session_quietness.dart";
import "../repositories/scheduled_task_repository.dart";
import "../repositories/session_repository.dart";
import "../repositories/trackers/prompt_stamp.dart";
import "plugin_lifecycle_service.dart";
import "session_event_dispatcher.dart";
import "session_operation_dispatcher.dart";
import "session_prompt_service.dart";

/// Tells the session where a request was shown, once, how that request ended.
///
/// The notice is a bridge prompt marked [PromptStampNotice], so it shows as a
/// Sesori row with only its summary. It never stops the agent's work or cuts
/// across input the user has not given: a harness that steers takes it into
/// the running turn, and otherwise it waits until the session is quiet. A
/// scheduled run's session hears it only after its turn, so the turn the
/// notice starts is its own and the run's final reply stays the run's.
/// Nothing is kept across a bridge restart. Logs carry the session id and
/// the reason, never the notice text.
class const SessionNoticeService({
  required final SessionRepository _sessions,
  required final SessionOperationDispatcher _operations,
  required final SessionPromptService _prompts,
  required final SessionEventDispatcher _events,
  required final PluginLifecycleService _plugins,
  required final ScheduledTaskRepository _tasks,
}) {
  /// Sends [notice] into [sessionId] as soon as its timing allows, skipping
  /// an archived or deleted session. Completes once it is sent, skipped or
  /// dropped; never throws.
  Future<void> deliver({required String sessionId, required SessionNotice notice}) async {
    if (await _promptableSession(sessionId: sessionId) == null) {
      Log.i("Skipped a notice for session $sessionId: it is archived or deleted");
      return;
    }
    // Listening before the first check keeps an idle that lands between a
    // busy check and the wait from being missed.
    var idle = Completer<void>();
    final subscription = _events.events.listen(
      (sourced) {
        if (_isIdle(event: sourced.event, sessionId: sessionId) && !idle.isCompleted) idle.complete();
      },
      // The dispatcher's own consumers report source errors; the wait simply
      // has nothing to observe for a failed event.
      onError: (Object _) {},
      onDone: () {
        if (!idle.isCompleted) idle.completeError(StateError("the bridge is shutting down"));
      },
    );
    try {
      final isRun = (await _tasks.marksOfSessions(sessionIds: {sessionId})).containsKey(sessionId);
      final timing = isRun ? _SessionNoticeTiming.afterTurn : _SessionNoticeTiming.intoRunningTurn;
      while (true) {
        final attempt = await _operations.dispatch(
          sessionId: sessionId,
          operation: SessionOperation.deliverNotice,
          body: () => _sendIfReady(sessionId: sessionId, notice: notice, timing: timing),
        );
        switch (attempt) {
          case _Attempt.sent:
            return;
          case _Attempt.skipped:
            Log.i("Skipped a notice for session $sessionId: it was archived or deleted while it waited");
            return;
          case _Attempt.waiting:
            await idle.future;
            idle = Completer<void>();
        }
      }
    } on Object catch (error, stackTrace) {
      Log.w("Dropped a notice for session $sessionId", error, stackTrace);
    } finally {
      await subscription.cancel();
    }
  }

  /// Runs on the session's lane, so no other prompt starts between the check
  /// and the send. A session that turned busy since its idle waits again.
  Future<_Attempt> _sendIfReady({
    required String sessionId,
    required SessionNotice notice,
    required _SessionNoticeTiming timing,
  }) async {
    final session = await _promptableSession(sessionId: sessionId);
    if (session == null) return _Attempt.skipped;
    final ready = switch (await _sessions.getSessionQuietness(sessionId: sessionId)) {
      SessionQuietness.quiet || SessionQuietness.unknown => true,
      SessionQuietness.working => switch (timing) {
        _SessionNoticeTiming.intoRunningTurn =>
          _plugins.busyPromptHandling(pluginId: session.pluginId) == PluginBusyPromptHandling.steer,
        _SessionNoticeTiming.afterTurn => false,
      },
      SessionQuietness.awaitingUser => false,
    };
    if (!ready) return _Attempt.waiting;
    final text = buildSessionNotice(summary: notice.summary, guidance: notice.guidance);
    await _prompts.sendWithDefaults(
      sessionId: sessionId,
      defaults: session.promptDefaults,
      send: (settings) => _prompts.sendPromptAlreadyReserved(
        sessionId: sessionId,
        promptId: SessionPromptService.generatePromptId(),
        parts: [PromptPart.text(text: text)],
        variant: settings.variant,
        fastMode: settings.fastMode,
        agent: settings.agent,
        model: settings.model,
        command: null,
        commandSource: null,
        mark: const PromptStampNotice(),
        runContext: null,
      ),
    );
    return _Attempt.sent;
  }

  /// [sessionId]'s stored session, or null when it is deleted or archived.
  Future<Session?> _promptableSession({required String sessionId}) async {
    final session = await _sessions.getCatalogSession(sessionId: sessionId);
    return session == null || session.time?.archived != null ? null : session;
  }

  static bool _isIdle({required NormalizedBridgeEvent event, required String sessionId}) {
    final payload = switch (event) {
      NormalizedTerminalHandoff(:final payload) => payload,
      final NormalizedBridgePayload payload => payload,
    };
    // Harnesses report the end of a turn as either event.
    return switch (payload) {
      NormalizedStatusEvent(sessionId: final idleSessionId, status: SessionStatusIdle()) ||
      NormalizedOtherEvent(event: BridgeSseSessionIdle(sessionID: final idleSessionId)) => idleSessionId == sessionId,
      _ => false,
    };
  }
}

/// When a notice may reach a session whose agent is working.
enum _SessionNoticeTiming() {
  /// Into the running turn on a harness that steers; after the turn otherwise.
  intoRunningTurn,

  /// Only once the turn has ended, so the notice starts a turn of its own.
  afterTurn,
}

enum _Attempt() {
  sent,
  skipped,
  waiting,
}
