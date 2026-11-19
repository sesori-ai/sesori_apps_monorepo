/// What the bridge tells a session, once, about how something it asked for
/// ended: [summary] is the line the user sees, addressed to them, and
/// [guidance] is what the agent reads beside it. [pageRequestId] names the
/// agent page the notice settles, so the user's line can reopen it.
class const SessionNotice({
  required final String summary,
  required final String guidance,
  required final String? pageRequestId,
});
