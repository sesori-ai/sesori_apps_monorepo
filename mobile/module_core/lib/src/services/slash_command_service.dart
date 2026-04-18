import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/slash_command_repository.dart";

@lazySingleton
class SlashCommandService {
  final SlashCommandRepository _repository;

  SlashCommandService({required SlashCommandRepository repository}) : _repository = repository;

  Future<ApiResponse<CommandListResponse>> listCommands({required String? projectId}) {
    final normalizedProjectId = projectId?.trim();
    if (normalizedProjectId == null || normalizedProjectId.isEmpty) {
      return Future.value(ApiResponse.success(const CommandListResponse(items: <CommandInfo>[])));
    }

    return _repository.listCommands(projectId: normalizedProjectId);
  }

  Future<ApiResponse<Session>> createSessionWithMessage({
    required String projectId,
    required String text,
    required String? agent,
    required String? providerID,
    required String? modelID,
    required String? command,
    required bool dedicatedWorktree,
  }) {
    return _repository.createSessionWithMessage(
      projectId: projectId,
      text: text,
      agent: command != null ? null : agent,
      model: _resolveModel(
        command: command,
        providerID: providerID,
        modelID: modelID,
      ),
      command: command?.trim(),
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
    return _repository.sendMessage(
      sessionId: sessionId,
      text: text,
      agent: command != null ? null : agent,
      providerID: command != null ? null : providerID,
      modelID: command != null ? null : modelID,
      command: command?.trim(),
    );
  }

  PromptModel? _resolveModel({
    required String? command,
    required String? providerID,
    required String? modelID,
  }) {
    if (command != null) return null;
    if (providerID == null || providerID.isEmpty) return null;
    if (modelID == null || modelID.isEmpty) return null;
    return PromptModel(providerID: providerID, modelID: modelID);
  }
}
