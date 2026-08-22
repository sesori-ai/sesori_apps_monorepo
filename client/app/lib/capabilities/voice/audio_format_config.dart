import "package:flutter/foundation.dart" show immutable, visibleForTesting;
import "package:injectable/injectable.dart";
import "package:record/record.dart";
import "package:universal_platform/universal_platform.dart";

// ignore: use_primary_constructors, dart_style crashes on enum primary constructors here.
enum RealtimeRecorderEncoding {
  signedPcm16LittleEndian,
}

// ignore: use_primary_constructors, dart_style crashes on enum primary constructors here.
enum RealtimeRecorderChannelLayout {
  mono,
}

@immutable
final class const RealtimeRecorderFormat({
  required final RealtimeRecorderEncoding encoding,
  required final RealtimeRecorderChannelLayout channelLayout,
  required final int sampleRate,
}) {
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RealtimeRecorderFormat &&
            other.encoding == encoding &&
            other.channelLayout == channelLayout &&
            other.sampleRate == sampleRate;
  }

  @override
  int get hashCode => Object.hash(encoding, channelLayout, sampleRate);
}

@immutable
final class const RealtimeRecorderConfig({
  required final RecordConfig requestedRecordConfig,
  required final RealtimeRecorderFormat requestedFormat,
  required final List<int> supportedEffectiveSampleRates,
}) {
  RealtimeRecorderFormat validateEffectiveRecordConfig({required RecordConfig? latestRecordConfig}) {
    final effectiveRecordConfig = latestRecordConfig ?? requestedRecordConfig;

    if (effectiveRecordConfig.encoder != requestedRecordConfig.encoder) {
      throw UnsupportedError("Realtime recorder encoding changed from PCM16 little-endian");
    }

    if (effectiveRecordConfig.numChannels != requestedRecordConfig.numChannels) {
      throw UnsupportedError("Realtime recorder channel layout changed from mono");
    }

    if (!supportedEffectiveSampleRates.contains(effectiveRecordConfig.sampleRate)) {
      throw UnsupportedError("Unsupported realtime recorder sample rate");
    }

    return RealtimeRecorderFormat(
      encoding: requestedFormat.encoding,
      channelLayout: requestedFormat.channelLayout,
      sampleRate: effectiveRecordConfig.sampleRate,
    );
  }
}

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
  static const RealtimeRecorderConfig _realtimeRecorder = RealtimeRecorderConfig(
    requestedRecordConfig: RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
    ),
    requestedFormat: RealtimeRecorderFormat(
      encoding: RealtimeRecorderEncoding.signedPcm16LittleEndian,
      channelLayout: RealtimeRecorderChannelLayout.mono,
      sampleRate: 16000,
    ),
    supportedEffectiveSampleRates: [16000, 24000, 44100, 48000],
  );

  final AudioEncoder encoder = isWeb ? AudioEncoder.wav : AudioEncoder.aacLc;
  final String mimeType = isWeb ? "audio/wav" : "audio/mp4";
  final String fileExtension = isWeb ? "wav" : "m4a";
  final int bitRate;
  final int sampleRate = isAndroid ? 16000 : 44100;
  final int numChannels;
  final RealtimeRecorderConfig realtimeRecorder = _realtimeRecorder;

  new()
    : this.forPlatform(
        isWeb: UniversalPlatform.isWeb,
        isAndroid: UniversalPlatform.isAndroid,
      );

  @visibleForTesting
  this : bitRate = 128000, numChannels = 1;
}
