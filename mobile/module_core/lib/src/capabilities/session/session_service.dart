import "dart:convert";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../api/client/relay_http_client.dart";

class SessionCleanupRejectedException implements Exception {
  final SessionCleanupRejection rejection;

  const SessionCleanupRejectedException({required this.rejection});
}

@lazySingleton
class SessionService {
  final RelayHttpApiClient _client;

  SessionService(RelayHttpApiClient client) : _client = client;

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

  /// Lists sessions for the current project.
  Future<ApiResponse<SessionListResponse>> listSessions({required String projectId}) {
    return _client.post(
      "/sessions",
      fromJson: SessionListResponse.fromJson,
      body: SessionListRequest(projectId: projectId, start: null, limit: null),
    );
  }

  Future<ApiResponse<Session>> createSessionWithMessage({
    required String projectId,
    required String text,
    required String? agent,
    required PromptModel? model,
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
        dedicatedWorktree: dedicatedWorktree,
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

  Future<ApiResponse<Session>> unarchiveSession(String sessionId) {
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

  Future<ApiResponse<Session>> renameSession({
    required String sessionId,
    required String title,
  }) {
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
      } on Object {
        return;
      }
    }
  }

  Future<ApiResponse<SessionListResponse>> getChildren(String sessionId) {
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

  Future<ApiResponse<MessageWithPartsResponse>> getMessages(String sessionId) {
    return _client.post(
      "/session/messages",
      fromJson: MessageWithPartsResponse.fromJson,
      body: SessionIdRequest(sessionId: sessionId),
    );
  }

  // ignore: no_slop_linter/prefer_required_named_parameters, public API with optional model selection
  Future<ApiResponse<void>> sendMessage(
    String sessionId,
    String text, {
    String? agent,
    String? providerID,
    String? modelID,
  }) {
    return _client.post(
      "/session/prompt_async",
      fromJson: SuccessEmptyResponse.fromJson,
      body: SendPromptRequest(
        sessionId: sessionId,
        parts: [PromptPart.text(text: text)],
        agent: agent,
        model: providerID != null && modelID != null ? PromptModel(providerID: providerID, modelID: modelID) : null,
      ),
    );
  }

  Future<ApiResponse<SuccessEmptyResponse>> abortSession(String sessionId) {
    return _client.post(
      "/session/abort",
      fromJson: SuccessEmptyResponse.fromJson,
      body: SessionIdRequest(sessionId: sessionId),
    );
  }

  Future<ApiResponse<PendingQuestionResponse>> getPendingQuestions(String sessionId) {
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

  Future<ApiResponse<void>> rejectQuestion(String requestId) {
    return _client.post(
      "/question/reject",
      fromJson: SuccessEmptyResponse.fromJson,
      body: RejectQuestionRequest(requestId: requestId),
    );
  }
}
