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

    group("toUnmodifiableList", () {
      test("returns UnmodifiableListView", () {
        final result = [1, 2, 3].toUnmodifiableList();
        expect(result, isA<UnmodifiableListView<int>>());
        expect(result, [1, 2, 3]);
      });
    });
  });
}
