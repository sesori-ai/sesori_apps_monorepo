/// What a plugin did with a request to compact one session's context.
enum PluginCompactionResult() {
  /// The harness took the compaction; it runs like a command the user sent.
  accepted,

  /// The session is working or waiting for input, so nothing was sent and no
  /// running work was stopped. The caller may ask again once it is quiet.
  sessionBusy,

  /// This harness, or the running version of it, cannot compact on request.
  unsupported,
}
