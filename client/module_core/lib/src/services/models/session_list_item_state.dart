typedef SessionListItemState = ({bool unseen, int? lastUserActivityAt});

int? latestUserActivityAt({required int? first, required int? second}) {
  if (first == null) return second;
  if (second == null) return first;
  return first > second ? first : second;
}
