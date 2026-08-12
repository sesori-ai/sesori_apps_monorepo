import "dart:async";

import "../bridge/repositories/session_repository.dart";
import "../bridge/services/session_event_dispatcher.dart";

class SessionBindingCommitListener({
  required final Stream<SessionBindingsCommitted> _source,
  required final SessionEventDispatcher _dispatcher,
}) {
  StreamSubscription<SessionBindingsCommitted>? _subscription;
  bool _disposed = false;

  void start() {
    if (_subscription != null || _disposed) return;
    _subscription = _source.listen(
      (commit) => unawaited(_dispatcher.dispatchBindingsCommitted(commit: commit)),
      onError: _dispatcher.addSourceError,
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription?.cancel();
  }
}
