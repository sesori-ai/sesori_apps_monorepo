/// The items whose title contains every whitespace-separated word of [query],
/// ignoring case, in their original order. A blank query keeps every item; an
/// item without a title matches only a blank query.
List<T> matchTitles<T>({
  required Iterable<T> items,
  required String? Function(T item) titleOf,
  required String query,
}) {
  final words = query.toLowerCase().split(RegExp(r"\s+")).where((word) => word.isNotEmpty).toList();
  if (words.isEmpty) return items.toList();
  return items.where((item) {
    final title = titleOf(item)?.toLowerCase();
    return title != null && words.every(title.contains);
  }).toList();
}
