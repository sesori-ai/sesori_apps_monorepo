import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../capabilities/voice/voice_api.dart";

@lazySingleton
class VoiceRepository({required final VoiceApi _api}) {
  Future<VoiceTranscriptionOutcome> transcribe({
    required String audioFilePath,
    required String mimeType,
  }) async {
    final response = await _api.transcribe(audioFilePath: audioFilePath, mimeType: mimeType);
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
