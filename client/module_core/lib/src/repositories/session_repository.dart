import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/session_api.dart";

@lazySingleton
class SessionRepository {
  final SessionApi _api;
  final _providerCache = <String, ProviderListResponse>{};

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

  Future<ApiResponse<Agents>> listAgents({required String projectId}) {
    return _api.listAgents(projectId: projectId);
  }

  Future<ApiResponse<ProviderListResponse>> listProviders({required String projectId}) async {
    if (_providerCache[projectId] case final providersCache?) {
      return ApiResponse.success(providersCache);
    }

    final response = await _api.listProviders(projectId: projectId);

    // Only cache a response that actually carries models. Some backends build
    // their model catalog asynchronously (e.g. the Cursor/ACP plugin warms it
    // from an existing session after the agent connects), so an early fetch can
    // succeed with an empty list. Caching that empty result — permanently, since
    // this repository is a lazy singleton — would leave the model picker blank
    // forever for that project. Skipping the cache lets the next open retry and
    // pick up the catalog once it is ready.
    if (response is SuccessResponse<ProviderListResponse> &&
        response.data.items.any((provider) => provider.models.isNotEmpty)) {
      _providerCache[projectId] = response.data;
    }

    return response;
  }

  Future<ApiResponse<CommandListResponse>> listCommands({required String projectId}) {
    return _api.listCommands(projectId: projectId);
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
    return _api.createSessionWithMessage(
      projectId: projectId,
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
