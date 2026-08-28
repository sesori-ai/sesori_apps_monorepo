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

    test("realtime recorder requests provider-neutral PCM16 mono at 16 kHz", () {
      final config = AudioFormatConfig.forPlatform(isWeb: false);
      final recordConfig = config.realtimeRecorder.requestedRecordConfig;

      expect(recordConfig.encoder, AudioEncoder.pcm16bits);
      expect(recordConfig.sampleRate, 16000);
      expect(recordConfig.numChannels, 1);
      expect(recordConfig.iosConfig.allowHapticsAndSystemSoundsDuringRecording, isTrue);
      expect(config.realtimeRecorder.requestedFormat.encoding, RealtimeRecorderEncoding.signedPcm16LittleEndian);
      expect(config.realtimeRecorder.requestedFormat.channelLayout, RealtimeRecorderChannelLayout.mono);
      expect(config.realtimeRecorder.requestedFormat.sampleRate, 16000);
    });

    test("realtime recorder falls back to requested config when no effective callback fires", () {
      final config = AudioFormatConfig.forPlatform(isWeb: false);

      final effectiveFormat = config.realtimeRecorder.validateEffectiveRecordConfig(latestRecordConfig: null);

      expect(effectiveFormat.encoding, RealtimeRecorderEncoding.signedPcm16LittleEndian);
      expect(effectiveFormat.channelLayout, RealtimeRecorderChannelLayout.mono);
      expect(effectiveFormat.sampleRate, 16000);
    });

    test("realtime recorder accepts exactly the supported effective sample rates", () {
      final config = AudioFormatConfig.forPlatform(isWeb: false);

      for (final sampleRate in config.realtimeRecorder.supportedEffectiveSampleRates) {
        final effectiveFormat = config.realtimeRecorder.validateEffectiveRecordConfig(
          latestRecordConfig: config.realtimeRecorder.requestedRecordConfig.copyWith(sampleRate: sampleRate),
        );

        expect(effectiveFormat.sampleRate, sampleRate);
      }

      expect(config.realtimeRecorder.supportedEffectiveSampleRates, const [16000, 24000, 44100, 48000]);
    });

    test("realtime recorder rejects unsupported effective sample rate changes", () {
      final config = AudioFormatConfig.forPlatform(isWeb: false);

      expect(
        () => config.realtimeRecorder.validateEffectiveRecordConfig(
          latestRecordConfig: config.realtimeRecorder.requestedRecordConfig.copyWith(sampleRate: 22050),
        ),
        throwsUnsupportedError,
      );
    });

    test("realtime recorder rejects effective encoder changes", () {
      final config = AudioFormatConfig.forPlatform(isWeb: false);

      expect(
        () => config.realtimeRecorder.validateEffectiveRecordConfig(
          latestRecordConfig: config.realtimeRecorder.requestedRecordConfig.copyWith(encoder: AudioEncoder.wav),
        ),
        throwsUnsupportedError,
      );
    });

    test("realtime recorder rejects effective channel changes", () {
      final config = AudioFormatConfig.forPlatform(isWeb: false);

      expect(
        () => config.realtimeRecorder.validateEffectiveRecordConfig(
          latestRecordConfig: config.realtimeRecorder.requestedRecordConfig.copyWith(numChannels: 2),
        ),
        throwsUnsupportedError,
      );
    });
  });
}
