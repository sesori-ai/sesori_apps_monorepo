import "package:flutter/foundation.dart" show visibleForTesting;
import "package:injectable/injectable.dart";
import "package:record/record.dart";
import "package:universal_platform/universal_platform.dart";

/// Centralizes platform-aware audio recording configuration.
///
/// AAC-LC is supported on all native platforms (iOS, Android, macOS, etc.)
/// and produces small files. Web support for AAC is uncertain, so we fall
/// back to WAV there.
///
/// Sample rate is 16 kHz on Android (Whisper's native rate — smaller files,
/// zero quality loss) and the default 44.1 kHz elsewhere (iOS requires it
/// to avoid a hardware sample-rate mismatch that produces silent recordings).
@lazySingleton
class AudioFormatConfig.forPlatform({required bool isWeb, bool isAndroid = false}) {
  final AudioEncoder encoder;
  final String mimeType;
  final String fileExtension;
  final int bitRate;
  final int sampleRate;
  final int numChannels;

  AudioFormatConfig()
    : this.forPlatform(
        isWeb: UniversalPlatform.isWeb,
        isAndroid: UniversalPlatform.isAndroid,
      );

  @visibleForTesting
  this
    : encoder = isWeb ? AudioEncoder.wav : AudioEncoder.aacLc,
      mimeType = isWeb ? "audio/wav" : "audio/mp4",
      fileExtension = isWeb ? "wav" : "m4a",
      bitRate = 128000,
      sampleRate = isAndroid ? 16000 : 44100,
      numChannels = 1;
}
