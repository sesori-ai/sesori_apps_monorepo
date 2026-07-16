import "dart:async";

import "package:sesori_shared/sesori_shared.dart";

import "../bridge/services/session_event_dispatcher.dart";

class SessionDeletionListener {
  final Stream<Session> _source;
  final SessionEventDispatcher _dispatcher;
  StreamSubscription<Session>? _subscription;
  bool _disposed = false;

  SessionDeletionListener({
    required Stream<Session> source,
    required SessionEventDispatcher dispatcher,
  }) : _source = source,
       _dispatcher = dispatcher;

  void start() {
    if (_subscription != null || _disposed) return;
    _subscription = _source.listen(
      (session) => unawaited(_dispatcher.dispatchDeletedSession(session: session)),
      onError: _dispatcher.addSourceError,
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription?.cancel();
  }
}
