import "dart:async";

import "../bridge/repositories/session_repository.dart";
import "../bridge/services/session_event_dispatcher.dart";

class SessionBindingCommitListener {
  final String _pluginId;
  final Stream<SessionBindingsCommitted> _source;
  final SessionEventDispatcher _dispatcher;
  StreamSubscription<SessionBindingsCommitted>? _subscription;
  bool _disposed = false;

  SessionBindingCommitListener({
    required String pluginId,
    required Stream<SessionBindingsCommitted> source,
    required SessionEventDispatcher dispatcher,
  }) : _pluginId = pluginId,
       _source = source,
       _dispatcher = dispatcher;

  void start() {
    if (_subscription != null || _disposed) return;
    _subscription = _source
        .where((commit) => commit.pluginId == _pluginId)
        .listen(
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
