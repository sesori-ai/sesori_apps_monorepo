import "dart:async";

import "package:sesori_shared/sesori_shared.dart";

import "push_session_state_tracker.dart";

/// Manages debounced "session completed" notifications.
///
/// Tracks when session groups transition from busy to idle and fires
/// a callback after a debounce period, provided no pending interactions
/// (questions/permissions) block it.
class CompletionNotifier {
  final PushSessionStateTracker _tracker;
  final void Function(String rootSessionId) _onCompletion;
  final Duration _debounceDuration;
  final Map<String, Timer> _debounceTimers = {};
  final Set<String> _completionSentForRoots = {};
  final Map<String, String> _permissionRequestToSession = {};

  CompletionNotifier({
    required PushSessionStateTracker tracker,
    required void Function(String rootSessionId) onCompletion,
    Duration debounceDuration = const Duration(milliseconds: 500),
  }) : _tracker = tracker,
       _onCompletion = onCompletion,
       _debounceDuration = debounceDuration;

  /// Process an SSE event for completion tracking.
  /// Call AFTER tracker.handleEvent() has already updated state.
  void handleEvent(SesoriSseEvent event) {
    switch (event) {
      case SesoriQuestionAsked(:final sessionID):
        _cancelDebounceForSessionGroup(sessionID);
      case SesoriPermissionAsked(:final requestID, :final sessionID):
        _permissionRequestToSession[requestID] = sessionID;
        _cancelDebounceForSessionGroup(sessionID);
      case SesoriSessionStatus(:final sessionID, :final status):
        final rootSessionId = _tracker.resolveRootSessionId(sessionID);
        switch (status) {
          case SessionStatusBusy():
          case SessionStatusRetry():
            _completionSentForRoots.remove(rootSessionId);
            _cancelDebounceForRoot(rootSessionId);
          case SessionStatusIdle():
            _maybeScheduleCompletion(sessionID);
        }
      case SesoriSessionDeleted(:final info):
        _cancelDebounceForSessionGroup(info.id);
        _completionSentForRoots.remove(info.id);
        _permissionRequestToSession.removeWhere((_, sessionId) => sessionId == info.id);
      case SesoriQuestionReplied(:final sessionID):
        _maybeScheduleCompletion(sessionID);
      case SesoriQuestionRejected(:final sessionID):
        _maybeScheduleCompletion(sessionID);
      case SesoriPermissionReplied(:final requestID):
        final sessionId = _permissionRequestToSession.remove(requestID);
        if (sessionId != null) {
          _maybeScheduleCompletion(sessionId);
        }
      default:
        break;
    }
  }

  /// Cancel all timers.
  void dispose() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
  }

  /// Cancel all timers and clear internal state.
  void reset() {
    dispose();
    _completionSentForRoots.clear();
    _permissionRequestToSession.clear();
  }

  void _maybeScheduleCompletion(String sessionId) {
    final rootSessionId = _tracker.resolveRootSessionId(sessionId);
    if (!_shouldTriggerCompletion(rootSessionId)) {
      _cancelDebounceForRoot(rootSessionId);
      return;
    }

    _debounceTimers[rootSessionId]?.cancel();
    _debounceTimers[rootSessionId] = Timer(_debounceDuration, () {
      _debounceTimers.remove(rootSessionId);
      if (!_shouldTriggerCompletion(rootSessionId)) {
        return;
      }
      _onCompletion(rootSessionId);
      _completionSentForRoots.add(rootSessionId);
    });
  }

  bool _shouldTriggerCompletion(String rootSessionId) {
    return _tracker.wasPreviouslyBusy(rootSessionId) &&
        _tracker.isSessionGroupFullyIdle(rootSessionId) &&
        !_tracker.hasPendingInteraction(rootSessionId) &&
        !_completionSentForRoots.contains(rootSessionId);
  }

  void _cancelDebounceForSessionGroup(String sessionId) {
    final rootSessionId = _tracker.resolveRootSessionId(sessionId);
    _cancelDebounceForRoot(rootSessionId);
    if (rootSessionId != sessionId) {
      _cancelDebounceForRoot(sessionId);
    }
  }

  void _cancelDebounceForRoot(String rootSessionId) {
    final timer = _debounceTimers.remove(rootSessionId);
    timer?.cancel();
  }
}
