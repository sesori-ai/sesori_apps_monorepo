import "dart:typed_data";

final class const VoiceRealtimeAudioFormat({required final int sampleRate});

sealed class const VoiceRealtimeConnectionEvent();

final class const VoiceRealtimeReady() extends VoiceRealtimeConnectionEvent;

final class const VoiceRealtimeTranscript({
  required final String confirmedDelta,
  required final String provisional,
}) extends VoiceRealtimeConnectionEvent;

final class const VoiceRealtimeCompleted() extends VoiceRealtimeConnectionEvent;

final class const VoiceRealtimeFailed({required final VoiceRealtimeFailure failure})
    extends VoiceRealtimeConnectionEvent;

sealed class const VoiceRealtimeFailure({required final Object? innerError});

final class const VoiceRealtimeQuotaFailure({required super.innerError}) extends VoiceRealtimeFailure;

final class const VoiceRealtimeTemporaryUnavailableFailure({required super.innerError}) extends VoiceRealtimeFailure;

final class const VoiceRealtimeInterruptedFailure({required super.innerError}) extends VoiceRealtimeFailure;

final class const VoiceRealtimeContractFailure({required super.innerError}) extends VoiceRealtimeFailure;

sealed class const VoiceRealtimeTerminalOutcome();

final class const VoiceRealtimeTerminalCompleted() extends VoiceRealtimeTerminalOutcome;

final class const VoiceRealtimeTerminalFailed({required final VoiceRealtimeFailure failure})
    extends VoiceRealtimeTerminalOutcome;

final class const VoiceRealtimeConnectionException({required final VoiceRealtimeFailure failure}) implements Exception;

abstract interface class VoiceRealtimeConnection() {
  Stream<VoiceRealtimeConnectionEvent> get events;

  void sendAudio(Uint8List frame);

  Future<VoiceRealtimeTerminalOutcome> finish();

  Future<void> cancel();

  Future<void> close();
}
