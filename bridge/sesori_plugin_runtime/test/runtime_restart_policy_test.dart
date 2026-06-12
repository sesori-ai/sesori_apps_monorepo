import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

void main() {
  group("RuntimeRestartPolicy", () {
    test("disabled() is const and is the disabled variant", () {
      const policy = RuntimeRestartPolicy.disabled();
      expect(policy, isA<DisabledRestartPolicy>());
      expect(identical(const RuntimeRestartPolicy.disabled(), const RuntimeRestartPolicy.disabled()), isTrue);
    });

    BoundedRestartPolicy bounded({
      int maxAttempts = 3,
      Duration initialBackoff = const Duration(milliseconds: 200),
      Duration maxBackoff = const Duration(seconds: 2),
      double backoffMultiplier = 2.0,
    }) {
      return RuntimeRestartPolicy.bounded(
        maxAttempts: maxAttempts,
        initialBackoff: initialBackoff,
        maxBackoff: maxBackoff,
        backoffMultiplier: backoffMultiplier,
        portReleaseTimeout: const Duration(seconds: 5),
        portReleasePollInterval: const Duration(milliseconds: 250),
      ) as BoundedRestartPolicy;
    }

    test("backoffFor grows geometrically from the first attempt", () {
      final policy = bounded();
      expect(policy.backoffFor(1), equals(const Duration(milliseconds: 200)));
      expect(policy.backoffFor(2), equals(const Duration(milliseconds: 400)));
      expect(policy.backoffFor(3), equals(const Duration(milliseconds: 800)));
    });

    test("backoffFor is capped at maxBackoff", () {
      final policy = bounded(maxBackoff: const Duration(milliseconds: 500));
      expect(policy.backoffFor(3), equals(const Duration(milliseconds: 500)));
      expect(policy.backoffFor(50), equals(const Duration(milliseconds: 500)));
    });

    test("a multiplier of 1.0 keeps the backoff flat", () {
      final policy = bounded(backoffMultiplier: 1.0);
      expect(policy.backoffFor(1), equals(const Duration(milliseconds: 200)));
      expect(policy.backoffFor(5), equals(const Duration(milliseconds: 200)));
    });

    test("rejects invalid parameters", () {
      expect(() => bounded(maxAttempts: 0), throwsA(isA<AssertionError>()));
      expect(
        () => RuntimeRestartPolicy.bounded(
          maxAttempts: 1,
          initialBackoff: const Duration(seconds: 1),
          maxBackoff: const Duration(milliseconds: 500),
          portReleaseTimeout: const Duration(seconds: 5),
          portReleasePollInterval: const Duration(milliseconds: 250),
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => RuntimeRestartPolicy.bounded(
          maxAttempts: 1,
          initialBackoff: const Duration(milliseconds: 200),
          maxBackoff: const Duration(seconds: 2),
          portReleaseTimeout: const Duration(seconds: 5),
          portReleasePollInterval: Duration.zero,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
