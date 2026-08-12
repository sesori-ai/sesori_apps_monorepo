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
  final AudioEncoder encoder = isWeb ? AudioEncoder.wav : AudioEncoder.aacLc;
  final String mimeType = isWeb ? "audio/wav" : "audio/mp4";
  final String fileExtension = isWeb ? "wav" : "m4a";
  final int bitRate;
  final int sampleRate = isAndroid ? 16000 : 44100;
  final int numChannels;

  new()
    : this.forPlatform(
        isWeb: UniversalPlatform.isWeb,
        isAndroid: UniversalPlatform.isAndroid,
      );

  @visibleForTesting
  this : bitRate = 128000, numChannels = 1;
}
