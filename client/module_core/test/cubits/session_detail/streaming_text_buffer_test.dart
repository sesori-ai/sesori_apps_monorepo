import "package:fake_async/fake_async.dart";
import "package:sesori_dart_core/src/cubits/session_detail/streaming_text_buffer.dart";
import "package:test/test.dart";

void main() {
  group("StreamingTextBuffer", () {
    test("snapshot is empty initially", () {
      final buffer = StreamingTextBuffer(onFlush: () {});
      expect(buffer.snapshot(), isEmpty);
      buffer.dispose();
    });

    test("appendDelta accumulates text for a part", () {
      final buffer = StreamingTextBuffer(onFlush: () {});
      buffer.appendDelta(partId: "p1", delta: "Hello", baseText: _noBase);
      buffer.appendDelta(partId: "p1", delta: " World", baseText: _noBase);
      expect(buffer.snapshot(), {"p1": "Hello World"});
      buffer.dispose();
    });

    test("appendDelta handles multiple parts independently", () {
      final buffer = StreamingTextBuffer(onFlush: () {});
      buffer.appendDelta(partId: "p1", delta: "a", baseText: _noBase);
      buffer.appendDelta(partId: "p2", delta: "b", baseText: _noBase);
      expect(buffer.snapshot(), {"p1": "a", "p2": "b"});
      buffer.dispose();
    });

    test("a new accumulator is seeded once from the base text", () {
      var baseLookups = 0;
      final buffer = StreamingTextBuffer(onFlush: () {});
      String? base() {
        baseLookups++;
        return "before-middle";
      }

      buffer.appendDelta(partId: "p1", delta: "after", baseText: base);
      buffer.appendDelta(partId: "p1", delta: "!", baseText: base);
      expect(buffer.snapshot(), {"p1": "before-middleafter!"});
      expect(baseLookups, 1, reason: "an existing accumulator must not rescan for a base");
      buffer.dispose();
    });

    test("a null base text starts the accumulator from the delta alone", () {
      final buffer = StreamingTextBuffer(onFlush: () {});
      buffer.appendDelta(partId: "p1", delta: "after", baseText: _noBase);
      expect(buffer.snapshot(), {"p1": "after"});
      buffer.dispose();
    });

    test("removePart clears a specific part", () {
      final buffer = StreamingTextBuffer(onFlush: () {});
      buffer.appendDelta(partId: "p1", delta: "data", baseText: _noBase);
      buffer.appendDelta(partId: "p2", delta: "keep", baseText: _noBase);
      buffer.removePart("p1");
      expect(buffer.snapshot(), {"p2": "keep"});
      buffer.dispose();
    });

    test("removePart is a no-op for unknown part", () {
      final buffer = StreamingTextBuffer(onFlush: () {});
      buffer.appendDelta(partId: "p1", delta: "data", baseText: _noBase);
      buffer.removePart("nonexistent");
      expect(buffer.snapshot(), {"p1": "data"});
      buffer.dispose();
    });

    test("onFlush fires after throttle duration", () {
      fakeAsync((async) {
        var flushCount = 0;
        final buffer = StreamingTextBuffer(
          onFlush: () => flushCount++,
          throttle: const Duration(milliseconds: 50),
        );

        buffer.appendDelta(partId: "p1", delta: "data", baseText: _noBase);
        expect(flushCount, 0);

        async.elapse(const Duration(milliseconds: 50));
        expect(flushCount, 1);

        buffer.dispose();
      });
    });

    test("multiple appendDelta calls within throttle window produce one flush", () {
      fakeAsync((async) {
        var flushCount = 0;
        final buffer = StreamingTextBuffer(
          onFlush: () => flushCount++,
          throttle: const Duration(milliseconds: 50),
        );

        buffer.appendDelta(partId: "p1", delta: "a", baseText: _noBase);
        buffer.appendDelta(partId: "p1", delta: "b", baseText: _noBase);
        buffer.appendDelta(partId: "p1", delta: "c", baseText: _noBase);

        async.elapse(const Duration(milliseconds: 50));
        expect(flushCount, 1);
        expect(buffer.snapshot(), {"p1": "abc"});

        buffer.dispose();
      });
    });

    test("new deltas after flush schedule a new timer", () {
      fakeAsync((async) {
        var flushCount = 0;
        final buffer = StreamingTextBuffer(
          onFlush: () => flushCount++,
          throttle: const Duration(milliseconds: 50),
        );

        buffer.appendDelta(partId: "p1", delta: "first", baseText: _noBase);
        async.elapse(const Duration(milliseconds: 50));
        expect(flushCount, 1);

        buffer.appendDelta(partId: "p1", delta: " second", baseText: _noBase);
        async.elapse(const Duration(milliseconds: 50));
        expect(flushCount, 2);

        buffer.dispose();
      });
    });

    test("dispose cancels pending timer", () {
      fakeAsync((async) {
        var flushCount = 0;
        final buffer = StreamingTextBuffer(
          onFlush: () => flushCount++,
          throttle: const Duration(milliseconds: 50),
        );

        buffer.appendDelta(partId: "p1", delta: "data", baseText: _noBase);
        buffer.dispose();

        async.elapse(const Duration(milliseconds: 100));
        expect(flushCount, 0);
      });
    });

    test("flush interval stretches as the buffered text grows, capped at 300ms", () {
      fakeAsync((async) {
        var flushCount = 0;
        final buffer = StreamingTextBuffer(
          onFlush: () => flushCount++,
          throttle: const Duration(milliseconds: 50),
        );

        // Small buffers flush at the base throttle.
        buffer.appendDelta(partId: "p1", delta: "small", baseText: _noBase);
        async.elapse(const Duration(milliseconds: 50));
        expect(flushCount, 1);

        // Past the relaxed threshold (8 KiB) the next flush waits
        // proportionally longer than the base throttle (~16 KB → ~98ms).
        buffer.appendDelta(partId: "p1", delta: "x" * 16000, baseText: _noBase);
        async.elapse(const Duration(milliseconds: 50));
        expect(flushCount, 1);
        async.elapse(const Duration(milliseconds: 50));
        expect(flushCount, 2);

        // No matter how large the part grows, the interval caps at 300ms.
        buffer.appendDelta(partId: "p1", delta: "x" * 1000000, baseText: _noBase);
        async.elapse(const Duration(milliseconds: 300));
        expect(flushCount, 3);

        buffer.dispose();
      });
    });

    test("a finalized large part stops throttling the next part", () {
      fakeAsync((async) {
        var flushCount = 0;
        final buffer = StreamingTextBuffer(
          onFlush: () => flushCount++,
          throttle: const Duration(milliseconds: 50),
        );

        // The large part schedules the capped 300ms interval, then finalizes
        // before that timer fires.
        buffer.appendDelta(partId: "p1", delta: "x" * 1000000, baseText: _noBase);
        buffer.removePart("p1");

        // The next (small) part must get its normal 50ms flush, not inherit
        // the stale 300ms timer.
        buffer.appendDelta(partId: "p2", delta: "small", baseText: _noBase);
        async.elapse(const Duration(milliseconds: 50));
        expect(flushCount, 1);
        expect(buffer.snapshot(), {"p2": "small"});

        buffer.dispose();
      });
    });

    test("removing the last part cancels the pending flush", () {
      fakeAsync((async) {
        var flushCount = 0;
        final buffer = StreamingTextBuffer(
          onFlush: () => flushCount++,
          throttle: const Duration(milliseconds: 50),
        );

        buffer.appendDelta(partId: "p1", delta: "data", baseText: _noBase);
        buffer.removePart("p1");

        async.elapse(const Duration(milliseconds: 400));
        expect(flushCount, 0);

        buffer.dispose();
      });
    });

    test("removing one part reschedules the flush for the remaining parts", () {
      fakeAsync((async) {
        var flushCount = 0;
        final buffer = StreamingTextBuffer(
          onFlush: () => flushCount++,
          throttle: const Duration(milliseconds: 50),
        );

        buffer.appendDelta(partId: "p1", delta: "x" * 1000000, baseText: _noBase);
        buffer.appendDelta(partId: "p2", delta: "small", baseText: _noBase);
        buffer.removePart("p1");

        async.elapse(const Duration(milliseconds: 50));
        expect(flushCount, 1);
        expect(buffer.snapshot(), {"p2": "small"});

        buffer.dispose();
      });
    });
  });
}

String? _noBase() => null;
