/// Where one query word matched inside a title: `start` inclusive, `end`
/// exclusive, in the title's code units.
// ponytail: indices come from the lower-cased title, which only differs in
// length for rare letters such as "İ"; a highlight there is shifted, not lost.
typedef TitleMatchRange = ({int start, int end});

/// An item whose title holds every word of a search query.
class const TitleMatch<T>({
  required final T item,

  /// The first match of each query word, sorted and non-overlapping.
  required final List<TitleMatchRange> ranges,
});

/// The items whose title contains every whitespace-separated word of [query],
/// ignoring case, in their original order. A blank query matches every item
/// with no ranges; an item without a title matches only a blank query.
List<TitleMatch<T>> matchTitles<T>({
  required Iterable<T> items,
  required String? Function(T item) titleOf,
  required String query,
}) {
  final words = query.toLowerCase().split(RegExp(r"\s+")).where((word) => word.isNotEmpty).toList();
  final matches = <TitleMatch<T>>[];
  for (final item in items) {
    if (words.isEmpty) {
      matches.add(TitleMatch(item: item, ranges: const []));
      continue;
    }
    final ranges = _rangesIn(title: titleOf(item)?.toLowerCase(), words: words);
    if (ranges != null) matches.add(TitleMatch(item: item, ranges: ranges));
  }
  return matches;
}

List<TitleMatchRange>? _rangesIn({required String? title, required List<String> words}) {
  if (title == null) return null;
  final ranges = <TitleMatchRange>[];
  for (final word in words) {
    final start = title.indexOf(word);
    if (start < 0) return null;
    ranges.add((start: start, end: start + word.length));
  }
  ranges.sort((a, b) => a.start.compareTo(b.start));
  // Words that overlap ("fix" and "fixes") highlight as one span.
  final merged = <TitleMatchRange>[];
  for (final range in ranges) {
    if (merged.isNotEmpty && range.start <= merged.last.end) {
      final last = merged.removeLast();
      merged.add((start: last.start, end: range.end > last.end ? range.end : last.end));
    } else {
      merged.add(range);
    }
  }
  return merged;
}
