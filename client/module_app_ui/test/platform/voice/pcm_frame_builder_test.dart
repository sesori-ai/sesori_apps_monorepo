import "dart:math";
import "dart:typed_data";

import "package:flutter_test/flutter_test.dart";
import "package:sesori_app_ui/src/platform/voice/pcm_frame_builder.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

Uint8List _bytes(List<int> values) => Uint8List.fromList(values);

void main() {
  late PcmFrameBuilder builder;

  setUp(() => builder = PcmFrameBuilder());

  test("an even chunk passes through whole", () {
    expect(builder.add(chunk: _bytes([1, 2, 3, 4])), [
      [1, 2, 3, 4],
    ]);
  });

  test("an odd chunk holds its last byte and the next chunk starts with it", () {
    expect(builder.add(chunk: _bytes([1, 2, 3])), [
      [1, 2],
    ]);
    expect(builder.add(chunk: _bytes([4, 5, 6])), [
      [3, 4, 5, 6],
    ]);
  });

  test("a held byte carries through an even chunk too", () {
    expect(builder.add(chunk: _bytes([1])), isEmpty);
    expect(builder.add(chunk: _bytes([2, 3])), [
      [1, 2],
    ]);
    expect(builder.add(chunk: _bytes([4])), [
      [3, 4],
    ]);
  });

  test("an empty chunk gives no frame and keeps the held byte", () {
    expect(builder.add(chunk: _bytes([])), isEmpty);
    expect(builder.add(chunk: _bytes([1])), isEmpty);
    expect(builder.add(chunk: _bytes([])), isEmpty);
    expect(builder.add(chunk: _bytes([2])), [
      [1, 2],
    ]);
  });

  test("the largest allowed frame stays whole and one byte more is held", () {
    final largest = Uint8List(realtimeVoiceMaxFrameBytes);
    expect(builder.add(chunk: largest).map((frame) => frame.length), [realtimeVoiceMaxFrameBytes]);

    final oneMore = Uint8List(realtimeVoiceMaxFrameBytes + 1);
    expect(builder.add(chunk: oneMore).map((frame) => frame.length), [realtimeVoiceMaxFrameBytes]);
  });

  test("a chunk over the limit splits, and a held byte can push it over", () {
    expect(builder.add(chunk: Uint8List(realtimeVoiceMaxFrameBytes * 2 + 4)).map((frame) => frame.length), [
      realtimeVoiceMaxFrameBytes,
      realtimeVoiceMaxFrameBytes,
      4,
    ]);

    builder.add(chunk: _bytes([1]));
    expect(builder.add(chunk: Uint8List(realtimeVoiceMaxFrameBytes + 1)).map((frame) => frame.length), [
      realtimeVoiceMaxFrameBytes,
      2,
    ]);
  });

  test("any chunking gives valid frames holding every byte in order", () {
    final random = Random(7);
    final sizes = <int>[1, 2, 3, 0, 65535, 65536, 65537, 131073, for (var i = 0; i < 300; i++) random.nextInt(9000)];
    final input = BytesBuilder(copy: false);
    final output = BytesBuilder(copy: false);
    var next = 0;

    for (final size in sizes) {
      final chunk = Uint8List(size);
      for (var i = 0; i < size; i++) {
        chunk[i] = next++ & 0xff;
      }
      input.add(chunk);
      for (final frame in builder.add(chunk: chunk)) {
        expect(frame.length, inInclusiveRange(realtimeVoiceMinFrameBytes, realtimeVoiceMaxFrameBytes));
        expect(frame.length.isEven, isTrue);
        output.add(frame);
      }
    }

    final sent = output.takeBytes();
    final total = input.takeBytes();
    expect(sent.length, total.length - total.length % 2);
    expect(sent, total.sublist(0, sent.length));
  });
}
