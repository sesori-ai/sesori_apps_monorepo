import "dart:async";

import "../bridge/services/prompt_echo_correlator.dart";
import "../bridge/services/session_abort_service.dart";

/// Retires a session's pending prompt correlations when its turn is aborted.
///
/// An aborted prompt never produces the echo its correlation was waiting for,
/// so keeping it would let the next prompt sent to that session inherit the
/// abandoned id and settle the wrong submission on every client.
class AbortedSessionCorrelationListener({
  required final SessionAbortService _abortService,
  required final PromptEchoCorrelator _correlator,
}) {
  // ignore: cancel_subscriptions, cancelled in dispose()
  StreamSubscription<String>? _subscription;
  bool _disposed = false;

  void start() {
    if (_subscription != null || _disposed) return;
    _subscription = _abortService.abortedSessions.listen(
      (sessionId) => _correlator.forgetSession(sessionId: sessionId),
    );
  }

  Future<void> dispose() async {
    _disposed = true;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }
}
