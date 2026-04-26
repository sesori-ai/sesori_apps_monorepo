import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../repositories/session_repository.dart";

@lazySingleton
class SessionService {
  final SessionRepository _repository;

  SessionService({required SessionRepository repository}) : _repository = repository;

  Future<ApiResponse<Session>> archiveSession({
    required String sessionId,
    required bool deleteWorktree,
    required bool deleteBranch,
    required bool force,
  }) {
    return _repository.archiveSession(
      sessionId: sessionId,
      deleteWorktree: deleteWorktree,
      deleteBranch: deleteBranch,
      force: force,
    );
  }

  Future<ApiResponse<Session>> unarchiveSession({required String sessionId}) {
    return _repository.unarchiveSession(sessionId: sessionId);
  }

  Future<ApiResponse<Session>> renameSession({required String sessionId, required String title}) {
    return _repository.renameSession(sessionId: sessionId, title: title);
  }

  Future<ApiResponse<void>> deleteSession({
    required String sessionId,
    required bool deleteWorktree,
    required bool deleteBranch,
    required bool force,
  }) {
    return _repository.deleteSession(
      sessionId: sessionId,
      deleteWorktree: deleteWorktree,
      deleteBranch: deleteBranch,
      force: force,
    );
  }

  Future<ApiResponse<void>> abortSession({required String sessionId}) {
    return _repository.abortSession(sessionId: sessionId);
  }

  Future<ApiResponse<void>> replyToQuestion({
    required String requestId,
    required String sessionId,
    required List<ReplyAnswer> answers,
  }) {
    return _repository.replyToQuestion(requestId: requestId, sessionId: sessionId, answers: answers);
  }

  Future<ApiResponse<void>> rejectQuestion({required String requestId}) {
    return _repository.rejectQuestion(requestId: requestId);
  }

  Future<ApiResponse<MessageWithPartsResponse>> getMessages({required String sessionId}) {
    return _repository.getMessages(sessionId: sessionId);
  }

  Future<ApiResponse<PendingQuestionResponse>> getPendingQuestions({required String sessionId}) {
    return _repository.getPendingQuestions(sessionId: sessionId);
  }

  Future<ApiResponse<PendingPermissionResponse>> getPendingPermissions() {
    return _repository.getPendingPermissions();
  }

  Future<ApiResponse<SessionListResponse>> getChildren({required String sessionId}) {
    return _repository.getChildren(sessionId: sessionId);
  }

  Future<ApiResponse<SessionStatusResponse>> getSessionStatuses() {
    return _repository.getSessionStatuses();
  }

  Future<ApiResponse<Agents>> listAgents() {
    return _repository.listAgents();
  }

  Future<ApiResponse<ProviderListResponse>> listProviders({required String projectId}) {
    return _repository.listProviders(projectId: projectId);
  }

  Future<ApiResponse<CommandListResponse>> listCommands({required String? projectId}) {
    final normalizedProjectId = _normalizeOptionalText(projectId);
    if (normalizedProjectId == null) {
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
    required SessionVariant? variant,
    required String? command,
    required bool dedicatedWorktree,
  }) {
    final normalizedCommand = _normalizeOptionalText(command);
    return _repository.createSessionWithMessage(
      projectId: projectId,
      text: text,
      agent: agent,
      model: _resolveModel(providerID: providerID, modelID: modelID),
      variant: variant,
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
    required SessionVariant? variant,
    required String? command,
  }) {
    final normalizedCommand = _normalizeOptionalText(command);
    return _repository.sendMessage(
      sessionId: sessionId,
      text: text,
      agent: agent,
      model: _resolveModel(providerID: providerID, modelID: modelID),
      variant: variant,
      command: normalizedCommand,
    );
  }

  PromptModel? _resolveModel({required String? providerID, required String? modelID}) {
    final normalizedProviderID = _normalizeOptionalText(providerID);
    final normalizedModelID = _normalizeOptionalText(modelID);
    if (normalizedProviderID == null || normalizedModelID == null) return null;
    return PromptModel(providerID: normalizedProviderID, modelID: normalizedModelID);
  }
}

String? _normalizeOptionalText(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}
