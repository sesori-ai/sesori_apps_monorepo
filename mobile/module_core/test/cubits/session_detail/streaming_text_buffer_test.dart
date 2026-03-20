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
      buffer.appendDelta("p1", "Hello");
      buffer.appendDelta("p1", " World");
      expect(buffer.snapshot(), {"p1": "Hello World"});
      buffer.dispose();
    });

    test("appendDelta handles multiple parts independently", () {
      final buffer = StreamingTextBuffer(onFlush: () {});
      buffer.appendDelta("p1", "a");
      buffer.appendDelta("p2", "b");
      expect(buffer.snapshot(), {"p1": "a", "p2": "b"});
      buffer.dispose();
    });

    test("removePart clears a specific part", () {
      final buffer = StreamingTextBuffer(onFlush: () {});
      buffer.appendDelta("p1", "data");
      buffer.appendDelta("p2", "keep");
      buffer.removePart("p1");
      expect(buffer.snapshot(), {"p2": "keep"});
      buffer.dispose();
    });

    test("removePart is a no-op for unknown part", () {
      final buffer = StreamingTextBuffer(onFlush: () {});
      buffer.appendDelta("p1", "data");
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

        buffer.appendDelta("p1", "data");
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

        buffer.appendDelta("p1", "a");
        buffer.appendDelta("p1", "b");
        buffer.appendDelta("p1", "c");

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

        buffer.appendDelta("p1", "first");
        async.elapse(const Duration(milliseconds: 50));
        expect(flushCount, 1);

        buffer.appendDelta("p1", " second");
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

        buffer.appendDelta("p1", "data");
        buffer.dispose();

        async.elapse(const Duration(milliseconds: 100));
        expect(flushCount, 0);
      });
    });
  });
}
