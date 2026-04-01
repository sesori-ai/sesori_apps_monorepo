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
      buffer.appendDelta(partId: "p1", delta: "Hello");
      buffer.appendDelta(partId: "p1", delta: " World");
      expect(buffer.snapshot(), {"p1": "Hello World"});
      buffer.dispose();
    });

    test("appendDelta handles multiple parts independently", () {
      final buffer = StreamingTextBuffer(onFlush: () {});
      buffer.appendDelta(partId: "p1", delta: "a");
      buffer.appendDelta(partId: "p2", delta: "b");
      expect(buffer.snapshot(), {"p1": "a", "p2": "b"});
      buffer.dispose();
    });

    test("removePart clears a specific part", () {
      final buffer = StreamingTextBuffer(onFlush: () {});
      buffer.appendDelta(partId: "p1", delta: "data");
      buffer.appendDelta(partId: "p2", delta: "keep");
      buffer.removePart("p1");
      expect(buffer.snapshot(), {"p2": "keep"});
      buffer.dispose();
    });

    test("removePart is a no-op for unknown part", () {
      final buffer = StreamingTextBuffer(onFlush: () {});
      buffer.appendDelta(partId: "p1", delta: "data");
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

        buffer.appendDelta(partId: "p1", delta: "data");
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

        buffer.appendDelta(partId: "p1", delta: "a");
        buffer.appendDelta(partId: "p1", delta: "b");
        buffer.appendDelta(partId: "p1", delta: "c");

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

        buffer.appendDelta(partId: "p1", delta: "first");
        async.elapse(const Duration(milliseconds: 50));
        expect(flushCount, 1);

        buffer.appendDelta(partId: "p1", delta: " second");
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

        buffer.appendDelta(partId: "p1", delta: "data");
        buffer.dispose();

        async.elapse(const Duration(milliseconds: 100));
        expect(flushCount, 0);
      });
    });

    test("clear() removes all buffered parts and cancels pending timer", () {
      fakeAsync((async) {
        var flushCount = 0;
        final buffer = StreamingTextBuffer(
          onFlush: () => flushCount++,
          throttle: const Duration(milliseconds: 50),
        );

        buffer.appendDelta(partId: "p1", delta: "data");
        buffer.appendDelta(partId: "p2", delta: "more");
        expect(buffer.snapshot(), {"p1": "data", "p2": "more"});

        buffer.clear();
        expect(buffer.snapshot(), isEmpty);

        async.elapse(const Duration(milliseconds: 100));
        expect(flushCount, 0);
      });
    });

    test("clear() followed by snapshot() returns empty map", () {
      final buffer = StreamingTextBuffer(onFlush: () {});
      buffer.appendDelta(partId: "p1", delta: "text");
      buffer.appendDelta(partId: "p2", delta: "more");
      buffer.clear();
      expect(buffer.snapshot(), isEmpty);
      buffer.dispose();
    });

    test("appendDelta() after clear() works normally (buffer is reusable)", () {
      fakeAsync((async) {
        var flushCount = 0;
        final buffer = StreamingTextBuffer(
          onFlush: () => flushCount++,
          throttle: const Duration(milliseconds: 50),
        );

        buffer.appendDelta(partId: "p1", delta: "first");
        buffer.clear();
        expect(buffer.snapshot(), isEmpty);

        buffer.appendDelta(partId: "p2", delta: "second");
        expect(buffer.snapshot(), {"p2": "second"});

        async.elapse(const Duration(milliseconds: 50));
        expect(flushCount, 1);

        buffer.dispose();
      });
    });
  });
}
