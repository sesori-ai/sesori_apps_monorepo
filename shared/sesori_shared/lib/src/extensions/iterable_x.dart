import "package:collection/collection.dart";

extension IterableExtensions<T> on Iterable<T> {
  OUT reduceSafe<OUT>({
    required OUT Function(OUT aggregator, T e) combine,
    required OUT initialValue,
  }) {
    final Iterator<T> iterator = this.iterator;
    OUT aggregator = initialValue;

    while (iterator.moveNext()) {
      aggregator = combine(aggregator, iterator.current);
    }
    return aggregator;
  }

  // ignore: no_slop_linter/prefer_required_named_parameters, the single argument is the predicate
  (UnmodifiableListView<T>, UnmodifiableListView<T>) partition(
    bool Function(T item) condition,
  ) {
    final matching = <T>[];
    final nonMatching = <T>[];

    forEach(
      (element) => (condition(element) ? matching : nonMatching).add(element),
    );
    return (matching.toUnmodifiableList(), nonMatching.toUnmodifiableList());
  }

  UnmodifiableListView<T> toUnmodifiableList() => UnmodifiableListView(this);
}
