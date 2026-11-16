/// A session's turn in flight, as its running row recorded it.
final class const SessionRunningTurnRecord({
  required final String sessionId,

  /// When the bridge last saw the turn running.
  required final DateTime startedAt,
});
