import "dart:async";

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

  Iterable<T> withoutLast() => length > 0 ? take(length - 1) : this;

  List<T> replaceLast(T newLast) {
    if (length == 0) throw Exception("Cannot call replaceLast on empty list");
    return [...withoutLast(), newLast];
  }

  Iterable<T> plusElementIf({required T newElement, required bool condition}) =>
      condition ? [...this, newElement] : this;

  Future<Iterable<Y>> asyncMap<Y>(Future<Y> Function(T e) mapper) => Future.wait(map(mapper));

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

  (UnmodifiableListView<T>, UnmodifiableListView<T>) splitAt(int index) =>
      (take(index).toUnmodifiableList(), skip(index).toUnmodifiableList());

  UnmodifiableListView<T> toUnmodifiableList() => UnmodifiableListView(this);

  UnmodifiableSetView<T> toUnmodifiableSet() => UnmodifiableSetView(toSet());

  Iterable<T> sortedMultiple(Iterable<int Function(T a, T b)> compare) => sorted((a, b) {
    final comparatorsIterator = compare.iterator;
    while (comparatorsIterator.moveNext()) {
      final comparator = comparatorsIterator.current;
      final result = comparator(a, b);
      if (result != 0) return result;
    }
    return 0;
  });
}
