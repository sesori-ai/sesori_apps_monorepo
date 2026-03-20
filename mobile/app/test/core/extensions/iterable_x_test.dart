import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/src/extensions/iterable_x.dart";

void main() {
  group("IterableExtensions.reduceSafe", () {
    test("returns initial value for empty iterable", () {
      final list = <int>[];
      final result = list.reduceSafe(
        combine: (acc, e) => acc + e,
        initialValue: 0,
      );

      expect(result, equals(0));
    });

    test("reduces non-empty iterable with initial value", () {
      final list = [1, 2, 3, 4];
      final result = list.reduceSafe(
        combine: (acc, e) => acc + e,
        initialValue: 0,
      );

      expect(result, equals(10));
    });

    test("reduces with different initial value", () {
      final list = [1, 2, 3];
      final result = list.reduceSafe(
        combine: (acc, e) => acc + e,
        initialValue: 10,
      );

      expect(result, equals(16));
    });

    test("reduces with multiplication", () {
      final list = [2, 3, 4];
      final result = list.reduceSafe(
        combine: (acc, e) => acc * e,
        initialValue: 1,
      );

      expect(result, equals(24));
    });

    test("reduces single element", () {
      final list = [5];
      final result = list.reduceSafe(
        combine: (acc, e) => acc + e,
        initialValue: 10,
      );

      expect(result, equals(15));
    });
  });

  group("IterableExtensions.partition", () {
    test("partitions list into matching and non-matching", () {
      final list = [1, 2, 3, 4, 5];
      final (matching, nonMatching) = list.partition((x) => x.isEven);

      expect(matching.toList(), equals([2, 4]));
      expect(nonMatching.toList(), equals([1, 3, 5]));
    });

    test("returns all in matching when all match", () {
      final list = [2, 4, 6];
      final (matching, nonMatching) = list.partition((x) => x.isEven);

      expect(matching.toList(), equals([2, 4, 6]));
      expect(nonMatching.toList(), isEmpty);
    });

    test("returns all in non-matching when none match", () {
      final list = [1, 3, 5];
      final (matching, nonMatching) = list.partition((x) => x.isEven);

      expect(matching.toList(), isEmpty);
      expect(nonMatching.toList(), equals([1, 3, 5]));
    });

    test("partitions empty list", () {
      final list = <int>[];
      final (matching, nonMatching) = list.partition((x) => x.isEven);

      expect(matching.toList(), isEmpty);
      expect(nonMatching.toList(), isEmpty);
    });

    test("partitions strings by length", () {
      final list = ["a", "bb", "ccc", "dd"];
      final (matching, nonMatching) = list.partition((s) => s.length > 1);

      expect(matching.toList(), equals(["bb", "ccc", "dd"]));
      expect(nonMatching.toList(), equals(["a"]));
    });
  });

  group("IterableExtensions.asyncMap", () {
    test("maps elements asynchronously", () async {
      final list = [1, 2, 3];
      final result = await list.asyncMap((x) async => x * 2);

      expect(result.toList(), equals([2, 4, 6]));
    });

    test("handles empty iterable", () async {
      final list = <int>[];
      final result = await list.asyncMap((x) async => x * 2);

      expect(result.toList(), isEmpty);
    });

    test("maps with async operations", () async {
      final list = ["a", "b", "c"];
      final result = await list.asyncMap((x) async {
        await Future<void>.delayed(Duration.zero);
        return x.toUpperCase();
      });

      expect(result.toList(), equals(["A", "B", "C"]));
    });

    test("maps single element", () async {
      final list = [42];
      final result = await list.asyncMap((x) async => x + 1);

      expect(result.toList(), equals([43]));
    });

    test("preserves order of results", () async {
      final list = [3, 1, 2];
      final result = await list.asyncMap((x) async => x * 10);

      expect(result.toList(), equals([30, 10, 20]));
    });
  });

  group("IterableExtensions.sortedMultiple", () {
    test("sorts by first comparator", () {
      final list = [
        (name: "Alice", age: 30),
        (name: "Bob", age: 25),
        (name: "Charlie", age: 35),
      ];

      final result = list.sortedMultiple([
        (a, b) => a.name.compareTo(b.name),
      ]);

      expect(
        result.map((r) => r.name).toList(),
        equals(["Alice", "Bob", "Charlie"]),
      );
    });

    test("sorts by multiple comparators in order", () {
      final list = [
        (name: "Alice", age: 30),
        (name: "Bob", age: 25),
        (name: "Alice", age: 25),
      ];

      final result = list.sortedMultiple([
        (a, b) => a.name.compareTo(b.name),
        (a, b) => a.age.compareTo(b.age),
      ]);

      expect(
        result.map((r) => (r.name, r.age)).toList(),
        equals([
          ("Alice", 25),
          ("Alice", 30),
          ("Bob", 25),
        ]),
      );
    });

    test("uses second comparator when first returns 0", () {
      final list = [
        (x: 1, y: 2),
        (x: 1, y: 1),
        (x: 2, y: 1),
      ];

      final result = list.sortedMultiple([
        (a, b) => a.x.compareTo(b.x),
        (a, b) => a.y.compareTo(b.y),
      ]);

      expect(
        result.map((r) => (r.x, r.y)).toList(),
        equals([
          (1, 1),
          (1, 2),
          (2, 1),
        ]),
      );
    });

    test("sorts empty list", () {
      final list = <(int, int)>[];
      final result = list.sortedMultiple([
        (a, b) => a.$1.compareTo(b.$1),
      ]);

      expect(result.toList(), isEmpty);
    });

    test("sorts single element", () {
      final list = [(1, 2)];
      final result = list.sortedMultiple([
        (a, b) => a.$1.compareTo(b.$1),
      ]);

      expect(result.toList(), equals([(1, 2)]));
    });

    test("handles empty comparators list", () {
      final list = [3, 1, 2];
      final result = list.sortedMultiple([]);

      expect(result.toList(), equals([3, 1, 2]));
    });
  });
}
