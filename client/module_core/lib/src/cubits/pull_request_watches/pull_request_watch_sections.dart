import "package:sesori_shared/sesori_shared.dart";

import "../../services/models/pull_request_watch_stage.dart";
import "pull_request_watch_list_state.dart";

/// One group's rows, as the list shows them.
final class const PullRequestWatchSection({
  /// The stage the group gathers, which orders the groups.
  required final PullRequestWatchStage group,
  required final List<PullRequestWatchListItem> watches,
});

/// The list's rows under their groups, only [sessionId]'s when it is set.
///
/// While a list stays open it passes the sections it [shown] last: a row
/// keeps its group and place and only its content changes, so nothing moves
/// under the user's finger. A row that ended leaves; a new one joins the end
/// of its status's group. With nothing shown yet, every row joins its
/// status's group: open ones by repository and number, merged ones newest
/// first.
List<PullRequestWatchSection> arrangePullRequestWatches({
  required List<PullRequestWatchListItem> watches,
  required String? sessionId,
  required List<PullRequestWatchSection>? shown,
}) {
  final current = {
    for (final item in watches)
      if (sessionId == null || item.sessionId == sessionId) item.key: item,
  };
  final placed = {for (final group in PullRequestWatchStage.values) group: <PullRequestWatchKey>[]};
  for (final section in shown ?? const <PullRequestWatchSection>[]) {
    for (final item in section.watches) {
      if (current.containsKey(item.key)) placed[section.group]?.add(item.key);
    }
  }
  final placedKeys = {for (final keys in placed.values) ...keys};
  final arrivals = [
    for (final item in current.values)
      if (!placedKeys.contains(item.key)) item,
  ]..sort(_listOrder);
  for (final item in arrivals) {
    placed[PullRequestWatchStage.of(status: item.watch.status)]?.add(item.key);
  }
  return [
    for (final MapEntry(key: group, value: keys) in placed.entries)
      if (keys.isNotEmpty)
        PullRequestWatchSection(
          group: group,
          watches: [
            for (final key in keys) ?current[key],
          ],
        ),
  ];
}

int _listOrder(PullRequestWatchListItem a, PullRequestWatchListItem b) {
  if ((a.watch.status, b.watch.status)
      case (
        PullRequestWatchStatusMerged(mergedAt: final aMergedAt),
        PullRequestWatchStatusMerged(mergedAt: final bMergedAt),
      )
      when aMergedAt != bMergedAt) {
    return bMergedAt.compareTo(aMergedAt);
  }
  final byRepository = a.watch.repository.compareTo(b.watch.repository);
  if (byRepository != 0) return byRepository;
  final byNumber = a.watch.number.compareTo(b.watch.number);
  return byNumber != 0 ? byNumber : a.sessionId.compareTo(b.sessionId);
}
