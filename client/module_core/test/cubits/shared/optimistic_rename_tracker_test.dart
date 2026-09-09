import "package:sesori_dart_core/src/cubits/shared/optimistic_rename_tracker.dart";
import "package:test/test.dart";

void main() {
  group("OptimisticRenameTracker", () {
    test("shows the latest request and confirms the newest success", () {
      final tracker = OptimisticRenameTracker(confirmedValue: "original");

      tracker.begin(token: 1, value: "first");
      tracker.begin(token: 2, value: "second");
      expect(tracker.visibleValue, "second");
      expect(tracker.confirmedValue, "original");
      expect(tracker.isSettled, isFalse);

      tracker.complete(token: 2, value: "second", succeeded: true);
      tracker.complete(token: 1, value: "first", succeeded: true);

      expect(tracker.confirmedValue, "second", reason: "an older success must not overwrite a newer one");
      expect(tracker.visibleValue, "second");
      expect(tracker.isSettled, isTrue);
    });

    test("a failed visible rename falls back to the newest pending request", () {
      final tracker = OptimisticRenameTracker(confirmedValue: "original");

      tracker.begin(token: 1, value: "first");
      tracker.begin(token: 2, value: "second");
      tracker.complete(token: 2, value: "second", succeeded: false);

      expect(tracker.visibleValue, "first");
      expect(tracker.isSettled, isFalse);
    });

    test("a failed visible rename prefers a newer confirmation over an older pending request", () {
      final tracker = OptimisticRenameTracker(confirmedValue: "original");

      tracker.begin(token: 1, value: "first");
      tracker.begin(token: 2, value: "second");
      tracker.begin(token: 3, value: "third");
      tracker.complete(token: 2, value: "second", succeeded: true);
      tracker.complete(token: 3, value: "third", succeeded: false);

      expect(tracker.visibleValue, "second");
      expect(tracker.confirmedValue, "second");
    });

    test("a rejected rename of an entity without a name settles back to null", () {
      final tracker = OptimisticRenameTracker(confirmedValue: null);

      tracker.begin(token: 1, value: "first");
      tracker.complete(token: 1, value: "first", succeeded: false);

      expect(tracker.isSettled, isTrue);
      expect(tracker.confirmedValue, isNull);
    });
  });
}
