import "dart:async";

import "package:meta/meta.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_shared/sesori_shared.dart";

import "completion_notifier.dart";
import "push_dispatcher.dart";
import "push_notification_content_builder.dart";
import "push_session_state_tracker.dart";

class CompletionPushListener {
  final PushSessionStateTracker _tracker;
  final CompletionNotifier _completionNotifier;
  final PushNotificationContentBuilder _contentBuilder;
  final PushDispatcher _dispatcher;

  final CompositeSubscription _subscriptions = CompositeSubscription();
  bool _isStarted = false;

  CompletionPushListener({
    required PushSessionStateTracker tracker,
    required CompletionNotifier completionNotifier,
    required PushNotificationContentBuilder contentBuilder,
    required PushDispatcher dispatcher,
  }) : _tracker = tracker,
       _completionNotifier = completionNotifier,
       _contentBuilder = contentBuilder,
       _dispatcher = dispatcher;

  @visibleForTesting
  bool get isStarted => _isStarted;

  void handleSseEvent(SesoriSseEvent event) {
    _tracker.handleEvent(event);
    _completionNotifier.handleEvent(event);
    _dispatcher.dispatchImmediateIfApplicable(event);
  }

  /// Marks a session as user-aborted so the completion notification is
  /// suppressed for the current busy→idle transition.
  void markSessionAbortPending(String sessionId) {
    _completionNotifier.markSessionAbortPending(sessionId);
  }

  void markSessionAborted(String sessionId) {
    _completionNotifier.markSessionAborted(sessionId);
  }

  void clearPendingAbort(String sessionId) {
    _completionNotifier.clearPendingAbort(sessionId);
  }

  void start() {
    if (_isStarted) {
      return;
    }
    _isStarted = true;

    _completionNotifier.completions
        .listen((rootSessionId) {
          final sessionTitle = _tracker.getSessionTitle(rootSessionId);
          final latestAssistantText = _tracker.getLatestAssistantText(rootSessionId);
          final title = _contentBuilder.truncateTitle(
            (sessionTitle == null || sessionTitle.trim().isEmpty) ? "Session completed" : sessionTitle,
          );
          final body = _contentBuilder.truncateToWords(
            (latestAssistantText == null || latestAssistantText.trim().isEmpty)
                ? "Task completed"
                : latestAssistantText,
          );
          final projectId = _tracker.getSessionProjectId(sessionId: rootSessionId);

          _tracker.clearLatestAssistantTextForRootSubtree(rootSessionId: rootSessionId);
          _dispatcher.dispatchCompletion(
            rootSessionId: rootSessionId,
            title: title,
            body: body,
            projectId: projectId,
          );
        })
        .addTo(_subscriptions);
  }

  Future<void> dispose() async {
    _isStarted = false;
    await _subscriptions.cancel();
    _completionNotifier.dispose();
  }

  void reset() {
    _completionNotifier.reset();
    _tracker.reset();
  }
}
