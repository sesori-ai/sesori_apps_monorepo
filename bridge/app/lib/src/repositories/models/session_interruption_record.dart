/// A session's latest turn that a bridge stop cut off.
final class const SessionInterruptionRecord({
  required final String sessionId,

  /// The newest stored history message when the interruption was recorded.
  required final String afterMessageId,

  /// Whether the user opened the session or sent to it since.
  required final bool acknowledged,
});
