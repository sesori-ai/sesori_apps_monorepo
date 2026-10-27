/// The items whose title contains every whitespace-separated word of [query],
/// ignoring case, in their original order. A blank query keeps every item; an
/// item without a title matches only a blank query.
List<T> matchTitles<T>({
  required Iterable<T> items,
  required String? Function(T item) titleOf,
  required String query,
}) => matchTexts(items: items, textsOf: (item) => [titleOf(item)], query: query);

/// [matchTitles] over several texts per item: each word of [query] must occur
/// in one of the item's texts, not necessarily the same one, so "app fix"
/// finds the title "Fix the header" in the project "app". A null text never
/// matches.
List<T> matchTexts<T>({
  required Iterable<T> items,
  required List<String?> Function(T item) textsOf,
  required String query,
}) {
  final words = _words(query: query);
  if (words.isEmpty) return items.toList();
  return items.where((item) {
    final texts = [for (final text in textsOf(item)) ?text?.toLowerCase()];
    return words.every((word) => texts.any((text) => text.contains(word)));
  }).toList();
}

/// Where [query]'s words occur in [title], ignoring case: sorted, merged
/// `[start, end)` ranges to highlight. Empty for a blank query.
List<({int start, int end})> titleMatchRanges({required String title, required String query}) {
  final lower = title.toLowerCase();
  // ponytail: assumes lowercasing keeps the title's length, true outside rare Unicode.
  if (lower.length != title.length) return const [];
  final marked = List.filled(title.length, false);
  for (final word in _words(query: query)) {
    for (var at = lower.indexOf(word); at >= 0; at = lower.indexOf(word, at + 1)) {
      marked.fillRange(at, at + word.length, true);
    }
  }
  final ranges = <({int start, int end})>[];
  for (var index = 0; index < marked.length; index++) {
    if (!marked[index]) continue;
    final start = index;
    while (index < marked.length && marked[index]) {
      index++;
    }
    ranges.add((start: start, end: index));
  }
  return ranges;
}

List<String> _words({required String query}) =>
    query.toLowerCase().split(RegExp(r"\s+")).where((word) => word.isNotEmpty).toList();
