import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";

@lazySingleton
class SlashCommandService {
  final SessionRepository _repository;

  SlashCommandService({required SessionRepository repository}) : _repository = repository;

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
    final normalizedCommand = _normalizeOptionalText(command);
    return _repository.createSessionWithMessage(
      projectId: projectId,
      text: text,
      agent: agent,
      model: _resolveModel(
        providerID: providerID,
        modelID: modelID,
      ),
      command: normalizedCommand,
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
    final normalizedCommand = _normalizeOptionalText(command);
    return _repository.sendMessage(
      sessionId: sessionId,
      text: text,
      agent: agent,
      providerID: _normalizeOptionalText(providerID),
      modelID: _normalizeOptionalText(modelID),
      command: normalizedCommand,
    );
  }

  String? _normalizeOptionalText(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  PromptModel? _resolveModel({required String? providerID, required String? modelID}) {
    if (providerID == null || providerID.isEmpty) return null;
    if (modelID == null || modelID.isEmpty) return null;
    return PromptModel(providerID: providerID, modelID: modelID);
  }
}
