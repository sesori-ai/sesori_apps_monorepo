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

  Future<ApiResponse<List<AgentInfo>>> listAgents() {
    return _client.get(
      "/agent",
      fromJson: (json) => switch (json) {
        final List<dynamic> list =>
          list
              .map(
                (e) => switch (e) {
                  final Map<String, dynamic> map => AgentInfo.fromJson(map),
                  _ => throw FormatException("expected map, got ${e.runtimeType}"),
                },
              )
              .toList(),
        _ => throw FormatException("expected list, got ${json.runtimeType}"),
      },
    );
  }

  Future<ApiResponse<ProviderListResponse>> listProviders() {
    return _client.get(
      "/provider",
      fromJson: (json) => switch (json) {
        final Map<String, dynamic> map => ProviderListResponse.fromJson(map),
        _ => throw FormatException("expected map, got ${json.runtimeType}"),
      },
    );
  }

  /// Lists sessions for the current project.
  ///
  /// Project scoping is passed via the `x-project-id` header.
  Future<ApiResponse<List<Session>>> listSessions({required String projectId}) {
    return _client.get(
      "/session",
      fromJson: (json) => switch (json) {
        final List<dynamic> list =>
          list
              .map(
                (e) => switch (e) {
                  final Map<String, dynamic> map => Session.fromJson(map),
                  _ => throw FormatException("expected map, got ${e.runtimeType}"),
                },
              )
              .toList(),
        _ => throw FormatException("expected list, got ${json.runtimeType}"),
      },
      headers: {"x-project-id": projectId},
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
      "/session",
      fromJson: (json) => switch (json) {
        final Map<String, dynamic> map => Session.fromJson(map),
        _ => throw FormatException("expected map, got ${json.runtimeType}"),
      },
      body: CreateSessionRequest(
        projectId: projectId,
        parts: [PromptPart.text(text: text)],
        agent: agent,
        model: model,
        dedicatedWorktree: dedicatedWorktree,
      ).toJson(),
    );
  }

  Future<ApiResponse<Session>> archiveSession({
    required String sessionId,
    required bool deleteWorktree,
    required bool deleteBranch,
    required bool force,
  }) async {
    final response = await _client.patch(
      "/session/$sessionId",
      fromJson: (json) => switch (json) {
        final Map<String, dynamic> map => Session.fromJson(map),
        _ => throw FormatException("expected map, got ${json.runtimeType}"),
      },
      body: UpdateSessionArchiveRequest(
        archived: true,
        deleteWorktree: deleteWorktree,
        deleteBranch: deleteBranch,
        force: force,
      ).toJson(),
    );

    _throwIfCleanupRejected(response);
    return response;
  }

  Future<ApiResponse<Session>> unarchiveSession(String sessionId) {
    return _client.patch(
      "/session/$sessionId",
      fromJson: (json) => switch (json) {
        final Map<String, dynamic> map => Session.fromJson(map),
        _ => throw FormatException("expected map, got ${json.runtimeType}"),
      },
      body: const UpdateSessionArchiveRequest(
        archived: false,
        deleteWorktree: false,
        deleteBranch: false,
        force: false,
      ).toJson(),
    );
  }

  Future<ApiResponse<Session>> renameSession({required String sessionId, required String title}) {
    return _client.patch(
      "/session/title",
      fromJson: (json) => switch (json) {
        final Map<String, dynamic> map => Session.fromJson(map),
        _ => throw FormatException("expected map, got ${json.runtimeType}"),
      },
      body: RenameSessionRequest(sessionId: sessionId, title: title).toJson(),
    );
  }

  Future<ApiResponse<bool>> deleteSession({
    required String sessionId,
    required bool deleteWorktree,
    required bool deleteBranch,
    required bool force,
  }) async {
    final response = await _client.delete(
      "/session/$sessionId",
      fromJson: (_) => true,
      body: DeleteSessionRequest(
        deleteWorktree: deleteWorktree,
        deleteBranch: deleteBranch,
        force: force,
      ).toJson(),
    );

    _throwIfCleanupRejected(response);
    return response;
  }

  void _throwIfCleanupRejected<T>(ApiResponse<T> response) {
    if (response case ErrorResponse(error: NonSuccessCodeError(errorCode: 409, rawErrorString: final rawBody))) {
      try {
        final decoded = jsonDecode(rawBody ?? "{}");
        final rejection = SessionCleanupRejection.fromJson(
          switch (decoded) {
            final Map<String, dynamic> map => map,
            _ => throw const FormatException("invalid cleanup rejection json"),
          },
        );
        throw SessionCleanupRejectedException(rejection: rejection);
      } on SessionCleanupRejectedException {
        rethrow;
      } on Object {
        return;
      }
    }
  }

  Future<ApiResponse<List<Session>>> getChildren(String sessionId) {
    return _client.get(
      "/session/$sessionId/children",
      fromJson: (json) => switch (json) {
        final List<dynamic> list =>
          list
              .map(
                (e) => switch (e) {
                  final Map<String, dynamic> map => Session.fromJson(map),
                  _ => throw FormatException("expected map, got ${e.runtimeType}"),
                },
              )
              .toList(),
        _ => throw FormatException("expected list, got ${json.runtimeType}"),
      },
    );
  }

  Future<ApiResponse<Map<String, SessionStatus>>> getSessionStatuses() {
    return _client.get(
      "/session/status",
      fromJson: (json) => switch (json) {
        final Map<String, dynamic> map => map.map(
          (key, value) => MapEntry(
            key,
            switch (value) {
              final Map<String, dynamic> valueMap => SessionStatus.fromJson(valueMap),
              _ => throw FormatException("expected map value, got ${value.runtimeType}"),
            },
          ),
        ),
        _ => throw FormatException("expected map, got ${json.runtimeType}"),
      },
    );
  }

  Future<ApiResponse<List<MessageWithParts>>> getMessages(
    String sessionId,
  ) {
    return _client.get(
      "/session/$sessionId/message",
      fromJson: (json) => switch (json) {
        final List<dynamic> list =>
          list
              .map(
                (e) => switch (e) {
                  final Map<String, dynamic> map => MessageWithParts.fromJson(map),
                  _ => throw FormatException("expected map, got ${e.runtimeType}"),
                },
              )
              .toList(),
        _ => throw FormatException("expected list, got ${json.runtimeType}"),
      },
    );
  }

  Future<ApiResponse<bool>> sendMessage(
    String sessionId,
    String text, {
    String? agent,
    String? providerID,
    String? modelID,
  }) {
    return _client.post(
      "/session/$sessionId/prompt_async",
      fromJson: (_) => true,
      body: SendPromptRequest(
        parts: [PromptPart.text(text: text)],
        agent: agent,
        model: providerID != null && modelID != null ? PromptModel(providerID: providerID, modelID: modelID) : null,
      ).toJson(),
    );
  }

  Future<ApiResponse<bool>> abortSession(String sessionId) {
    return _client.post(
      "/session/$sessionId/abort",
      fromJson: (_) => true,
      body: null,
    );
  }

  Future<ApiResponse<List<PendingQuestion>>> getPendingQuestions(String sessionId) {
    return _client.get(
      "/session/$sessionId/questions",
      fromJson: (json) => switch (json) {
        final List<dynamic> list =>
          list
              .map(
                (e) => switch (e) {
                  final Map<String, dynamic> map => PendingQuestion.fromJson(map),
                  _ => throw FormatException("expected map, got ${e.runtimeType}"),
                },
              )
              .toList(),
        _ => throw FormatException("expected list, got ${json.runtimeType}"),
      },
    );
  }

  Future<ApiResponse<bool>> replyToQuestion({
    required String requestId,
    required String sessionId,
    required List<ReplyAnswer> answers,
  }) {
    return _client.post(
      "/question/$requestId/reply",
      fromJson: (_) => true,
      body: ReplyToQuestionRequest(sessionId: sessionId, answers: answers).toJson(),
    );
  }

  Future<ApiResponse<bool>> rejectQuestion(String requestId) {
    return _client.post(
      "/question/$requestId/reject",
      fromJson: (_) => true,
      body: null,
    );
  }
}
