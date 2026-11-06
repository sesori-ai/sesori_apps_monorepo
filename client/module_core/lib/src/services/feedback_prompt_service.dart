import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/sse_event.dart";
import "../foundation/models/feedback/feedback_prompt_config.dart";
import "../foundation/models/feedback/feedback_prompt_state.dart";
import "../logging/logging.dart";
import "../platform/lifecycle_source.dart";
import "../repositories/feedback_prompt_repository.dart";

/// Decides when the rating prompt opens by itself.
///
/// An agent turn that finishes cleanly while the app is in the foreground earns
/// its session a point; the turn finishing is the session going idle after a
/// busy run. A failure the user felt in a session drops only that session's
/// points. Right after a clean turn brings the total across sessions to the
/// configured threshold, and once the cooldown since the last automatic
/// showing has passed, the service clears every point, records the showing and
/// emits on [prompts]. Answering **Yes** retires the automatic prompt for good.
///
/// Only the mobile shell calls [start]. Until then every record call is a
/// no-op, so the desktop shell, which shares the recording cubits but never
/// shows the prompt, stores nothing.
@lazySingleton
class FeedbackPromptService({
  required final ConnectionService _connectionService,
  required final LifecycleSource _lifecycleSource,
  required final FeedbackPromptRepository _repository,
}) {
  final StreamController<void> _prompts = StreamController<void>.broadcast();

  /// Fetched once per launch, on first use.
  late final Future<FeedbackPromptConfig> _config = _repository.readConfig();

  StreamSubscription<SseEvent>? _eventsSubscription;

  /// Serializes the read-modify-write updates of the stored progress.
  Future<void> _lastUpdate = Future<void>.value();

  /// Sessions last reported busy or retrying, whose going idle ends a turn.
  final Set<String> _busySessions = {};

  /// Sessions whose current turn failed or was stopped, so it earns no point
  /// when it ends. Cleared when the session's next turn starts.
  final Set<String> _spoiledTurns = {};

  /// Sessions the user stopped. Some backends report a stopped response as an
  /// error, so their AI errors do not count until their next turn starts.
  final Set<String> _stoppedSessions = {};

  /// Sub-agent sessions. Their turns run inside the parent's turn, which is
  /// still going when they end, so they never earn points.
  final Set<String> _childSessions = {};

  bool get _isStarted => _eventsSubscription != null;

  /// Emits once for each automatic showing, right after it is recorded.
  Stream<void> get prompts => _prompts.stream;

  /// Starts recording finished turns and AI errors from every session.
  void start() {
    _eventsSubscription ??= _connectionService.events.listen(_onEvent);
    unawaited(_config);
  }

  /// The user is stopping [sessionId]'s response; call before the stop request
  /// goes out, because its error event can arrive before the response does.
  void recordUserStop({required String sessionId}) {
    if (!_isStarted) return;
    _stoppedSessions.add(sessionId);
    _spoiledTurns.add(sessionId);
  }

  /// A failure the user felt in [sessionId]: an AI error, or a failed send or
  /// reply. Drops only that session's points; other sessions keep theirs.
  Future<void> recordFailure({required String sessionId}) {
    if (!_isStarted) return Future<void>.value();
    _spoiledTurns.add(sessionId);
    return _update(() async {
      final state = await _repository.readState();
      if (state case FeedbackPromptCounting(:final pointsBySession, :final lastShownAt)
          when pointsBySession.containsKey(sessionId)) {
        await _repository.writeState(
          state: FeedbackPromptCounting(
            pointsBySession: {...pointsBySession}..remove(sessionId),
            lastShownAt: lastShownAt,
          ),
        );
      }
    });
  }

  /// The previous launch crashed: every session's points are dropped.
  Future<void> recordCrash() => _update(() async {
    final state = await _repository.readState();
    if (state case FeedbackPromptCounting(:final pointsBySession, :final lastShownAt) when pointsBySession.isNotEmpty) {
      await _repository.writeState(
        state: FeedbackPromptCounting(pointsBySession: const {}, lastShownAt: lastShownAt),
      );
    }
  });

  /// The user answered **Yes** from either entry.
  Future<void> recordYes() => _update(() => _repository.writeState(state: const FeedbackPromptRetired()));

  void _onEvent(SseEvent event) {
    final data = event.data;
    if (data case SesoriSessionCreated(:final info) || SesoriSessionUpdated(:final info) when info.parentID != null) {
      _childSessions.add(info.id);
    } else if (data case SesoriSessionStatus(:final sessionID, :final status)) {
      _onSessionStatus(sessionId: sessionID, status: status);
    } else if (data case SesoriSessionError() || SesoriMessageUpdated(info: MessageError())) {
      // A session error without a session belongs to none of the counted
      // turns, so it drops nothing.
      final sessionId = event.sessionId;
      if (sessionId == null || _stoppedSessions.contains(sessionId)) return;
      unawaited(recordFailure(sessionId: sessionId));
    }
  }

  void _onSessionStatus({required String sessionId, required SessionStatus status}) {
    switch (status) {
      case SessionStatusBusy() || SessionStatusRetry():
        if (_busySessions.add(sessionId)) {
          _spoiledTurns.remove(sessionId);
          _stoppedSessions.remove(sessionId);
        }
      case SessionStatusIdle():
        if (!_busySessions.remove(sessionId)) return;
        final spoiled = _spoiledTurns.remove(sessionId);
        if (spoiled || _childSessions.contains(sessionId)) return;
        if (_lifecycleSource.lifecycleState != LifecycleState.resumed) return;
        unawaited(_recordFinishedTurn(sessionId: sessionId));
    }
  }

  Future<void> _recordFinishedTurn({required String sessionId}) => _update(() async {
    final state = await _repository.readState();
    if (state is! FeedbackPromptCounting) return;
    final pointsBySession = {...state.pointsBySession, sessionId: (state.pointsBySession[sessionId] ?? 0) + 1};
    final counted = FeedbackPromptCounting(pointsBySession: pointsBySession, lastShownAt: state.lastShownAt);
    final config = await _config;
    final now = DateTime.now().toUtc();
    final lastShownAt = state.lastShownAt;
    final isDue =
        counted.totalPoints >= config.interactionThreshold &&
        (lastShownAt == null || now.difference(lastShownAt) >= config.cooldown);
    if (!isDue) {
      await _repository.writeState(state: counted);
      return;
    }
    // Claiming the showing in the same write that clears the points means the
    // next one needs a fresh run of finished turns and the full cooldown.
    await _repository.writeState(
      state: FeedbackPromptCounting(pointsBySession: const {}, lastShownAt: now),
    );
    logi("Showing the automatic rating prompt after ${counted.totalPoints} finished turns");
    if (!_prompts.isClosed) _prompts.add(null);
  });

  Future<void> _update(Future<void> Function() update) {
    if (!_isStarted) return Future<void>.value();
    return _lastUpdate = _lastUpdate.then((_) => update()).catchError((Object error, StackTrace stackTrace) {
      logw("Failed to update the automatic rating prompt progress", error, stackTrace);
    });
  }

  @disposeMethod
  Future<void> dispose() async {
    await _eventsSubscription?.cancel();
    _eventsSubscription = null;
    await _prompts.close();
  }
}
