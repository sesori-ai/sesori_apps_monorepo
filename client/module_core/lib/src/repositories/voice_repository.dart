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
      SuccessResponse(:final data) => VoiceTranscriptionOutcome.success(transcript: data),
      ErrorResponse(:final error) => _mapError(error: error),
    };
  }

  VoiceTranscriptionOutcome _mapError({required ApiError error}) => switch (error) {
    NotAuthenticatedError() => const VoiceTranscriptionOutcome.notAuthenticated(),
    NonSuccessCodeError(:final errorCode) => VoiceTranscriptionOutcome.serverFailure(statusCode: errorCode),
    DartHttpClientError() || GenericError() => const VoiceTranscriptionOutcome.networkFailure(),
    JsonParsingError() || EmptyResponseError() => const VoiceTranscriptionOutcome.emptyTranscript(),
  };
}

sealed class const VoiceTranscriptionOutcome() {
  const factory success({required String transcript}) = VoiceTranscriptionSuccess;

  const factory notAuthenticated() = VoiceTranscriptionNotAuthenticated;

  const factory serverFailure({required int statusCode}) = VoiceTranscriptionServerFailure;

  const factory networkFailure() = VoiceTranscriptionNetworkFailure;

  const factory emptyTranscript() = VoiceTranscriptionEmptyTranscript;
}

final class const VoiceTranscriptionSuccess({required final String transcript}) extends VoiceTranscriptionOutcome;

final class const VoiceTranscriptionNotAuthenticated() extends VoiceTranscriptionOutcome;

final class const VoiceTranscriptionServerFailure({required final int statusCode}) extends VoiceTranscriptionOutcome;

final class const VoiceTranscriptionNetworkFailure() extends VoiceTranscriptionOutcome;

final class const VoiceTranscriptionEmptyTranscript() extends VoiceTranscriptionOutcome;
