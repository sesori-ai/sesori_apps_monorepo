import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../logging/logging.dart";
import "client/relay_http_client.dart";

class SessionCleanupRejectedException implements Exception {
  final SessionCleanupRejection rejection;

  const SessionCleanupRejectedException({required this.rejection});
}

@lazySingleton
class SessionApi {
  final RelayHttpApiClient _client;

  SessionApi({required RelayHttpApiClient client}) : _client = client;

  Future<ApiResponse<Agents>> listAgents() {
    return _client.get(
      "/agent",
      fromJson: Agents.fromJson,
    );
  }

  Future<ApiResponse<ProviderListResponse>> listProviders() {
    return _client.get(
      "/provider",
      fromJson: ProviderListResponse.fromJson,
    );
  }

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
    required SessionVariant? variant,
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
        variant: variant,
        command: command,
        dedicatedWorktree: dedicatedWorktree,
      ),
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
    return _client.post(
      "/session/prompt_async",
      fromJson: SuccessEmptyResponse.fromJson,
      body: SendPromptRequest(
        sessionId: sessionId,
        parts: [PromptPart.text(text: text)],
        agent: agent,
        model: model,
        variant: variant,
        command: command,
      ),
    );
  }

  Future<ApiResponse<Session>> archiveSession({
    required String sessionId,
    required bool deleteWorktree,
    required bool deleteBranch,
    required bool force,
  }) async {
    final response = await _client.patch(
      "/session/update/archive",
      fromJson: Session.fromJson,
      body: UpdateSessionArchiveRequest(
        sessionId: sessionId,
        archived: true,
        deleteWorktree: deleteWorktree,
        deleteBranch: deleteBranch,
        force: force,
      ),
    );

    _throwIfCleanupRejected(response);
    return response;
  }

  Future<ApiResponse<Session>> unarchiveSession({required String sessionId}) {
    return _client.patch(
      "/session/update/archive",
      fromJson: Session.fromJson,
      body: UpdateSessionArchiveRequest(
        sessionId: sessionId,
        archived: false,
        deleteWorktree: false,
        deleteBranch: false,
        force: false,
      ),
    );
  }

  Future<ApiResponse<Session>> renameSession({required String sessionId, required String title}) {
    return _client.patch(
      "/session/title",
      fromJson: Session.fromJson,
      body: RenameSessionRequest(sessionId: sessionId, title: title),
    );
  }

  Future<ApiResponse<void>> deleteSession({
    required String sessionId,
    required bool deleteWorktree,
    required bool deleteBranch,
    required bool force,
  }) async {
    final response = await _client.delete(
      "/session/delete",
      fromJson: SuccessEmptyResponse.fromJson,
      body: DeleteSessionRequest(
        sessionId: sessionId,
        deleteWorktree: deleteWorktree,
        deleteBranch: deleteBranch,
        force: force,
      ),
    );

    _throwIfCleanupRejected(response);
    return response;
  }

  void _throwIfCleanupRejected<T>(ApiResponse<T> response) {
    if (response case ErrorResponse(error: NonSuccessCodeError(errorCode: 409, rawErrorString: final rawBody))) {
      try {
        if (rawBody == null) {
          throw const FormatException("invalid cleanup rejection json");
        }
        final rejection = SessionCleanupRejection.fromJson(jsonDecodeMap(rawBody));
        throw SessionCleanupRejectedException(rejection: rejection);
      } on SessionCleanupRejectedException {
        rethrow;
      } on Object catch (e) {
        logw("Failed to parse 409 cleanup rejection body: $e");
        return;
      }
    }
  }

  Future<ApiResponse<SessionListResponse>> getChildren({required String sessionId}) {
    return _client.post(
      "/session/children",
      fromJson: SessionListResponse.fromJson,
      body: SessionIdRequest(sessionId: sessionId),
    );
  }

  Future<ApiResponse<SessionStatusResponse>> getSessionStatuses() {
    return _client.get(
      "/session/status",
      fromJson: SessionStatusResponse.fromJson,
    );
  }

  Future<ApiResponse<SessionDiffsResponse>> getSessionDiffs({required String sessionId}) {
    return _client.post(
      "/session/diffs",
      fromJson: SessionDiffsResponse.fromJson,
      body: SessionIdRequest(sessionId: sessionId),
    );
  }

  Future<ApiResponse<MessageWithPartsResponse>> getMessages({required String sessionId}) {
    return _client.post(
      "/session/messages",
      fromJson: MessageWithPartsResponse.fromJson,
      body: SessionIdRequest(sessionId: sessionId),
    );
  }

  Future<ApiResponse<SuccessEmptyResponse>> abortSession({required String sessionId}) {
    return _client.post(
      "/session/abort",
      fromJson: SuccessEmptyResponse.fromJson,
      body: SessionIdRequest(sessionId: sessionId),
    );
  }

  Future<ApiResponse<PendingQuestionResponse>> getPendingQuestions({required String sessionId}) {
    return _client.post(
      "/session/questions",
      fromJson: PendingQuestionResponse.fromJson,
      body: SessionIdRequest(sessionId: sessionId),
    );
  }

  Future<ApiResponse<void>> replyToQuestion({
    required String requestId,
    required String sessionId,
    required List<ReplyAnswer> answers,
  }) {
    return _client.post(
      "/question/reply",
      fromJson: SuccessEmptyResponse.fromJson,
      body: ReplyToQuestionRequest(requestId: requestId, sessionId: sessionId, answers: answers),
    );
  }

  Future<ApiResponse<void>> rejectQuestion({required String requestId}) {
    return _client.post(
      "/question/reject",
      fromJson: SuccessEmptyResponse.fromJson,
      body: RejectQuestionRequest(requestId: requestId),
    );
  }
}
