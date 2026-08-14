import "dart:async";
import "dart:io";

import "package:http/http.dart" as http;
import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../../logging/logging.dart";
import "project_glossary_key.dart";
import "voice_capabilities.dart";

/// Timeout for the transcription upload request.
const _uploadTimeout = Duration(seconds: 120);

const _capabilitiesTimeout = Duration(seconds: 5);

/// API layer for voice endpoints on the auth server.
///
/// Uses [AuthenticatedHttpApiClient] which handles token injection, proactive refresh,
/// and 401 retry automatically — this class never touches tokens directly.
@lazySingleton
class VoiceApi(final AuthenticatedHttpApiClient _client, final HttpApiClient _publicClient) {
  Future<VoiceCapabilitiesDiscoveryResult> discoverCapabilities() async {
    try {
      final response = await _publicClient
          .get(
            Uri.parse("$authBaseUrl/voice/capabilities"),
            fromJson: VoiceCapabilities.parse,
          )
          .timeout(_capabilitiesTimeout);

      return switch (response) {
        SuccessResponse(:final data) when data.supportsProtocol1 => VoiceCapabilitiesAvailable(capabilities: data),
        SuccessResponse() => const VoiceCapabilitiesContractFailure(reason: "Realtime protocol 1 was not advertised"),
        // COMPATIBILITY 2026-08-14 (v1.8.0): auth servers before realtime capability discovery, disabled rollout
        // deployments, and transient public endpoint failures must preserve the legacy async transcription path.
        // Remove only this missing/unavailable capability fallback after every supported auth server exposes protocol 1.
        ErrorResponse() => const VoiceCapabilitiesAsyncFallback(),
      };
    } on TimeoutException {
      return const VoiceCapabilitiesAsyncFallback();
    } on FormatException catch (error) {
      return VoiceCapabilitiesContractFailure(reason: error.message);
    }
  }

  /// Uploads an audio file for transcription.
  ///
  /// [mimeType] is sent as the file's content-type so the server can forward
  /// it to the transcription model (e.g. `"audio/mp4"` for m4a/AAC).
  Future<ApiResponse<String>> transcribe(
    String audioFilePath, {
    required String mimeType,
    required String? projectKey,
    required VoiceCapabilities? capabilities,
  }) async {
    final uri = Uri.parse("$authBaseUrl/voice/transcribe");
    final fields = _transcriptionFields(projectKey: projectKey, capabilities: capabilities);

    try {
      // `await` is required here so async errors thrown inside the returned
      // Future (TimeoutException, SocketException, HandshakeException) are
      // caught by the handlers below. Without the await, the Future's failure
      // escapes this try/catch and propagates to the caller unwrapped.
      return await _client
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
    } on TimeoutException catch (error, stackTrace) {
      loge("Transcription upload timed out", error, stackTrace);
      return ApiResponse.error(ApiError.dartHttpClient(error));
    } on SocketException catch (error, stackTrace) {
      loge("Transcription API socket error", error, stackTrace);
      return ApiResponse.error(ApiError.dartHttpClient(error));
    } on HandshakeException catch (error, stackTrace) {
      loge("Transcription API TLS handshake failed", error, stackTrace);
      return ApiResponse.error(ApiError.dartHttpClient(error));
    }
  }

  static Map<String, String>? _transcriptionFields({
    required String? projectKey,
    required VoiceCapabilities? capabilities,
  }) {
    if (projectKey == null || capabilities == null || !capabilities.supportsProtocol1) {
      return null;
    }
    if (!isValidProjectGlossaryKey(projectKey)) {
      throw ArgumentError.value(projectKey, "projectKey", "Expected opaque project glossary key");
    }
    return {"projectKey": projectKey};
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
