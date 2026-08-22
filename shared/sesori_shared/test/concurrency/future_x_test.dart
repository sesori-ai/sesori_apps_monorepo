import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("wait2", () {
    test("returns tuple of two resolved values", () async {
      final result = await wait2(
        Future.value(1),
        Future.value("two"),
      );
      expect(result, (1, "two"));
    });

    test("works with FutureOr (synchronous values)", () async {
      final result = await wait2(42, "hello");
      expect(result, (42, "hello"));
    });

    test("works with mixed FutureOr and Future", () async {
      final result = await wait2(1, Future.value("b"));
      expect(result, (1, "b"));
    });

    test("propagates error from first future", () {
      expect(
        () => wait2(Future<int>.error(Exception("a")), Future.value("b")),
        throwsA(isA<Exception>()),
      );
    });

    test("propagates error from second future", () {
      expect(
        () => wait2(Future.value(1), Future<String>.error(Exception("b"))),
        throwsA(isA<Exception>()),
      );
    });
  });
}
