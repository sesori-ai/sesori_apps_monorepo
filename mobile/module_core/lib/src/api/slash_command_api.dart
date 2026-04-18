import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "client/relay_http_client.dart";

@lazySingleton
class SlashCommandApi {
  final RelayHttpApiClient _client;

  SlashCommandApi({required RelayHttpApiClient client}) : _client = client;

  Future<ApiResponse<CommandListResponse>> listCommands({required String projectId}) {
    return _client.post(
      "/command",
      fromJson: CommandListResponse.fromJson,
      body: ProjectIdRequest(projectId: projectId),
    );
  }

  Future<ApiResponse<Session>> createSessionWithMessage({
    required String projectId,
    required String text,
    required String? agent,
    required PromptModel? model,
    required String? command,
    required bool dedicatedWorktree,
  }) {
    return _client.post(
      "/session/create",
      fromJson: Session.fromJson,
      body: CreateSessionRequest(
        projectId: projectId,
        parts: [PromptPart.text(text: text)],
        agent: agent,
        model: model,
        command: command,
        dedicatedWorktree: dedicatedWorktree,
      ),
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
    return _client.post(
      "/session/prompt_async",
      fromJson: SuccessEmptyResponse.fromJson,
      body: SendPromptRequest(
        sessionId: sessionId,
        parts: [PromptPart.text(text: text)],
        agent: agent,
        model: providerID != null && modelID != null ? PromptModel(providerID: providerID, modelID: modelID) : null,
        command: command,
      ),
    );
  }
}
