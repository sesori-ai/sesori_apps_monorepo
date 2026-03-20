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
      // ignore: no_slop_linter/avoid_dynamic_type, json parsing
      fromJson: (json) => (json as List)
          .map(
            // ignore: no_slop_linter/avoid_dynamic_type, json parsing
            (e) => AgentInfo.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  Future<ApiResponse<ProviderListResponse>> listProviders() {
    return _client.get(
      "/provider",
      // ignore: no_slop_linter/avoid_dynamic_type, json parsing
      fromJson: (json) => ProviderListResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  /// Lists root sessions for the current project.
  ///
  /// Project scoping relies on the `x-opencode-directory` header that
  /// [RelayHttpApiClient] injects from [ConnectionService.activeDirectory].
  /// We intentionally omit a `directory` query param so the server returns
  /// sessions from *all* subdirectories of the project — not just those
  /// whose stored directory exactly matches the worktree root.
  Future<ApiResponse<List<Session>>> listSessions() {
    return _client.get(
      "/session",
      // ignore: no_slop_linter/avoid_dynamic_type, json parsing
      fromJson: (json) => (json as List)
          .map(
            // ignore: no_slop_linter/avoid_dynamic_type, json parsing
            (e) => Session.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      queryParameters: {"roots": "true"},
    );
  }

  Future<ApiResponse<Session>> createSession() {
    return _client.post(
      "/session",
      // ignore: no_slop_linter/avoid_dynamic_type, json parsing
      fromJson: (json) => Session.fromJson(json as Map<String, dynamic>),
      body: <String, dynamic>{},
    );
  }

  Future<ApiResponse<Session>> archiveSession(String sessionId) {
    return _client.patch(
      "/session/$sessionId",
      // ignore: no_slop_linter/avoid_dynamic_type, json parsing
      fromJson: (json) => Session.fromJson(json as Map<String, dynamic>),
      body: {
        "time": {"archived": DateTime.now().millisecondsSinceEpoch},
      },
    );
  }

  Future<ApiResponse<Session>> unarchiveSession(String sessionId) {
    return _client.patch(
      "/session/$sessionId",
      // ignore: no_slop_linter/avoid_dynamic_type, json parsing
      fromJson: (json) => Session.fromJson(json as Map<String, dynamic>),
      body: {
        "time": {"archived": null},
      },
    );
  }

  Future<ApiResponse<bool>> deleteSession(String sessionId) {
    return _client.delete(
      "/session/$sessionId",
      // ignore: no_slop_linter/avoid_dynamic_type, json parsing
      fromJson: (_) => true,
    );
  }

  Future<ApiResponse<List<Session>>> getChildren(String sessionId) {
    return _client.get(
      "/session/$sessionId/children",
      // ignore: no_slop_linter/avoid_dynamic_type, json parsing
      fromJson: (json) => (json as List)
          .map(
            // ignore: no_slop_linter/avoid_dynamic_type, json parsing
            (e) => Session.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  Future<ApiResponse<Map<String, SessionStatus>>> getSessionStatuses() {
    return _client.get(
      "/session/status",
      // ignore: no_slop_linter/avoid_dynamic_type, json parsing
      fromJson: (json) => (json as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, SessionStatus.fromJson(value as Map<String, dynamic>)),
      ),
    );
  }

  Future<ApiResponse<List<MessageWithParts>>> getMessages(
    String sessionId,
  ) {
    return _client.get(
      "/session/$sessionId/message",
      // ignore: no_slop_linter/avoid_dynamic_type, json parsing
      fromJson: (json) => (json as List)
          .map(
            // ignore: no_slop_linter/avoid_dynamic_type, json parsing
            (e) => MessageWithParts.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
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
      // ignore: no_slop_linter/avoid_dynamic_type, json parsing
      fromJson: (_) => true,
      body: {
        "parts": [
          {"type": "text", "text": text},
        ],
        "agent": ?agent,
        if (providerID != null && modelID != null) "model": {"providerID": providerID, "modelID": modelID},
      },
    );
  }

  Future<ApiResponse<bool>> abortSession(String sessionId) {
    return _client.post(
      "/session/$sessionId/abort",
      // ignore: no_slop_linter/avoid_dynamic_type, json parsing
      fromJson: (_) => true,
      body: null,
    );
  }

  Future<ApiResponse<List<SesoriQuestionAsked>>> getPendingQuestions() {
    return _client.get(
      "/question",
      // ignore: no_slop_linter/avoid_dynamic_type, json parsing
      fromJson: (json) => (json as List)
          .map(
            // ignore: no_slop_linter/avoid_dynamic_type, json parsing
            (e) => SesoriQuestionAsked.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  Future<ApiResponse<bool>> replyToQuestion(
    String requestId,
    List<List<String>> answers,
  ) {
    return _client.post(
      "/question/$requestId/reply",
      // ignore: no_slop_linter/avoid_dynamic_type, json parsing
      fromJson: (_) => true,
      body: {"answers": answers},
    );
  }

  Future<ApiResponse<bool>> rejectQuestion(String requestId) {
    return _client.post(
      "/question/$requestId/reject",
      // ignore: no_slop_linter/avoid_dynamic_type, json parsing
      fromJson: (_) => true,
      body: null,
    );
  }
}
