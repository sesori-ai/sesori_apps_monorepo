import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart" show ApiResponse;

import "../capabilities/voice/voice_api.dart";
import "project_voice_glossary_service.dart";

/// Coordinates project glossary context with hosted transcription independently
/// of any Flutter recorder or product shell.
@lazySingleton
class HostedVoiceInputService({
  required final VoiceApi _voiceApi,
  required final ProjectVoiceGlossaryService _projectVoiceGlossaryService,
}) {
  int _recordingGeneration = 0;
  String? _recordingProjectId;
  String? _recordingProjectKey;

  /// Starts best-effort glossary preparation after the platform recorder has
  /// started. The detached request never delays capture.
  void recordingStarted({required String? projectId}) {
    final generation = ++_recordingGeneration;
    _recordingProjectId = projectId;
    _recordingProjectKey = null;
    if (projectId == null) return;

    unawaited(
      _projectVoiceGlossaryService.requestPopulation(projectId: projectId).then((projectKey) {
        if (generation != _recordingGeneration || _recordingProjectId != projectId) return;
        _recordingProjectKey = projectKey;
      }),
    );
  }

  /// Uploads the recorded file with the key resolved for this exact recording.
  /// A pending, invalid, or unsupported glossary request remains unscoped.
  Future<ApiResponse<String>> transcribe({
    required String audioFilePath,
    required String mimeType,
    required String? projectId,
  }) {
    return _voiceApi.transcribe(
      audioFilePath: audioFilePath,
      mimeType: mimeType,
      projectKey: projectId == _recordingProjectId ? _recordingProjectKey : null,
    );
  }

  /// Invalidates late glossary responses when capture/transcription finishes or
  /// is cancelled.
  void recordingFinished() {
    _recordingGeneration++;
    _recordingProjectId = null;
    _recordingProjectKey = null;
  }
}
