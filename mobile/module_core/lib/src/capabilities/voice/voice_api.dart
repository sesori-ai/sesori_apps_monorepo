import "dart:async";
import "dart:io";

import "package:http/http.dart" as http;
import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../../logging/logging.dart";

/// Timeout for the transcription upload request.
const _uploadTimeout = Duration(seconds: 30);

/// API layer for voice endpoints on the auth server.
///
/// Uses [AuthenticatedHttpApiClient] which handles token injection, proactive refresh,
/// and 401 retry automatically — this class never touches tokens directly.
@lazySingleton
class VoiceApi {
  final AuthenticatedHttpApiClient _client;

  VoiceApi(AuthenticatedHttpApiClient client) : _client = client;

  /// Uploads an audio file for transcription.
  ///
  /// [mimeType] is sent as the file's content-type so the server can forward
  /// it to the transcription model (e.g. `"audio/mp4"` for m4a/AAC).
  Future<ApiResponse<String>> transcribe(String audioFilePath, {required String mimeType}) async {
    final uri = Uri.parse("$authBaseUrl/voice/transcribe");

    try {
      // `await` is required here so async errors thrown inside the returned
      // Future (TimeoutException, SocketException, HandshakeException) are
      // caught by the handlers below. Without the await, the Future's failure
      // escapes this try/catch and propagates to the caller unwrapped.
      return await _client.postMultipart(
        uri,
        fromJson: _parseTranscript,
        createFiles: () async => [
          await http.MultipartFile.fromPath(
            "audio",
            audioFilePath,
            contentType: http.MediaType.parse(mimeType),
          ),
        ],
        timeout: _uploadTimeout,
      );
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

  // ignore: no_slop_linter/avoid_dynamic_type, JSON parser callback signature requires dynamic input
  static String _parseTranscript(dynamic json) {
    // ignore: no_slop_linter/avoid_dynamic_type, JSON parsing requires dynamic
    if (json is Map<String, dynamic>) {
      final textValue = json["text"];
      if (textValue case final String text when text.isNotEmpty) {
        return text;
      }
    }
    throw const FormatException("Missing or empty 'text' field in transcription response");
  }
}
