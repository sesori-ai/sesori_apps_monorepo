import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../api/client/relay_http_client.dart";

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

  /// Lists root sessions for the current project.
  ///
  /// Project scoping is passed via the `x-project-id` header. We keep
  /// `roots=true` so the server returns root sessions across all
  /// subdirectories of the selected project.
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
      queryParameters: {"roots": "true"},
    );
  }

  Future<ApiResponse<Session>> createSession({required String projectId}) {
    return _client.post(
      "/session",
      fromJson: (json) => switch (json) {
        final Map<String, dynamic> map => Session.fromJson(map),
        _ => throw FormatException("expected map, got ${json.runtimeType}"),
      },
      body: CreateSessionRequest(projectId: projectId).toJson(),
    );
  }

  Future<ApiResponse<Session>> archiveSession(String sessionId) {
    return _client.patch(
      "/session/$sessionId",
      fromJson: (json) => switch (json) {
        final Map<String, dynamic> map => Session.fromJson(map),
        _ => throw FormatException("expected map, got ${json.runtimeType}"),
      },
      body: const UpdateSessionArchiveRequest(archived: true).toJson(),
    );
  }

  Future<ApiResponse<Session>> unarchiveSession(String sessionId) {
    return _client.patch(
      "/session/$sessionId",
      fromJson: (json) => switch (json) {
        final Map<String, dynamic> map => Session.fromJson(map),
        _ => throw FormatException("expected map, got ${json.runtimeType}"),
      },
      body: const UpdateSessionArchiveRequest(archived: false).toJson(),
    );
  }

  Future<ApiResponse<bool>> deleteSession(String sessionId) {
    return _client.delete(
      "/session/$sessionId",
      fromJson: (_) => true,
    );
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

  Future<ApiResponse<List<PendingQuestion>>> getPendingQuestions() {
    return _client.get(
      "/question",
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

  Future<ApiResponse<bool>> replyToQuestion(
    String requestId,
    List<ReplyAnswer> answers,
  ) {
    return _client.post(
      "/question/$requestId/reply",
      fromJson: (_) => true,
      body: ReplyToQuestionRequest(answers: answers).toJson(),
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
