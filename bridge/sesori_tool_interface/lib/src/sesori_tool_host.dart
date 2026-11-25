import "sesori_tool_store.dart";

/// What the bridge offers one tool group: its stored records, its toggle,
/// Sesori's messages into sessions, the sessions themselves and the user's
/// Allow. A group receives it, or the parts its own classes need, through
/// its constructor.
abstract interface class SesoriToolHost() {
  /// The group's records.
  SesoriToolStore get store;

  /// Whether the user has the group on. While it is off, sessions are not
  /// offered its tools, so the group should pause work it does on its own.
  bool get enabled;

  /// [enabled]'s new value each time it changes.
  Stream<bool> get enabledChanges;

  /// Sends Sesori's message into [sessionId] once [timing] allows: [summary]
  /// is the line the user sees, and [guidance] what the agent reads beside
  /// it. Completes once it is sent, skipped or dropped; never throws. A
  /// notice still waiting when the bridge stops ends as dropped, possibly
  /// after the group's `dispose`.
  ///
  /// [claim], when given, runs right before the send, with nothing else
  /// reaching the session in between. Returning false sends nothing
  /// ([SesoriToolNoticeOutcome.claimLost]). Writing the group's own state in
  /// the claim means a crash right after it loses that one message and never
  /// sends it twice.
  Future<SesoriToolNoticeOutcome> deliverNotice({
    required String sessionId,
    required String summary,
    required String guidance,
    required SesoriToolNoticeTiming timing,
    required Future<bool> Function()? claim,
  });

  /// The sessions among [sessionIds] that are stored, by id. Unknown ids
  /// are absent.
  Future<Map<String, SesoriToolSession>> sessions({required Set<String> sessionIds});

  /// Asks the user to allow a change [sessionId]'s agent asked for: [title]
  /// names the request and [body] is the Markdown the user approves. It
  /// shows on the session's root. Completes once the request is shown, or
  /// at once when it needs no card: the session approves everything, or no
  /// answer can come.
  ///
  /// The request lives in memory only: once the bridge begins to stop it
  /// ends as [SesoriToolApprovalOutcome.dropped], and the group applies
  /// nothing.
  Future<SesoriToolApproval> requestApproval({
    required String sessionId,
    required String title,
    required String body,
  });
}

/// When a notice may reach a session whose agent is working.
enum SesoriToolNoticeTiming() {
  /// Into the running turn on a harness that steers, after the turn
  /// otherwise.
  derived,

  /// Only once the turn has ended, on every harness.
  afterTurn,
}

/// How a [SesoriToolHost.deliverNotice] ended.
enum SesoriToolNoticeOutcome() {
  sent,

  /// The session was archived or deleted, before or while the notice waited.
  skippedInactive,

  /// The claim failed right before the send, so nothing was sent.
  claimLost,

  /// The send failed, or the bridge shut down while the notice waited.
  dropped,
}

/// A stored Sesori session, as a tool group sees it.
final class const SesoriToolSession({
  /// The root of the session's family: the session itself, or the one its
  /// sub-agent chain started from.
  required final String rootSessionId,

  /// Where the session's agent works: its worktree, or its project folder.
  required final String workingDirectory,
  required final bool archived,
});

/// How a [SesoriToolHost.requestApproval] began.
sealed class const SesoriToolApproval();

/// Allowed with nothing shown: the session approves everything.
final class const SesoriToolApprovalAllowed() extends SesoriToolApproval;

/// Not shown, and no answer will come: the bridge is stopping, or the
/// session is gone.
final class const SesoriToolApprovalDropped() extends SesoriToolApproval;

/// Shown to the user; [answer] completes once they answer it, or once the
/// bridge begins to stop.
final class const SesoriToolApprovalShown({required final Future<SesoriToolApprovalOutcome> answer})
    extends SesoriToolApproval;

enum SesoriToolApprovalOutcome() {
  allowed,
  rejected,

  /// No answer will come: the bridge stopped, or the session is gone.
  dropped,
}
