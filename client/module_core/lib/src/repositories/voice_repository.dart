import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart" show ApiResponse;

import "../capabilities/voice/voice_api.dart";

/// Layer-2 access to hosted voice transcription.
@lazySingleton
class VoiceRepository({required final VoiceApi _api}) {
  Future<ApiResponse<String>> transcribe({
    required String audioFilePath,
    required String mimeType,
    required String? projectKey,
  }) => _api.transcribe(
    audioFilePath: audioFilePath,
    mimeType: mimeType,
    projectKey: projectKey,
  );
}
