import "dart:async";

import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "completion_notifier.dart";
import "push_dispatcher.dart";
import "push_notification_content_builder.dart";
import "push_session_state_tracker.dart";

class CompletionPushListener({
  required final PushSessionStateTracker _tracker,
  required final CompletionNotifier _completionNotifier,
  required final PushNotificationContentBuilder _contentBuilder,
  required final PushDispatcher _dispatcher,
  // The stored catalog title, not a tracker-cached one: the tracker forgets a
  // root after it is pruned for idleness or the bridge restarts, which is
  // exactly when a returning user prompts a long-idle session.
  required final Future<String?> Function({required String sessionId}) _resolveSessionTitle,
}) {
  final CompositeSubscription _subscriptions = CompositeSubscription();
  bool _isStarted = false;

  void handleSseEvent({required SesoriSseEvent event}) {
    _tracker.handleEvent(event: event);
    _completionNotifier.handleEvent(event: event);
    _dispatcher.dispatchImmediateIfApplicable(event: event);
  }

  /// Marks a session as user-aborted so the completion notification is
  /// suppressed for the current busy→idle transition.
  void markSessionAbortPending({required String sessionId}) {
    _completionNotifier.markSessionAbortPending(sessionId: sessionId);
  }

  void markSessionAborted({required String sessionId}) {
    _completionNotifier.markSessionAborted(sessionId: sessionId);
  }

  void clearPendingAbort({required String sessionId}) {
    _completionNotifier.clearPendingAbort(sessionId: sessionId);
  }

  void start() {
    if (_isStarted) {
      return;
    }
    _isStarted = true;

    _completionNotifier.completions
        .listen((rootSessionId) async {
          final latestAssistantText = _tracker.getLatestAssistantText(sessionId: rootSessionId);
          final body = _contentBuilder.truncateToWords(
            text: (latestAssistantText == null || latestAssistantText.trim().isEmpty)
                ? "Task completed"
                : latestAssistantText,
          );
          final projectId = _tracker.getSessionProjectId(sessionId: rootSessionId);

          _tracker.clearLatestAssistantTextForRootSubtree(rootSessionId: rootSessionId);
          final sessionTitle = await _resolveSessionTitle(sessionId: rootSessionId).onError((error, stackTrace) {
            Log.w("[push] failed to resolve title for session $rootSessionId", error, stackTrace);
            return null;
          });
          _dispatcher.dispatchCompletion(
            rootSessionId: rootSessionId,
            title: _contentBuilder.truncateTitle(
              title: (sessionTitle == null || sessionTitle.trim().isEmpty) ? "Session completed" : sessionTitle,
            ),
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
}
