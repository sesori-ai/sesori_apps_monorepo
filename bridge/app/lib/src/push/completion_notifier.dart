import "dart:async";

import "package:sesori_shared/sesori_shared.dart";

import "push_session_state_tracker.dart";

/// Manages debounced "session completed" notifications.
///
/// Tracks when session groups transition from busy to idle and fires
/// a stream event after a debounce period, provided no pending interactions
/// (questions/permissions) block it.
class CompletionNotifier {
  final PushSessionStateTracker _tracker;
  final Duration _debounceDuration;
  final StreamController<String> _completionController = StreamController<String>.broadcast();
  final Map<String, Timer> _debounceTimers = {};
  final Set<String> _completionSentForRoots = {};
  final Set<String> _completionBlockedByPendingInteraction = {};
  final Set<String> _pendingAbortRoots = {};
  final Set<String> _abortedRoots = {};
  final Map<String, String> _permissionRequestToSession = {};

  Stream<String> get completions => _completionController.stream;

  int get permissionRequestCount => _permissionRequestToSession.length;

  int get completionSentRootCount => _completionSentForRoots.length;

  int get abortedRootCount => _abortedRoots.length;

  CompletionNotifier({
    required PushSessionStateTracker tracker,
    Duration debounceDuration = const Duration(milliseconds: 500),
  }) : _tracker = tracker,
       _debounceDuration = debounceDuration;

  void markSessionAbortPending(String sessionId) {
    final rootSessionId = _tracker.resolveRootSessionId(sessionId);
    _pendingAbortRoots.add(rootSessionId);
    _cancelDebounceForRoot(rootSessionId);
  }

  /// Marks a session as user-aborted so the next idle transition does not
  /// trigger a completion notification. The flag is cleared when the session
  /// becomes busy again (new turn) or is deleted.
  void markSessionAborted(String sessionId) {
    final rootSessionId = _tracker.resolveRootSessionId(sessionId);
    _pendingAbortRoots.remove(rootSessionId);
    _abortedRoots.add(rootSessionId);
    _cancelDebounceForRoot(rootSessionId);
  }

  void clearPendingAbort(String sessionId) {
    final rootSessionId = _tracker.resolveRootSessionId(sessionId);
    final wasPending = _pendingAbortRoots.remove(rootSessionId);
    if (!wasPending) {
      return;
    }
    _maybeScheduleCompletion(rootSessionId);
  }

  /// Process an SSE event for completion tracking.
  /// Call AFTER tracker.handleEvent() has already updated state.
  void handleEvent(SesoriSseEvent event) {
    switch (event) {
      // A new question blocks completion for this session group.
      case SesoriQuestionAsked(:final sessionID):
        _cancelDebounceForSessionGroup(sessionID);
      // A new permission request blocks completion for this session group.
      case SesoriPermissionAsked(:final requestID, :final sessionID):
        _permissionRequestToSession[requestID] = sessionID;
        _cancelDebounceForSessionGroup(sessionID);
      // Session status transitions determine when completion can fire.
      case SesoriSessionStatus(:final sessionID, :final status):
        final rootSessionId = _tracker.resolveRootSessionId(sessionID);
        switch (status) {
          case SessionStatusBusy():
          case SessionStatusRetry():
            _completionSentForRoots.remove(rootSessionId);
            _completionBlockedByPendingInteraction.remove(rootSessionId);
            _pendingAbortRoots.remove(rootSessionId);
            _abortedRoots.remove(rootSessionId);
            _cancelDebounceForRoot(rootSessionId);
          case SessionStatusIdle():
            if (_tracker.isSessionGroupFullyIdle(rootSessionId) &&
                _tracker.hasPendingInteraction(rootSessionId)) {
              // The agent finished while prompts are still pending. Block
              // completion until the user resolves all of them.
              _completionBlockedByPendingInteraction.add(rootSessionId);
              _cancelDebounceForRoot(rootSessionId);
            } else {
              _maybeScheduleCompletion(sessionID);
            }
        }
      // Deletion clears any pending completion work for this session group.
      case SesoriSessionDeleted(:final info):
        _cancelDebounceForSessionGroup(info.id);
        _completionSentForRoots.remove(info.id);
        _completionBlockedByPendingInteraction.remove(info.id);
        _pendingAbortRoots.remove(info.id);
        _abortedRoots.remove(info.id);
        _permissionRequestToSession.removeWhere((_, sessionId) => sessionId == info.id);
        // The deleted session may have been the last pending interaction
        // blocking its root. Resume completion for the root if it is still
        // reachable via the parent and now eligible.
        if (info.parentID case final parentId?) {
          _maybeResumeBlockedCompletion(parentId);
        }
      // User already handled the question; resume completion if this was the
      // last blocker for an idle session group.
      case SesoriQuestionReplied(:final sessionID):
        _maybeResumeBlockedCompletion(sessionID);
      // Rejected questions are also already seen by the user.
      case SesoriQuestionRejected(:final sessionID):
        _maybeResumeBlockedCompletion(sessionID);
      // Permission replies are user actions; resume completion if this was the
      // last blocker for an idle session group.
      case SesoriPermissionReplied(:final requestID):
        final sessionId = _permissionRequestToSession.remove(requestID);
        if (sessionId != null) {
          _maybeResumeBlockedCompletion(sessionId);
        }
      // Ignore unsupported events.
      default:
        break;
    }
  }

