import "package:flutter_test/flutter_test.dart";
import "package:record/record.dart";
import "package:sesori_mobile/capabilities/voice/audio_format_config.dart";

void main() {
  group("AudioFormatConfig", () {
    test("native non-Android: AAC encoder, default sample rate", () {
      final config = AudioFormatConfig.forPlatform(isWeb: false);

      expect(config.encoder, AudioEncoder.aacLc);
      expect(config.mimeType, "audio/mp4");
      expect(config.fileExtension, "m4a");
      expect(config.bitRate, 128000);
      expect(config.sampleRate, 44100);
      expect(config.numChannels, 1);
    });

    test("Android: AAC encoder, 16 kHz sample rate (Whisper native rate)", () {
      final config = AudioFormatConfig.forPlatform(isWeb: false, isAndroid: true);

      expect(config.encoder, AudioEncoder.aacLc);
      expect(config.mimeType, "audio/mp4");
      expect(config.fileExtension, "m4a");
      expect(config.bitRate, 128000);
      expect(config.sampleRate, 16000);
      expect(config.numChannels, 1);
    });

    test("web platform: WAV encoder, default sample rate", () {
      final config = AudioFormatConfig.forPlatform(isWeb: true);

      expect(config.encoder, AudioEncoder.wav);
      expect(config.mimeType, "audio/wav");
      expect(config.fileExtension, "wav");
      expect(config.bitRate, 128000);
      expect(config.sampleRate, 44100);
      expect(config.numChannels, 1);
    });

    test("default constructor uses platform detection", () {
      // Tests run natively (not in a browser, not on Android)
      final config = AudioFormatConfig();

      expect(config.encoder, AudioEncoder.aacLc);
      expect(config.mimeType, "audio/mp4");
      expect(config.fileExtension, "m4a");
      expect(config.bitRate, 128000);
      expect(config.sampleRate, 44100);
      expect(config.numChannels, 1);
    });
  });
}
