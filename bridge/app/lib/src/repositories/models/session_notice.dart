/// What the bridge tells a session, once, about how something it asked for
/// ended: [summary] is the line the user sees, addressed to them, and
/// [guidance] is what the agent reads beside it.
class const SessionNotice({required final String summary, required final String guidance});

/// When a notice may reach a session whose agent is working.
enum SessionNoticeTiming() {
  /// Into the running turn on a harness that steers; after the turn otherwise.
  intoRunningTurn,

  /// Only once the turn has ended, so the notice starts a turn of its own.
  afterTurn,
}
