import "dart:typed_data";

final class const VoiceRealtimeAudioFormat({required final int sampleRate});

sealed class const VoiceRealtimeConnectionEvent();

final class const VoiceRealtimeReady() extends VoiceRealtimeConnectionEvent;

final class const VoiceRealtimeTranscript({
  required final String confirmedDelta,
  required final String provisional,
}) extends VoiceRealtimeConnectionEvent;

// WORKAROUND: dart_style 3.1.12 crashes on empty enhanced enum constructors.
// ignore: use_primary_constructors
enum VoiceRealtimeCompletionReason { finished, sessionLimit, quotaLimit }

final class const VoiceRealtimeCompleted({required final VoiceRealtimeCompletionReason reason})
    extends VoiceRealtimeConnectionEvent;

final class const VoiceRealtimeFailed({required final VoiceRealtimeFailure failure})
    extends VoiceRealtimeConnectionEvent;

sealed class const VoiceRealtimeFailure({
  required final Object? innerError,
  required final StackTrace? innerStackTrace,
});

final class const VoiceRealtimeQuotaFailure({
  required super.innerError,
  required super.innerStackTrace,
}) extends VoiceRealtimeFailure;

final class const VoiceRealtimeTemporaryUnavailableFailure({
  required super.innerError,
  required super.innerStackTrace,
}) extends VoiceRealtimeFailure;

final class const VoiceRealtimeInterruptedFailure({
  required super.innerError,
  required super.innerStackTrace,
}) extends VoiceRealtimeFailure;

final class const VoiceRealtimeContractFailure({
  required super.innerError,
  required super.innerStackTrace,
}) extends VoiceRealtimeFailure;

sealed class const VoiceRealtimeTerminalOutcome();

final class const VoiceRealtimeTerminalCompleted({required final VoiceRealtimeCompletionReason reason})
    extends VoiceRealtimeTerminalOutcome;

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
