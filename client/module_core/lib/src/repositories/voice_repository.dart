import "dart:typed_data";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart" show ProjectGlossaryKey;

import "../capabilities/voice/realtime_voice_client.dart";
import "../capabilities/voice/realtime_voice_protocol.dart";
import "../capabilities/voice/voice_api.dart";
import "../foundation/models/voice/voice_dictation_outcome.dart";
import "../foundation/models/voice/voice_realtime.dart";
import "../foundation/models/voice/voice_transcription_error.dart";

@lazySingleton
class VoiceRepository({required final VoiceApi _api, required final RealtimeVoiceClient _realtimeClient}) {
  Future<VoiceTranscriptionOutcome> transcribe({
    required String audioFilePath,
    required String mimeType,
    required ProjectGlossaryKey? projectGlossaryKey,
  }) async {
    final response = await _api.transcribe(
      audioFilePath: audioFilePath,
      mimeType: mimeType,
      projectGlossaryKey: projectGlossaryKey,
    );
    return switch (response) {
      VoiceTranscriptionApiSuccess(:final transcript) => VoiceTranscriptionOutcome.success(
        transcript: transcript,
      ),
      VoiceTranscriptionApiFailure(:final error, :final retryable) => _mapError(
        error: error,
        retryable: retryable,
      ),
    };
  }

  /// Opens a live dictation socket. Returns once the upgrade succeeded; audio may
  /// follow only after [VoiceRealtimeReady].
  ///
  /// Throws a [VoiceTranscriptionError] holding the original as its `innerError`.
  /// A disabled server rejects the upgrade with 404, so it is a [ServerVoiceError].
  Future<VoiceRealtimeConnection> openRealtime({
    required VoiceRealtimeSampleRate sampleRate,
    required ProjectGlossaryKey? projectKey,
  }) async {
    try {
      final session = await _realtimeClient.open(sampleRate: sampleRate, projectKey: projectKey);
      return VoiceRealtimeConnection._(session: session);
    } on RealtimeVoiceException catch (error, stackTrace) {
      Error.throwWithStackTrace(_mapRealtimeException(exception: error), stackTrace);
    }
  }

  VoiceTranscriptionOutcome _mapError({
    required ApiError error,
    required bool? retryable,
  }) => switch (error) {
    NotAuthenticatedError() => const VoiceTranscriptionOutcome.notAuthenticated(),
    NonSuccessCodeError(:final errorCode) when retryable ?? false => VoiceTranscriptionOutcome.retryableServerFailure(
      statusCode: errorCode,
    ),
    // COMPATIBILITY 2026-08-28 (v1.8.2): Older auth servers can omit retryability.
    // Retire when every supported auth server returns a boolean for every transcribe failure.
    NonSuccessCodeError(:final errorCode) => VoiceTranscriptionOutcome.terminalServerFailure(statusCode: errorCode),
    DartHttpClientError() => const VoiceTranscriptionOutcome.networkFailure(),
    GenericError() => const VoiceTranscriptionOutcome.unexpectedFailure(),
    JsonParsingError() || EmptyResponseError() => const VoiceTranscriptionOutcome.emptyTranscript(),
  };
}

/// A live dictation socket, in domain terms. [events] closes after a terminal
/// event or [cancel].
class VoiceRealtimeConnection._({required final RealtimeVoiceSession _session}) {
  Stream<VoiceRealtimeEvent> get events => _session.events.map(_mapRealtimeEvent);

  /// Throws [StateError] before [VoiceRealtimeReady] or after [finish], and
  /// [ArgumentError] for a frame the protocol does not allow. Does nothing once
  /// the session has ended.
  void sendAudio({required Uint8List frame}) => _session.sendAudio(frame: frame);

  /// Throws [StateError] before [VoiceRealtimeReady].
  void finish() => _session.finish();

  Future<void> cancel() => _session.cancel();
}

VoiceRealtimeEvent _mapRealtimeEvent(RealtimeVoiceEvent event) => switch (event) {
  RealtimeVoiceReadyEvent() => const VoiceRealtimeReady(),
  RealtimeVoiceTranscriptEvent(:final confirmedDelta, :final provisional) => VoiceRealtimeWords(
    confirmedDelta: confirmedDelta,
    provisional: provisional,
  ),
  RealtimeVoiceCompleteEvent(:final reason) => VoiceRealtimeCompleted(
    outcome: switch (reason) {
      RealtimeVoiceCompleteReason.finished => VoiceDictationOutcome.finished,
      RealtimeVoiceCompleteReason.sessionLimit ||
      RealtimeVoiceCompleteReason.quotaLimit => VoiceDictationOutcome.limitReached,
    },
  ),
  RealtimeVoiceErrorEvent(:final code) => VoiceRealtimeFailed(
    // The server closes with this code, so it stands in for an HTTP status.
    error: code.retryable
        ? VoiceTranscriptionError.retryableServerError(statusCode: code.closeCode, innerError: event)
        : VoiceTranscriptionError.serverError(statusCode: code.closeCode, innerError: event),
  ),
  RealtimeVoiceConnectionFailedEvent(:final exception) => VoiceRealtimeFailed(
    error: _mapRealtimeException(exception: exception),
  ),
};

VoiceTranscriptionError _mapRealtimeException({required RealtimeVoiceException exception}) => switch (exception) {
  RealtimeVoiceNotAuthenticatedException() ||
  RealtimeVoiceUpgradeRejectedException(statusCode: 401) => VoiceTranscriptionError.notAuthenticated(
    innerError: exception,
  ),
  RealtimeVoiceUpgradeRejectedException(:final statusCode) when statusCode == 429 || statusCode >= 500 =>
    VoiceTranscriptionError.retryableServerError(statusCode: statusCode, innerError: exception),
  RealtimeVoiceUpgradeRejectedException(:final statusCode) => VoiceTranscriptionError.serverError(
    statusCode: statusCode,
    innerError: exception,
  ),
  RealtimeVoiceConnectionException() => VoiceTranscriptionError.networkError(innerError: exception),
  RealtimeVoiceProtocolException() => VoiceTranscriptionError.serverError(
    statusCode: realtimeVoiceProtocolViolationCode,
    innerError: exception,
  ),
};

sealed class const VoiceTranscriptionOutcome() {
  const factory success({required String transcript}) = VoiceTranscriptionSuccess;

  const factory notAuthenticated() = VoiceTranscriptionNotAuthenticated;

  const factory retryableServerFailure({required int statusCode}) = VoiceTranscriptionRetryableServerFailure;

  const factory terminalServerFailure({required int statusCode}) = VoiceTranscriptionTerminalServerFailure;

  const factory networkFailure() = VoiceTranscriptionNetworkFailure;

  const factory unexpectedFailure() = VoiceTranscriptionUnexpectedFailure;

  const factory emptyTranscript() = VoiceTranscriptionEmptyTranscript;
}

final class const VoiceTranscriptionSuccess({required final String transcript}) extends VoiceTranscriptionOutcome;

final class const VoiceTranscriptionNotAuthenticated() extends VoiceTranscriptionOutcome;

final class const VoiceTranscriptionRetryableServerFailure({required final int statusCode})
    extends VoiceTranscriptionOutcome;

final class const VoiceTranscriptionTerminalServerFailure({required final int statusCode})
    extends VoiceTranscriptionOutcome;

final class const VoiceTranscriptionNetworkFailure() extends VoiceTranscriptionOutcome;

final class const VoiceTranscriptionUnexpectedFailure() extends VoiceTranscriptionOutcome;

final class const VoiceTranscriptionEmptyTranscript() extends VoiceTranscriptionOutcome;
