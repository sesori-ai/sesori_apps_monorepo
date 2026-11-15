/// What the session's harness did with a request to compact its context.
enum SessionCompactionResult() {
  /// The harness took the compaction.
  accepted,

  /// The session was working or waiting for input; nothing was sent.
  sessionBusy,

  /// The session's harness cannot compact on request.
  unsupported,
}
