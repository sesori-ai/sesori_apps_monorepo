import "dart:async";

import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("ConcurrentCache", () {
    group("basic caching", () {
      test("first call invokes compute", () async {
        var computeCount = 0;
        final cache = ConcurrentCache<String>(
          compute: (_) async {
            computeCount++;
            return "value-$computeCount";
          },
          valid: const Duration(days: 1),
          grace: null,
        );

        final result = await cache.getOrFetch();
        expect(result, "value-1");
        expect(computeCount, 1);
      });

      test("second call within TTL returns cached value", () async {
        var computeCount = 0;
        final cache = ConcurrentCache<String>(
          compute: (_) async {
            computeCount++;
            return "value-$computeCount";
          },
          valid: const Duration(days: 1),
          grace: null,
        );

        final first = await cache.getOrFetch();
        final second = await cache.getOrFetch();

        expect(first, "value-1");
        expect(second, "value-1");
        expect(computeCount, 1);
      });

      test("compute receives previous cached value", () async {
        String? receivedOldValue;
        var computeCount = 0;

        final cache = ConcurrentCache<String>(
          compute: (old) async {
            receivedOldValue = old;
            computeCount++;
            return "v$computeCount";
          },
          valid: const Duration(milliseconds: 1),
          grace: null,
        );

        // First call — no previous value
        await cache.getOrFetch();
        expect(receivedOldValue, isNull);

        // Wait for expiry
        await Future<void>.delayed(const Duration(milliseconds: 5));

        // Second call — receives previous cached value
        await cache.getOrFetch();
        expect(receivedOldValue, "v1");
      });
    });

    group("expiry", () {
      test("expired cache triggers recompute", () async {
        var computeCount = 0;
        final cache = ConcurrentCache<String>(
          compute: (_) async {
            computeCount++;
            return "v$computeCount";
          },
          valid: const Duration(milliseconds: 1),
          grace: null,
        );

        await cache.getOrFetch();
        expect(computeCount, 1);

        // Wait for the TTL to expire
        await Future<void>.delayed(const Duration(milliseconds: 5));

        final result = await cache.getOrFetch();
        expect(result, "v2");
        expect(computeCount, 2);
      });
    });

    group("forceFetch", () {
      test("bypasses cache and recomputes", () async {
        var computeCount = 0;
        final cache = ConcurrentCache<String>(
          compute: (_) async {
            computeCount++;
            return "v$computeCount";
          },
          valid: const Duration(days: 1),
          grace: null,
        );

        await cache.getOrFetch();
        expect(computeCount, 1);

        final result = await cache.getOrFetch(forceFetch: true);
        expect(result, "v2");
        expect(computeCount, 2);
      });
    });

    group("invalidate", () {
      test("clears cache so next getOrFetch recomputes", () async {
        var computeCount = 0;
        final cache = ConcurrentCache<String>(
          compute: (_) async {
            computeCount++;
            return "v$computeCount";
          },
          valid: const Duration(days: 1),
          grace: null,
        );

        await cache.getOrFetch();
        expect(computeCount, 1);

        cache.invalidate();

        final result = await cache.getOrFetch();
        expect(result, "v2");
        expect(computeCount, 2);
      });
    });

    group("concurrent access", () {
      test("concurrent calls share the same fetch future", () async {
        var computeCount = 0;
        final gate = Completer<void>();

        final cache = ConcurrentCache<String>(
          compute: (_) async {
            computeCount++;
            await gate.future;
            return "v$computeCount";
          },
          valid: const Duration(days: 1),
          grace: null,
        );

        // Start two fetches concurrently
        final f1 = cache.getOrFetch();
        final f2 = cache.getOrFetch();

        gate.complete();

        final r1 = await f1;
        final r2 = await f2;

        // Both should get the same value from one compute call
        expect(r1, "v1");
        expect(r2, "v1");
        expect(computeCount, 1);
      });

      test("concurrent calls after expiry share the same fetch", () async {
        var computeCount = 0;
        final gates = <Completer<void>>[];

        final cache = ConcurrentCache<String>(
          compute: (_) async {
            computeCount++;
            final gate = Completer<void>();
            gates.add(gate);
            await gate.future;
            return "v$computeCount";
          },
          valid: const Duration(milliseconds: 1),
          grace: null,
        );

        // First fetch
        final f0 = cache.getOrFetch();
        gates.first.complete();
        await f0;
        expect(computeCount, 1);

        // Wait for expiry
        await Future<void>.delayed(const Duration(milliseconds: 5));

        // Two concurrent fetches after expiry
        final f1 = cache.getOrFetch();
        final f2 = cache.getOrFetch();
        gates[1].complete();

        final r1 = await f1;
        final r2 = await f2;

        expect(r1, "v2");
        expect(r2, "v2");
        expect(computeCount, 2); // only one recompute, not two
      });
    });

    group("grace period", () {
      test("returns stale value during grace while recomputing", () async {
        var computeCount = 0;
        final gate = Completer<void>();

        final cache = ConcurrentCache<String>(
          compute: (_) async {
            computeCount++;
            if (computeCount > 1) await gate.future;
            return "v$computeCount";
          },
          valid: const Duration(milliseconds: 1),
          grace: const Duration(days: 1), // very long grace
        );

        // Populate cache
        final first = await cache.getOrFetch();
        expect(first, "v1");

        // Wait for TTL to expire (but within grace)
        await Future<void>.delayed(const Duration(milliseconds: 5));

        // This should return stale "v1" immediately because grace hasn't expired
        final stale = await cache.getOrFetch();
        expect(stale, "v1");
        // A background recompute was kicked off
        expect(computeCount, 2);

        // Let the recompute finish
        gate.complete();
        await Future<void>.delayed(const Duration(milliseconds: 5));

        // Now we should get the fresh value
        final fresh = await cache.getOrFetch();
        expect(fresh, "v2");
      });

      test("null grace waits for recompute on expiry", () async {
        var computeCount = 0;
        final gate = Completer<void>();

        final cache = ConcurrentCache<String>(
          compute: (_) async {
            computeCount++;
            if (computeCount > 1) await gate.future;
            return "v$computeCount";
          },
          valid: const Duration(milliseconds: 1),
          grace: null, // no grace
        );

        await cache.getOrFetch();
        await Future<void>.delayed(const Duration(milliseconds: 5));

        // This will block until the new compute finishes
        final futureResult = cache.getOrFetch();
        gate.complete();

        final result = await futureResult;
        expect(result, "v2");
      });
    });

    group("error handling", () {
      test("compute exception propagates to caller", () async {
        final cache = ConcurrentCache<String>(
          compute: (_) async => throw Exception("compute failed"),
          valid: const Duration(days: 1),
          grace: null,
        );

        expect(cache.getOrFetch, throwsA(isA<Exception>()));
      });

      test("failed compute clears the fetching future", () async {
        var callCount = 0;
        final cache = ConcurrentCache<String>(
          compute: (_) async {
            callCount++;
            if (callCount == 1) throw Exception("first fails");
            return "recovered";
          },
          valid: const Duration(days: 1),
          grace: null,
        );

        // First call fails
        try {
          await cache.getOrFetch();
        } on Exception {
          // expected
        }

        // Second call should retry (not stuck on old failed future)
        final result = await cache.getOrFetch();
        expect(result, "recovered");
        expect(callCount, 2);
      });
    });
  });
}
