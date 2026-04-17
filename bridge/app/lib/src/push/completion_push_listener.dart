import "dart:async";

import "package:meta/meta.dart";
import "package:sesori_shared/sesori_shared.dart";

import "completion_notifier.dart";
import "push_dispatcher.dart";
import "push_session_state_tracker.dart";

class CompletionPushListener {
  final PushSessionStateTracker _tracker;
  final CompletionNotifier _completionNotifier;
  final PushDispatcher _dispatcher;

  // ignore: cancel_subscriptions, this listener stores the subscription and cancels it in dispose()
  StreamSubscription<String>? _completionSubscription;

  CompletionPushListener({
    required PushSessionStateTracker tracker,
    required CompletionNotifier completionNotifier,
    required PushDispatcher dispatcher,
  }) : _tracker = tracker,
       _completionNotifier = completionNotifier,
       _dispatcher = dispatcher;

  @visibleForTesting
  bool get isStarted => _completionSubscription != null;

  void handleSseEvent(SesoriSseEvent event) {
    _tracker.handleEvent(event);
    _completionNotifier.handleEvent(event);
    _dispatcher.dispatchImmediateIfApplicable(event);
  }

  /// Marks a session as user-aborted so the completion notification is
  /// suppressed for the current busy→idle transition.
  void markSessionAborted(String sessionId) {
    _completionNotifier.markSessionAborted(sessionId);
  }

  void start() {
    if (_completionSubscription != null) {
      return;
    }

    _completionSubscription = _completionNotifier.completions.listen((rootSessionId) {
      _dispatcher.dispatchCompletionForRoot(rootSessionId: rootSessionId);
    });
  }

  Future<void> dispose() async {
    final completionSubscription = _completionSubscription;
    _completionSubscription = null;
    await completionSubscription?.cancel();
    _completionNotifier.dispose();
  }

  void reset() {
    _completionNotifier.reset();
    _tracker.reset();
  }
}
