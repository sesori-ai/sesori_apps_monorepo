import "dart:async";

import "../services/session_event_dispatcher.dart";

class SessionMutationListener({
  required final Stream<LocalSessionEvent> _source,
  required final SessionEventDispatcher _dispatcher,
}) {
  StreamSubscription<LocalSessionEvent>? _subscription;
  bool _disposed = false;

  void start() {
    if (_subscription != null || _disposed) return;
    _subscription = _source.listen(
      (event) => unawaited(_dispatcher.dispatchLocalEvent(source: event)),
      onError: _dispatcher.addSourceError,
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription?.cancel();
  }
}
