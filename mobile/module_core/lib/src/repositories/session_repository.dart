import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/session_api.dart";

@lazySingleton
class SessionRepository {
  final SessionApi _api;

  SessionRepository({required SessionApi api}) : _api = api;

  Future<ApiResponse<CommandListResponse>> listCommands({required String projectId}) {
    return _api.listCommands(projectId: projectId);
  }

  Future<ApiResponse<Session>> createSessionWithMessage({
    required String projectId,
    required String text,
    required String? agent,
    required PromptModel? model,
    required String? command,
    required bool dedicatedWorktree,
  }) {
    return _api.createSessionWithMessage(
      projectId: projectId,
      text: text,
      agent: agent,
      model: model,
      command: command,
      dedicatedWorktree: dedicatedWorktree,
    );
  }

  Future<ApiResponse<void>> sendMessage({
    required String sessionId,
    required String text,
    required String? agent,
    required String? providerID,
    required String? modelID,
    required String? command,
  }) {
    return _api.sendMessage(
      sessionId: sessionId,
      text: text,
      agent: agent,
      providerID: providerID,
      modelID: modelID,
      command: command,
    );
  }
}
