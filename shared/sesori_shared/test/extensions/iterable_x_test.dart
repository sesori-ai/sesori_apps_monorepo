import "dart:collection";

import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("IterableExtensions", () {
    group("reduceSafe", () {
      test("reduces with initial value", () {
        final result = [1, 2, 3].reduceSafe(
          combine: (acc, e) => acc + e,
          initialValue: 0,
        );
        expect(result, 6);
      });

      test("returns initialValue for empty iterable", () {
        final result = <int>[].reduceSafe(
          combine: (acc, e) => acc + e,
          initialValue: 10,
        );
        expect(result, 10);
      });

      test("works with different aggregator type", () {
        final result = ["a", "bb", "ccc"].reduceSafe(
          combine: (acc, e) => acc + e.length,
          initialValue: 0,
        );
        expect(result, 6);
      });
    });

    group("withoutLast", () {
      test("removes last element", () {
        expect([1, 2, 3].withoutLast(), [1, 2]);
      });

      test("returns empty for single-element list", () {
        expect([1].withoutLast().toList(), isEmpty);
      });

      test("returns empty for empty list", () {
        expect(<int>[].withoutLast().toList(), isEmpty);
      });
    });

    group("replaceLast", () {
      test("replaces the last element", () {
        expect([1, 2, 3].replaceLast(99), [1, 2, 99]);
      });

      test("works with single element", () {
        expect([1].replaceLast(42), [42]);
      });

      test("throws on empty list", () {
        expect(() => <int>[].replaceLast(1), throwsA(isA<Exception>()));
      });
    });

    group("plusElementIf", () {
      test("appends when condition is true", () {
        final result = [1, 2].plusElementIf(newElement: 3, condition: true);
        expect(result, [1, 2, 3]);
      });

      test("does not append when condition is false", () {
        final result = [1, 2].plusElementIf(newElement: 3, condition: false);
        expect(result, [1, 2]);
      });
    });

    group("asyncMap", () {
      test("maps elements asynchronously", () async {
        final result = await [1, 2, 3].asyncMap((e) async => e * 2);
        expect(result, [2, 4, 6]);
      });

      test("returns empty for empty iterable", () async {
        final result = await <int>[].asyncMap((e) async => e);
        expect(result, isEmpty);
      });
    });

    group("partition", () {
      test("splits into matching and non-matching", () {
        final (evens, odds) = [1, 2, 3, 4, 5].partition((e) => e.isEven);
        expect(evens, [2, 4]);
        expect(odds, [1, 3, 5]);
      });

      test("returns unmodifiable lists", () {
        final (matching, nonMatching) = [1, 2].partition((e) => e > 0);
        expect(matching, isA<UnmodifiableListView<int>>());
        expect(nonMatching, isA<UnmodifiableListView<int>>());
      });

      test("handles all matching", () {
        final (matching, nonMatching) = [2, 4, 6].partition((e) => e.isEven);
        expect(matching, [2, 4, 6]);
        expect(nonMatching, isEmpty);
      });

      test("handles none matching", () {
        final (matching, nonMatching) = [1, 3, 5].partition((e) => e.isEven);
        expect(matching, isEmpty);
        expect(nonMatching, [1, 3, 5]);
      });

      test("handles empty iterable", () {
        final (matching, nonMatching) = <int>[].partition((e) => e.isEven);
        expect(matching, isEmpty);
        expect(nonMatching, isEmpty);
      });
    });

    group("splitAt", () {
      test("splits at given index", () {
        final (left, right) = [1, 2, 3, 4, 5].splitAt(3);
        expect(left, [1, 2, 3]);
        expect(right, [4, 5]);
      });

      test("split at 0 gives empty left", () {
        final (left, right) = [1, 2, 3].splitAt(0);
        expect(left, isEmpty);
        expect(right, [1, 2, 3]);
      });

      test("split at length gives empty right", () {
        final (left, right) = [1, 2, 3].splitAt(3);
        expect(left, [1, 2, 3]);
        expect(right, isEmpty);
      });
    });

    group("toUnmodifiableList", () {
      test("returns UnmodifiableListView", () {
        final result = [1, 2, 3].toUnmodifiableList();
        expect(result, isA<UnmodifiableListView<int>>());
        expect(result, [1, 2, 3]);
      });
    });

    group("toUnmodifiableSet", () {
      test("returns UnmodifiableSetView with deduplication", () {
        final result = [1, 2, 2, 3, 3].toUnmodifiableSet();
        expect(result, {1, 2, 3});
      });
    });

    group("sortedMultiple", () {
      test("sorts by primary comparator", () {
        final result = [3, 1, 2].sortedMultiple([(a, b) => a.compareTo(b)]);
        expect(result.toList(), [1, 2, 3]);
      });

      test("falls through to secondary comparator on tie", () {
        final items = [
          (priority: 1, name: "b"),
          (priority: 1, name: "a"),
          (priority: 0, name: "c"),
        ];
        final result = items.sortedMultiple([
          (a, b) => a.priority.compareTo(b.priority),
          (a, b) => a.name.compareTo(b.name),
        ]);

        expect(result.map((e) => e.name).toList(), ["c", "a", "b"]);
      });

      test("returns same order for equal elements", () {
        final result = [1, 1, 1].sortedMultiple([(a, b) => a.compareTo(b)]);
        expect(result.toList(), [1, 1, 1]);
      });
    });
  });
}
