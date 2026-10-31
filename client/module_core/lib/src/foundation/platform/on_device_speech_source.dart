import "dart:typed_data";

import "../models/voice/voice_realtime.dart";

/// The operating system's own speech engine, which keeps audio on the device.
abstract interface class OnDeviceSpeechSource() {
  /// Whether a dictation can run on the device right now. When only the language
  /// model is missing, this starts its download in the background and answers
  /// false, so a later dictation can use it.
  Future<bool> prepare();

  /// Starts the engine, which then accepts PCM16 mono audio at [sampleRate]. Only
  /// one session runs at a time, so this throws while another is open.
  Future<OnDeviceSpeechSession> open({required VoiceRealtimeSampleRate sampleRate});
}

abstract interface class OnDeviceSpeechSession() {
  /// Ends with [OnDeviceSpeechCompleted] or [OnDeviceSpeechFailed], and is silent
  /// after [cancel].
  Stream<OnDeviceSpeechEvent> get events;

  /// A frame the engine can't take arrives as [OnDeviceSpeechFailed].
  void sendAudio({required Uint8List frame});

  /// No more audio is coming.
  void finish();

  /// Stops the engine and discards what it has. Safe to call more than once.
  Future<void> cancel();
}

sealed class const OnDeviceSpeechEvent();

/// The engine's words, without any spacing between events. Empty strings are real
/// values here, as in [VoiceRealtimeWords].
final class const OnDeviceSpeechWords({
  /// New final words, to add to those before.
  required final String confirmedDelta,

  /// Replaces the previous tentative words.
  required final String provisional,
}) extends OnDeviceSpeechEvent;

final class const OnDeviceSpeechCompleted() extends OnDeviceSpeechEvent;

final class const OnDeviceSpeechFailed({required final String reason}) extends OnDeviceSpeechEvent;
