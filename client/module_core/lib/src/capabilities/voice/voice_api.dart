import "dart:async";
import "dart:convert";
import "dart:io";

import "package:http/http.dart" as http;
import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart" show ProjectGlossaryKey;

import "../../logging/logging.dart";
import "voice_transcription_failure_metadata.dart";

/// Timeout for the transcription upload request.
const _uploadTimeout = Duration(seconds: 120);

/// API layer for voice endpoints on the auth server.
///
/// Uses [AuthenticatedHttpApiClient] which handles token injection, proactive refresh,
/// and 401 retry automatically — this class never touches tokens directly.
@lazySingleton
class VoiceApi(final AuthenticatedHttpApiClient _client) {
  /// Uploads an audio file for transcription.
  ///
  /// [mimeType] is sent as the file's content-type so the server can forward
  /// it to the transcription model (e.g. `"audio/mp4"` for m4a/AAC).
  Future<VoiceTranscriptionApiResult> transcribe({
    required String audioFilePath,
    required String mimeType,
    required ProjectGlossaryKey? projectGlossaryKey,
  }) async {
    final uri = Uri.parse("$authBaseUrl/voice/transcribe");
    final fields = _transcriptionFields(projectGlossaryKey: projectGlossaryKey);

    try {
      // `await` is required here so async errors thrown inside the returned
      // Future (TimeoutException, SocketException, HandshakeException) are
      // caught by the handlers below. Without the await, the Future's failure
      // escapes this try/catch and propagates to the caller unwrapped.
      final response = await _client
          .postMultipart(
            uri,
            fromJson: _parseTranscript,
            fields: fields,
            createFiles: () async => [
              await http.MultipartFile.fromPath(
                "audio",
                audioFilePath,
                contentType: http.MediaType.parse(mimeType),
              ),
            ],
            timeout: _uploadTimeout,
          )
          .timeout(_uploadTimeout);
      return switch (response) {
        SuccessResponse(:final data) => VoiceTranscriptionApiResult.success(transcript: data),
        ErrorResponse(:final error) => VoiceTranscriptionApiResult.failure(
          error: error,
          retryable: _parseRetryable(error: error),
        ),
      };
    } on TimeoutException catch (error, stackTrace) {
      loge("Transcription upload timed out", error, stackTrace);
      return VoiceTranscriptionApiResult.failure(
        error: ApiError.dartHttpClient(error),
        retryable: null,
      );
    } on SocketException catch (error, stackTrace) {
      loge("Transcription API socket error", error, stackTrace);
      return VoiceTranscriptionApiResult.failure(
        error: ApiError.dartHttpClient(error),
        retryable: null,
      );
    } on HandshakeException catch (error, stackTrace) {
      loge("Transcription API TLS handshake failed", error, stackTrace);
      return VoiceTranscriptionApiResult.failure(
        error: ApiError.dartHttpClient(error),
        retryable: null,
      );
    }
  }

  static Map<String, String>? _transcriptionFields({
    required ProjectGlossaryKey? projectGlossaryKey,
  }) {
    if (projectGlossaryKey == null) return null;
    return {"projectKey": projectGlossaryKey.value};
  }

  static bool? _parseRetryable({required ApiError error}) {
    final rawError = switch (error) {
      NonSuccessCodeError(:final rawErrorString) => rawErrorString,
      JsonParsingError() ||
      DartHttpClientError() ||
      GenericError() ||
      NotAuthenticatedError() ||
      EmptyResponseError() => null,
    };
    if (rawError == null) return null;

    try {
      final decoded = jsonDecode(rawError);
      // ignore: no_slop_linter/prefer_specific_type, JSON object boundary before typed Freezed parsing
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException("Transcription failure body is not a JSON object");
      }
      return VoiceTranscriptionFailureMetadata.fromJson(decoded).retryable;
    } catch (error, stackTrace) {
      logw("Failed to parse transcription retryability metadata", error, stackTrace);
      return null;
    }
  }

  // ignore: no_slop_linter/prefer_specific_type, JSON parser callback signature requires dynamic input
  static String _parseTranscript(dynamic json) {
    // ignore: no_slop_linter/prefer_specific_type, JSON parsing requires an untyped map value
    if (json is Map<String, Object?>) {
      final textValue = json["text"];
      if (textValue case final String text when text.isNotEmpty) {
        return text;
      }
    }
    throw const FormatException("Missing or empty 'text' field in transcription response");
  }
}

sealed class const VoiceTranscriptionApiResult() {
  const factory success({required String transcript}) = VoiceTranscriptionApiSuccess;

  const factory failure({
    required ApiError error,
    required bool? retryable,
  }) = VoiceTranscriptionApiFailure;
}

final class const VoiceTranscriptionApiSuccess({required final String transcript}) extends VoiceTranscriptionApiResult;

final class const VoiceTranscriptionApiFailure({
  required final ApiError error,
  required final bool? retryable,
}) extends VoiceTranscriptionApiResult;
