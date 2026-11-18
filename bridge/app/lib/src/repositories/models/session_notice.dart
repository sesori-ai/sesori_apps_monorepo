/// What the bridge tells a session, once, about how something it asked for
/// ended: [summary] is the line the user sees, addressed to them, and
/// [guidance] is what the agent reads beside it.
class const SessionNotice({required final String summary, required final String guidance});
