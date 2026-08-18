import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/session_api.dart";
import "../foundation/models/composer/composer_attachment.dart";
import "../foundation/models/session_options/session_options_request_mode.dart";
import "models/session_options_repository_result.dart";

@lazySingleton
class SessionRepository({
  required final SessionApi _api,
}) {
  Future<ApiResponse<Session>> archiveSession({
    required String sessionId,
    required bool deleteWorktree,
    required bool force,
  }) {
    return _api.archiveSession(
      sessionId: sessionId,
      deleteWorktree: deleteWorktree,
      force: force,
    );
  }

  Future<ApiResponse<Session>> renameSession({required String sessionId, required String title}) {
    return _api.renameSession(sessionId: sessionId, title: title);
  }

  Future<ApiResponse<void>> deleteSession({
    required String sessionId,
    required bool deleteWorktree,
    required bool force,
  }) {
    return _api.deleteSession(
      sessionId: sessionId,
      deleteWorktree: deleteWorktree,
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

  Future<ApiResponse<MessageWithPartsResponse>> getMessages({
    required String sessionId,
    required int? limit,
    required int? before,
  }) {
    return _api.getMessages(sessionId: sessionId, limit: limit, before: before);
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
    final catalog = SessionOptionsCatalog(
      agents: switch (agents) {
        SuccessResponse(:final data) => data.agents,
        ErrorResponse() => const <AgentInfo>[],
      },
      providers: switch (providers) {
        SuccessResponse(:final data) => data.items,
        ErrorResponse() => const <ProviderInfo>[],
      },
      providersConnectedOnly: switch (providers) {
        SuccessResponse(:final data) => data.connectedOnly,
        ErrorResponse() => false,
      },
      commands: switch (commands) {
        SuccessResponse(:final data) => data.items,
        ErrorResponse() => const <CommandInfo>[],
      },
    );
    final errors = <LegacySessionOptionError>[
      if (agents case ErrorResponse(:final error))
        LegacySessionOptionError(source: LegacySessionOptionSource.agents, error: error),
      if (providers case ErrorResponse(:final error))
        LegacySessionOptionError(source: LegacySessionOptionSource.providers, error: error),
      if (commands case ErrorResponse(:final error))
        LegacySessionOptionError(source: LegacySessionOptionSource.commands, error: error),
    ];
    if (errors.isEmpty) return LegacySessionOptionsRepositoryAvailable(catalog: catalog);
    final anyAvailable = agents is SuccessResponse || providers is SuccessResponse || commands is SuccessResponse;
    return anyAvailable
        ? LegacySessionOptionsRepositoryPartial(catalog: catalog, errors: errors)
        : LegacySessionOptionsRepositoryFailure(errors: errors);
  }

  Future<SessionOptionsRepositoryResult> loadSessionOptions({
    required String projectId,
    required String pluginId,
    required SessionOptionsRequestMode mode,
  }) async {
    final response = await _api.loadSessionOptions(
      projectId: projectId,
      pluginId: pluginId,
      mode: mode,
    );
    return _mapSessionOptionsResponse(response: response);
  }

  SessionOptionsRepositoryResult _mapSessionOptionsResponse({
    required ApiResponse<SessionOptionsResponse> response,
  }) {
    return switch (response) {
      SuccessResponse(:final data) => SessionOptionsRepositoryAvailable(
        catalog: SessionOptionsCatalog(
          agents: data.agents.agents,
          providers: data.providers.items,
          providersConnectedOnly: data.providers.connectedOnly,
          commands: data.commands.items,
        ),
      ),
      ErrorResponse(:final error) => _mapSessionOptionsError(error: error),
    };
  }

  SessionOptionsRepositoryResult _mapSessionOptionsError({required ApiError error}) {
    if (error case NonSuccessCodeError(:final errorCode, :final rawErrorString)) {
      if (rawErrorString != null) {
        try {
          final response = SessionOptionsErrorResponse.fromJson(jsonDecodeMap(rawErrorString));
          return switch (response.code) {
            SessionOptionsErrorCode.cacheUnavailable => const SessionOptionsRepositoryCacheUnavailable(),
            SessionOptionsErrorCode.projectNotFound => SessionOptionsRepositoryProjectNotFound(error: error),
            SessionOptionsErrorCode.refreshFailedRetained => const SessionOptionsRepositoryRefreshFailedRetained(),
            SessionOptionsErrorCode.refreshFailedUnavailable =>
              const SessionOptionsRepositoryRefreshFailedUnavailable(),
            SessionOptionsErrorCode.unknown => SessionOptionsRepositoryFailure(error: error),
          };
        } on Object {
          // Route absence is classified below; other transport failures retain
          // the original error as their explicit observable outcome.
        }
      }
      if (errorCode == 404) return const SessionOptionsRepositoryUnsupported();
    }
    return SessionOptionsRepositoryFailure(error: error);
  }

  Future<ApiResponse<Session>> createSessionWithMessage({
    required String projectId,
    required String pluginId,
    required String text,
    required List<ComposerAttachment> attachments,
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
      attachments: attachments,
      agent: agent,
      model: model,
      variant: variant,
      command: command,
      dedicatedWorktree: dedicatedWorktree,
    );
  }

  Future<ApiResponse<void>> sendMessage({
    required String sessionId,
    required String promptId,
    required String text,
    required List<ComposerAttachment> attachments,
    required String? agent,
    required PromptModel? model,
    required SessionVariant? variant,
    required String? command,
  }) {
    return _api.sendMessage(
      sessionId: sessionId,
      promptId: promptId,
      text: text,
      attachments: attachments,
      agent: agent,
      model: model,
      variant: variant,
      command: command,
    );
  }

  Future<ApiResponse<QueuedPromptResponse>> getQueuedPrompts({required String sessionId}) {
    return _api.getQueuedPrompts(sessionId: sessionId);
  }

  Future<ApiResponse<void>> cancelQueuedPrompt({required String sessionId, required String promptId}) {
    return _api.cancelQueuedPrompt(sessionId: sessionId, promptId: promptId);
  }
}
