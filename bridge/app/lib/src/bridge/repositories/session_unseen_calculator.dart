/// Computes whether a session has unseen changes from its three tracking
/// timestamps. Pure, stateless, shared by [SessionRepository] (per-session
/// enrichment), [ProjectRepository] (project aggregate), and
/// [SessionUnseenRepository] — none of which may depend on each other, so the
/// rule lives in one injectable collaborator.
///
/// A session is unseen when there has been activity strictly newer than the
/// later of "the user's last message" and "the last time the user saw it".
/// Nulls are treated as 0, so a row with no recorded activity (the baseline
/// for pre-existing sessions) is "seen".
class SessionUnseenCalculator {
  const SessionUnseenCalculator();

  bool isUnseen({
    required int? activity,
    required int? userMessage,
    required int? seen,
  }) {
    final activityAt = activity ?? 0;
    final lastEngaged = (userMessage ?? 0) > (seen ?? 0) ? (userMessage ?? 0) : (seen ?? 0);
    return activityAt > lastEngaged;
  }
}