  /// Removes notifier-retained state for a pruned root subtree.
  void cleanupPrunedRootSubtree({
    required String rootSessionId,
    required Iterable<String> prunedSessionIds,
  }) {
    final prunedRootIds = {rootSessionId, ...prunedSessionIds};
    for (final sessionId in prunedRootIds) {
      _cancelDebounceForRoot(sessionId);
      _completionSentForRoots.remove(sessionId);
      _completionBlockedByPendingInteraction.remove(sessionId);
      _pendingAbortRoots.remove(sessionId);
      _abortedRoots.remove(sessionId);
    }
    _permissionRequestToSession.removeWhere((_, sessionId) => prunedRootIds.contains(sessionId));
  }

  /// Cancels all timers and closes the completion stream.
  void dispose() {
    _cancelAllDebounceTimers();
    if (!_completionController.isClosed) {
      _completionController.close();
    }
  }

  /// Clears debounce state but keeps the completion stream open.
  void reset() {
    _cancelAllDebounceTimers();
    _completionSentForRoots.clear();
    _completionBlockedByPendingInteraction.clear();
    _pendingAbortRoots.clear();
    _abortedRoots.clear();
    _permissionRequestToSession.clear();
  }

  /// Cancels every active debounce timer.
  void _cancelAllDebounceTimers() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
  }

  /// Schedules completion for [sessionId] only if its group was previously busy,
  /// is fully idle, has no pending interactions, and was blocked by a pending
  /// interaction. Used after question/permission replies or session deletions
  /// so an already-idle session can still fire completion once the last blocker
  /// is removed.
  void _maybeResumeBlockedCompletion(String sessionId) {
    final rootSessionId = _tracker.resolveRootSessionId(sessionId);
    // The blocked key may have been recorded under the original sessionId
    // before a parent link was learned (reparenting). Find either key and
    // remove it only when we are actually going to schedule completion.
    final blockedKey = _completionBlockedByPendingInteraction.contains(rootSessionId)
        ? rootSessionId
        : _completionBlockedByPendingInteraction.contains(sessionId)
            ? sessionId
            : null;
    if (blockedKey == null) {
      return;
    }
    if (_tracker.wasPreviouslyBusy(rootSessionId) &&
        _tracker.isSessionGroupFullyIdle(rootSessionId) &&
        !_tracker.hasPendingInteraction(rootSessionId)) {
      _completionBlockedByPendingInteraction.remove(blockedKey);
      _maybeScheduleCompletion(sessionId);
    }
  }

  /// Schedules (or reschedules) completion emission for [sessionId]'s root.
  void _maybeScheduleCompletion(String sessionId) {
    final rootSessionId = _tracker.resolveRootSessionId(sessionId);
    if (!_shouldTriggerCompletion(rootSessionId)) {
      _cancelDebounceForRoot(rootSessionId);
      return;
    }

    _debounceTimers[rootSessionId]?.cancel();
    _debounceTimers[rootSessionId] = Timer(_debounceDuration, () {
      _debounceTimers.remove(rootSessionId);

      // Re-resolve: parent links may have been established during the debounce
      // window (e.g., from a SesoriProjectsSummary or late SesoriSessionCreated).
      // If this session is now known to be a child, reschedule for the real root.
      final currentRoot = _tracker.resolveRootSessionId(rootSessionId);
      if (currentRoot != rootSessionId) {
        _maybeScheduleCompletion(rootSessionId);
        return;
      }

      if (!_shouldTriggerCompletion(rootSessionId)) {
        return;
      }
      if (_completionController.isClosed) {
        return;
      }
      _completionController.add(rootSessionId);
      _completionSentForRoots.add(rootSessionId);
    });
  }

  /// Returns true when completion notification criteria are satisfied.
  bool _shouldTriggerCompletion(String rootSessionId) {
    return _tracker.wasPreviouslyBusy(rootSessionId) &&
        _tracker.isSessionGroupFullyIdle(rootSessionId) &&
        !_tracker.hasPendingInteraction(rootSessionId) &&
        !_completionSentForRoots.contains(rootSessionId) &&
        !_pendingAbortRoots.contains(rootSessionId) &&
        !_abortedRoots.contains(rootSessionId);
  }

  /// Cancels debounce timers for a session and its current root session.
  void _cancelDebounceForSessionGroup(String sessionId) {
    final rootSessionId = _tracker.resolveRootSessionId(sessionId);
    _cancelDebounceForRoot(rootSessionId);
    if (rootSessionId != sessionId) {
      // Also cancel any timer for sessionId itself, in case it was
      // previously a root and has since been reparented.
      _cancelDebounceForRoot(sessionId);
    }
  }

  /// Cancels and removes a single root debounce timer.
  void _cancelDebounceForRoot(String rootSessionId) {
    final timer = _debounceTimers.remove(rootSessionId);
    timer?.cancel();
  }
}
