import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/session_api.dart";
import "models/session_options_repository_result.dart";

@lazySingleton
class SessionRepository {
  final SessionApi _api;

  SessionRepository({
    required SessionApi api,
  }) : _api = api;

  Future<ApiResponse<Session>> archiveSession({
    required String sessionId,
    required bool deleteWorktree,
    required bool deleteBranch,
    required bool force,
  }) {
    return _api.archiveSession(
      sessionId: sessionId,
      deleteWorktree: deleteWorktree,
      deleteBranch: deleteBranch,
      force: force,
    );
  }

  Future<ApiResponse<Session>> unarchiveSession({required String sessionId}) {
    return _api.unarchiveSession(sessionId: sessionId);
  }

  Future<ApiResponse<Session>> renameSession({required String sessionId, required String title}) {
    return _api.renameSession(sessionId: sessionId, title: title);
  }

  Future<ApiResponse<void>> deleteSession({
    required String sessionId,
    required bool deleteWorktree,
    required bool deleteBranch,
    required bool force,
  }) {
    return _api.deleteSession(
      sessionId: sessionId,
      deleteWorktree: deleteWorktree,
      deleteBranch: deleteBranch,
      force: force,
    );
  }

  Future<ApiResponse<void>> abortSession({required String sessionId}) {
    return _api.abortSession(sessionId: sessionId);
  }

  Future<ApiResponse<void>> markSessionSeen({required String sessionId, required bool read}) {
    return _api.markSessionSeen(sessionId: sessionId, read: read);
  }

  Future<ApiResponse<void>> replyToQuestion({
    required String requestId,
    required String sessionId,
    required List<ReplyAnswer> answers,
  }) {
    return _api.replyToQuestion(requestId: requestId, sessionId: sessionId, answers: answers);
  }

  Future<ApiResponse<void>> rejectQuestion({required String requestId, required String sessionId}) {
    return _api.rejectQuestion(requestId: requestId, sessionId: sessionId);
  }

  Future<ApiResponse<MessageWithPartsResponse>> getMessages({required String sessionId}) {
    return _api.getMessages(sessionId: sessionId);
  }

  Future<ApiResponse<PendingQuestionResponse>> getPendingQuestions({required String sessionId}) {
    return _api.getPendingQuestions(sessionId: sessionId);
  }

  Future<ApiResponse<PendingPermissionResponse>> getPendingPermissions({required String sessionId}) {
    return _api.getPendingPermissions(sessionId: sessionId);
  }

  Future<ApiResponse<SessionListResponse>> getChildren({required String sessionId}) {
    return _api.getChildren(sessionId: sessionId);
  }

  Future<ApiResponse<SessionStatusResponse>> getSessionStatuses() {
    return _api.getSessionStatuses();
  }

  Future<ApiResponse<SessionDiffsResponse>> getSessionDiffs({required String sessionId}) {
    return _api.getSessionDiffs(sessionId: sessionId);
  }

  Future<ApiResponse<Session>> getSession({required String sessionId}) {
    return _api.getSession(sessionId: sessionId);
  }

  Future<ApiResponse<Agents>> listAgents({required String projectId, required String pluginId}) {
    return _api.listAgents(projectId: projectId, pluginId: pluginId);
  }

  Future<ApiResponse<ProviderListResponse>> listProviders({
    required String projectId,
    required String pluginId,
  }) {
    return _api.listProviders(projectId: projectId, pluginId: pluginId);
  }

  Future<ApiResponse<CommandListResponse>> listCommands({required String projectId, required String pluginId}) {
    return _api.listCommands(projectId: projectId, pluginId: pluginId);
  }

  Future<LegacySessionOptionsRepositoryResult> loadLegacySessionOptions({
    required String projectId,
    required String pluginId,
  }) async {
    final (agents, providers, commands) = await (
      _api.listAgents(projectId: projectId, pluginId: pluginId),
      _api.listProviders(projectId: projectId, pluginId: pluginId),
      _api.listCommands(projectId: projectId, pluginId: pluginId),
    ).wait;
    return switch ((agents, providers, commands)) {
      (
        SuccessResponse(data: final agentData),
        SuccessResponse(data: final providerData),
        SuccessResponse(data: final commandData),
      ) =>
        LegacySessionOptionsRepositoryAvailable(
          catalog: SessionOptionsCatalog(
            agents: agentData.agents,
            providers: providerData.items,
            commands: commandData.items,
          ),
        ),
      (ErrorResponse(:final error), _, _) => LegacySessionOptionsRepositoryFailure(error: error),
      (_, ErrorResponse(:final error), _) => LegacySessionOptionsRepositoryFailure(error: error),
      (_, _, ErrorResponse(:final error)) => LegacySessionOptionsRepositoryFailure(error: error),
    };
  }

  Future<SessionOptionsRepositoryResult> loadSessionOptions({
    required String projectId,
    required String pluginId,
    required bool forceRefresh,
  }) async {
    final response = await _api.loadSessionOptions(
      projectId: projectId,
      pluginId: pluginId,
      forceRefresh: forceRefresh,
    );
    return switch (response) {
      SuccessResponse(:final data) => SessionOptionsRepositoryAvailable(
        catalog: SessionOptionsCatalog(
          agents: data.agents.agents,
          providers: data.providers.items,
          commands: data.commands.items,
        ),
      ),
      ErrorResponse(:final error) => _mapSessionOptionsError(error: error),
    };
  }

  SessionOptionsRepositoryResult _mapSessionOptionsError({required ApiError error}) {
    if (error case NonSuccessCodeError(:final rawErrorString)) {
      try {
        if (rawErrorString == null) return SessionOptionsRepositoryFailure(error: error);
        final response = SessionOptionsErrorResponse.fromJson(jsonDecodeMap(rawErrorString));
        return switch (response.code) {
          SessionOptionsErrorCode.cacheUnavailable => const SessionOptionsRepositoryCacheUnavailable(),
          SessionOptionsErrorCode.projectNotFound => SessionOptionsRepositoryProjectNotFound(error: error),
          SessionOptionsErrorCode.refreshFailedRetained => const SessionOptionsRepositoryRefreshFailedRetained(),
          SessionOptionsErrorCode.refreshFailedUnavailable => const SessionOptionsRepositoryRefreshFailedUnavailable(),
          SessionOptionsErrorCode.unknown => SessionOptionsRepositoryFailure(error: error),
        };
      } on Object {
        // The original transport error remains the explicit observable failure.
      }
    }
    return SessionOptionsRepositoryFailure(error: error);
  }

  Future<ApiResponse<Session>> createSessionWithMessage({
    required String projectId,
    required String pluginId,
    required String text,
    required String? agent,
    required PromptModel? model,
    required SessionVariant? variant,
    required String? command,
    required bool dedicatedWorktree,
  }) {
    return _api.createSessionWithMessage(
      projectId: projectId,
      pluginId: pluginId,
      text: text,
      agent: agent,
      model: model,
      variant: variant,
      command: command,
      dedicatedWorktree: dedicatedWorktree,
    );
  }

  Future<ApiResponse<void>> sendMessage({
    required String sessionId,
    required String text,
    required String? agent,
    required PromptModel? model,
    required SessionVariant? variant,
    required String? command,
  }) {
    return _api.sendMessage(
      sessionId: sessionId,
      text: text,
      agent: agent,
      model: model,
      variant: variant,
      command: command,
    );
  }
}
