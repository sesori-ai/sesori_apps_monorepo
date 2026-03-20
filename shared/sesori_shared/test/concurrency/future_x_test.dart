import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("future_x", () {
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

    group("wait3", () {
      test("returns tuple of three resolved values", () async {
        final result = await wait3(
          Future.value(1),
          Future.value("two"),
          Future.value(3.0),
        );
        expect(result, (1, "two", 3.0));
      });
    });

    group("wait4", () {
      test("returns tuple of four resolved values", () async {
        final result = await wait4(
          Future.value(1),
          Future.value("two"),
          Future.value(3.0),
          Future.value(true),
        );
        expect(result, (1, "two", 3.0, true));
      });
    });

    group("wait5", () {
      test("returns tuple of five resolved values", () async {
        final result = await wait5(
          Future.value(1),
          Future.value("two"),
          Future.value(3.0),
          Future.value(true),
          Future.value("five"),
        );
        expect(result, (1, "two", 3.0, true, "five"));
      });
    });

    group("FutureX.requireType", () {
      test("returns value when type matches", () async {
        final Future<num> future = Future.value(42);
        final result = await future.requireType<int>();
        expect(result, 42);
        expect(result, isA<int>());
      });

      test("throws when type does not match", () {
        final Future<num> future = Future.value(3.14);
        expect(
          () => future.requireType<int>(),
          throwsA(isA<Exception>()),
        );
      });

      test("passes through exact type match", () async {
        final Future<String> future = Future.value("hello");
        final result = await future.requireType<String>();
        expect(result, "hello");
      });
    });
  });
}
