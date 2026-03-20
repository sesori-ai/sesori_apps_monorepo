import "dart:async";

import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/src/concurrency/impl/concurrent_cache.dart";

/// Short TTL/grace for fast tests. Delays use 2x margin for CI tolerance.
const _ttl = Duration(milliseconds: 50);
const _grace = Duration(milliseconds: 50);
const _pastTtl = Duration(milliseconds: 120);
const _pastTtlAndGrace = Duration(milliseconds: 200);

void main() {
  group("ConcurrentCache", () {
    group("cache hit and TTL expiry", () {
      test("first call fetches from source, subsequent calls return cached value", () async {
        var fetchCount = 0;
        final cache = ConcurrentCache<String>(
          compute: (_) async {
            fetchCount++;
            return "value_$fetchCount";
          },
          valid: const Duration(seconds: 10),
          grace: const Duration(seconds: 5),
        );

        final result1 = await cache.getOrFetch();
        expect(result1, equals("value_1"));
        expect(fetchCount, equals(1));

        final result2 = await cache.getOrFetch();
        expect(result2, equals("value_1"));
        expect(fetchCount, equals(1), reason: "should not fetch again within TTL");
      });

      test("after TTL expires, next call re-fetches", () async {
        var fetchCount = 0;
        final cache = ConcurrentCache<String>(
          compute: (_) async {
            fetchCount++;
            return "value_$fetchCount";
          },
          valid: _ttl,
          grace: _grace,
        );

        final result1 = await cache.getOrFetch();
        expect(result1, equals("value_1"));

        await Future<void>.delayed(_pastTtlAndGrace);

        final result2 = await cache.getOrFetch();
        expect(result2, equals("value_2"));
        expect(fetchCount, equals(2));
      });
    });

    group("grace period behavior", () {
      test("during grace period, returns stale value while triggering background re-fetch", () async {
        var fetchCount = 0;
        final cache = ConcurrentCache<String>(
          compute: (_) async {
            fetchCount++;
            return "value_$fetchCount";
          },
          valid: _ttl,
          grace: const Duration(milliseconds: 500),
        );

        final result1 = await cache.getOrFetch();
        expect(result1, equals("value_1"));
        expect(fetchCount, equals(1));

        // Past TTL but well within long grace
        await Future<void>.delayed(_pastTtl);

        final result2 = await cache.getOrFetch();
        expect(result2, equals("value_1"), reason: "returns stale during grace");
        expect(fetchCount, equals(2), reason: "background fetch triggered");
      });

      test("after grace expires, returns fresh fetch result", () async {
        var fetchCount = 0;
        final cache = ConcurrentCache<String>(
          compute: (_) async {
            fetchCount++;
            return "value_$fetchCount";
          },
          valid: _ttl,
          grace: _grace,
        );

        final result1 = await cache.getOrFetch();
        expect(result1, equals("value_1"));

        await Future<void>.delayed(_pastTtlAndGrace);

        final result2 = await cache.getOrFetch();
        expect(result2, equals("value_2"));
        expect(fetchCount, equals(2));
      });
    });

    group("force fetch and invalidate", () {
      test("forceFetch: true bypasses cache", () async {
        var fetchCount = 0;
        final cache = ConcurrentCache<String>(
          compute: (_) async {
            fetchCount++;
            return "value_$fetchCount";
          },
          valid: const Duration(seconds: 10),
          grace: const Duration(seconds: 5),
        );

        final result1 = await cache.getOrFetch();
        expect(result1, equals("value_1"));

        final result2 = await cache.getOrFetch(forceFetch: true);
        expect(result2, equals("value_2"));

        final result3 = await cache.getOrFetch();
        expect(result3, equals("value_2"), reason: "should use newly cached value");
        expect(fetchCount, equals(2));
      });

      test("invalidate() clears cache, next call re-fetches", () async {
        var fetchCount = 0;
        final cache = ConcurrentCache<String>(
          compute: (_) async {
            fetchCount++;
            return "value_$fetchCount";
          },
          valid: const Duration(seconds: 10),
          grace: const Duration(seconds: 5),
        );

        final result1 = await cache.getOrFetch();
        expect(result1, equals("value_1"));

        cache.invalidate();

        final result2 = await cache.getOrFetch();
        expect(result2, equals("value_2"));
        expect(fetchCount, equals(2));
      });
    });

    group("concurrent deduplication", () {
      test("concurrent requests during fetch get same result (deduplication)", () async {
        var fetchCount = 0;
        final fetchGate = Completer<void>();
        final cache = ConcurrentCache<String>(
          compute: (_) async {
            fetchCount++;
            await fetchGate.future;
            return "value_$fetchCount";
          },
          valid: const Duration(seconds: 10),
          grace: const Duration(seconds: 5),
        );

        final futures = <Future<String>>[
          cache.getOrFetch(),
          cache.getOrFetch(),
          cache.getOrFetch(),
        ];

        fetchGate.complete();
        final results = await Future.wait(futures);

        expect(results, equals(["value_1", "value_1", "value_1"]));
        expect(fetchCount, equals(1));
      });

      test("concurrent requests after invalidate re-deduplicate", () async {
        var fetchCount = 0;
        var fetchGate = Completer<void>();
        final cache = ConcurrentCache<String>(
          compute: (_) async {
            fetchCount++;
            await fetchGate.future;
            return "value_$fetchCount";
          },
          valid: const Duration(seconds: 10),
          grace: const Duration(seconds: 5),
        );

        fetchGate.complete();
        final result1 = await cache.getOrFetch();
        expect(result1, equals("value_1"));

        cache.invalidate();
        fetchGate = Completer<void>();

        final futures = <Future<String>>[
          cache.getOrFetch(),
          cache.getOrFetch(),
        ];

        fetchGate.complete();
        final results = await Future.wait(futures);

        expect(results, equals(["value_2", "value_2"]));
        expect(fetchCount, equals(2));
      });
    });

    group("previous value passing", () {
      test("compute function receives previous cached value", () async {
        final previousValues = <String?>[];
        final cache = ConcurrentCache<String>(
          compute: (previous) async {
            previousValues.add(previous);
            return "new_${previous ?? "initial"}";
          },
          valid: _ttl,
          grace: _grace,
        );

        final result1 = await cache.getOrFetch();
        expect(result1, equals("new_initial"));
        expect(previousValues, equals([null]));

        await Future<void>.delayed(_pastTtlAndGrace);

        final result2 = await cache.getOrFetch();
        expect(result2, equals("new_new_initial"));
        expect(previousValues, equals([null, "new_initial"]));
      });
    });
  });
}
