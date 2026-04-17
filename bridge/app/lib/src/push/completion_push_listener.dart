import "dart:async";

import "completion_notifier.dart";
import "push_dispatcher.dart";

class CompletionPushListener {
  final CompletionNotifier _completionNotifier;
  final PushDispatcher _dispatcher;

  // ignore: cancel_subscriptions, this listener stores the subscription and cancels it in dispose()
  StreamSubscription<String>? _completionSubscription;

  CompletionPushListener({
    required CompletionNotifier completionNotifier,
    required PushDispatcher dispatcher,
  }) : _completionNotifier = completionNotifier,
       _dispatcher = dispatcher;

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
  }
}
