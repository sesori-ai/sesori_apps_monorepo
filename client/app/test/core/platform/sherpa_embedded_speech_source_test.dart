import "dart:typed_data";

import "package:flutter_test/flutter_test.dart";
import "package:sesori_mobile/core/platform/sherpa_embedded_speech_source.dart";

void main() {
  group("formatEmbeddedSpeechSegment", () {
    test("lowercases the model's capitals and capitalizes the first letter", () {
      expect(formatEmbeddedSpeechSegment(text: " FIX THE LOGIN BUG "), "Fix the login bug");
    });

    test("keeps the pronoun capitalized, alone and in contractions", () {
      expect(formatEmbeddedSpeechSegment(text: "SO I THINK I'M DONE IN IT"), "So I think I'm done in it");
    });

    test("an empty result stays empty", () {
      expect(formatEmbeddedSpeechSegment(text: "  "), "");
    });
  });

  test("pcm16ToSamples reads little-endian samples at any offset", () {
    final buffer = Uint8List.fromList([0xFF, 0x00, 0x80, 0xFF, 0x7F, 0x00, 0x00]);
    final frame = Uint8List.sublistView(buffer, 1, 7);

    expect(pcm16ToSamples(frame: frame), [-1.0, closeTo(32767 / 32768, 1e-6), 0.0]);
  });
}
