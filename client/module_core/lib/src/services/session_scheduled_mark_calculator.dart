import "package:sesori_shared/sesori_shared.dart";

import "models/pull_request_watch_stage.dart";
import "models/session_scheduled_mark.dart";

/// Decides what a session row says about Sesori waking the session again,
/// or the pull requests watched for it. A timed wake-up wins over watched
/// pull requests, and they win over the task that started the session.
/// Owns no state.
class const SessionScheduledMarkCalculator() {
  SessionScheduledMark mark({required Session session}) {
    final task = session.scheduledTask;
    final watches = session.pullRequestWatches;
    return switch (session.arming) {
      SessionArmingArmed(:final name, :final nextAt) => SessionScheduledMark.armed(name: name, nextAt: nextAt),
      SessionArmingNotArmed() ||
      SessionArmingUnreported() when watches.isNotEmpty => SessionScheduledMark.watchingPullRequests(
        lead: _lead(watches: watches),
        others: watches.length - 1,
      ),
      SessionArmingNotArmed() when task != null => SessionScheduledMark.fromTask(name: task.name),
      SessionArmingUnreported() when task != null => SessionScheduledMark.legacyTask(task: task),
      SessionArmingNotArmed() || SessionArmingUnreported() => const SessionScheduledMark.none(),
    };
  }

  /// The most urgent pull request, by [PullRequestWatchStage]'s order, To
  /// merge first; ties go to the lower number.
  SessionPullRequestWatch _lead({required List<SessionPullRequestWatch> watches}) {
    int rank(SessionPullRequestWatch watch) => PullRequestWatchStage.of(status: watch.status).index;
    return watches.reduce((lead, watch) {
      final order = rank(watch).compareTo(rank(lead));
      return order < 0 || (order == 0 && watch.number < lead.number) ? watch : lead;
    });
  }
}
