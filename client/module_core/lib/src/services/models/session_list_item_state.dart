typedef SessionListItemState = ({bool unseen, int? lastUserActivityAt});

/// A local optimistic write: the entry it replaced (null when there was none)
/// and the entry it wrote.
typedef LocalSessionUnseenWrite = ({SessionListItemState? previous, SessionListItemState written});

int? latestUserActivityAt({required int? first, required int? second}) {
  if (first == null) return second;
  if (second == null) return first;
  return first > second ? first : second;
}
