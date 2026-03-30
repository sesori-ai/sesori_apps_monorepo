import "dart:convert";

import "package:http/http.dart" as http;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "models/agent_info.dart";
import "models/message_with_parts.dart";
import "models/opencode_config.dart";
import "models/pending_question.dart";
import "models/project.dart";
import "models/provider_info.dart";
import "models/send_message_sync_body.dart";
import "models/send_prompt_body.dart";
import "models/session.dart";
import "models/session_status.dart";

const _directoryOpenCodeHeader = "x-opencode-directory";

class OpenCodeApi {
  final String serverURL;
  final String? _password;
  final http.Client _client;

  OpenCodeApi({
    required this.serverURL,
    required String? password,
    required http.Client client,
  }) : _password = password,
       _client = client;

  Map<String, String> get _authHeaders {
    if (_password == null) return const {};
    final creds = base64.encode(utf8.encode("opencode:$_password"));
    return {"Authorization": "Basic $creds"};
  }

  Future<bool> healthCheck() async {
    try {
      final response = await _client
          .get(Uri.parse("$serverURL/global/health"), headers: _authHeaders)
          .timeout(const Duration(seconds: 5));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<List<Project>> listProjects() async {
    final response = await _client.get(
      Uri.parse("$serverURL/project"),
      headers: _authHeaders,
    );
    _ensureSuccess(response, "GET /project");

    final decoded = jsonDecode(response.body) as List;
    return decoded.cast<Map<String, dynamic>>().map(Project.fromJson).toList();
  }

  Future<List<Session>> listRootSessions() async {
    final response = await _client.get(
      Uri.parse("$serverURL/session?roots=true"),
      headers: _authHeaders,
    );
    _ensureSuccess(response, "GET /session?roots=true");

    final decoded = jsonDecode(response.body) as List;
    return decoded.cast<Map<String, dynamic>>().map(Session.fromJson).toList();
  }

  Future<List<Session>> listSessions({String? directory}) async {
    final headers = <String, String>{
      ..._authHeaders,
      _directoryOpenCodeHeader: ?directory,
    };

    final response = await _client.get(
      Uri.parse("$serverURL/session"),
      headers: headers,
    );
    _ensureSuccess(response, "GET /session");

    final decoded = jsonDecode(response.body) as List;
    return decoded.cast<Map<String, dynamic>>().map(Session.fromJson).toList();
  }

  Future<Session> createSession({
    required String directory,
    String? parentSessionId,
  }) async {
    // Supported body:
    //  {
    //   "parentID": "<sessionID>",   // optional - set this to make it a child
    //   "title": "string",           // optional - title gets auto-generated after first message
    //   "permission": "...",         // optional
    //   "workspaceID": "string"      // optional
    // }
    final body = <String, dynamic>{};
    if (parentSessionId case final id?) {
      body["parentID"] = id;
    }
    final response = await _client.post(
      Uri.parse("$serverURL/session"),
      headers: {
        ..._authHeaders,
        "content-type": "application/json",
        _directoryOpenCodeHeader: directory,
      },
      body: jsonEncode(body),
    );
    _ensureSuccess(response, "POST /session");
    return Session.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Session> getSession({
    required String sessionId,
    required String? directory,
  }) async {
    final headers = <String, String>{
      ..._authHeaders,
      _directoryOpenCodeHeader: ?directory,
    };
    final response = await _client.get(
      Uri.parse("$serverURL/session/$sessionId"),
      headers: headers,
    );
    _ensureSuccess(response, "GET /session/$sessionId");
    return Session.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Session> updateSession({
    required String sessionId,
    required Map<String, dynamic> body,
    required String? directory,
  }) async {
    final response = await _client.patch(
      Uri.parse("$serverURL/session/$sessionId"),
      headers: {
        ..._authHeaders,
        "content-type": "application/json",
        _directoryOpenCodeHeader: ?directory,
      },
      body: jsonEncode(body),
    );
    _ensureSuccess(response, "PATCH /session/$sessionId");
    return Session.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Updates a project by its OpenCode-assigned ID (NOT the worktree path
  /// that Sesori uses as the project identifier).
  Future<Project> updateProject({
    required String projectId,
    required String directory,
    required Map<String, dynamic> body,
  }) async {
    final response = await _client.patch(
      Uri.parse("$serverURL/project/$projectId"),
      headers: {
        ..._authHeaders,
        "content-type": "application/json",
        _directoryOpenCodeHeader: directory,
      },
      body: jsonEncode(body),
    );
    _ensureSuccess(response, "PATCH /project/$projectId");
    return Project.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteSession({
    required String sessionId,
    required String? directory,
  }) async {
    final headers = <String, String>{
      ..._authHeaders,
      _directoryOpenCodeHeader: ?directory,
    };
    final response = await _client.delete(
      Uri.parse("$serverURL/session/$sessionId"),
      headers: headers,
    );
    _ensureSuccess(response, "DELETE /session/$sessionId");
  }

  Future<List<Session>> getChildren({
    required String sessionId,
    required String? directory,
  }) async {
    final headers = <String, String>{
      ..._authHeaders,
      _directoryOpenCodeHeader: ?directory, // probably irrelevant for this endpoint
    };
    final response = await _client.get(
      Uri.parse("$serverURL/session/$sessionId/children"),
      headers: headers,
    );
    _ensureSuccess(response, "GET /session/$sessionId/children");

    final decoded = jsonDecode(response.body) as List;
    return decoded.cast<Map<String, dynamic>>().map(Session.fromJson).toList();
  }

  Future<Session> forkSession({
    required String sessionId,
    required String directory,
  }) async {
    final response = await _client.post(
      Uri.parse("$serverURL/session/$sessionId/fork"),
      headers: {
        ..._authHeaders,
        _directoryOpenCodeHeader: directory,
      },
    );
    _ensureSuccess(response, "POST /session/$sessionId/fork");
    return Session.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<MessageWithParts>> getMessages({
    required String sessionId,
    required String? directory,
  }) async {
    final headers = <String, String>{
      ..._authHeaders,
      _directoryOpenCodeHeader: ?directory, // probably irrelevant for this endpoint
    };
    final response = await _client.get(
      Uri.parse("$serverURL/session/$sessionId/message"),
      headers: headers,
    );
    _ensureSuccess(response, "GET /session/$sessionId/message");

    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>().map(MessageWithParts.fromJson).toList();
  }

  Future<void> sendPrompt({
    required String sessionId,
    required SendPromptBody body,
    // 100% required for this endpoint
    // because otherwise it picks the CWD of where bridge is running
    required String? directory,
  }) async {
    final response = await _client.post(
      Uri.parse("$serverURL/session/$sessionId/prompt_async"),
      headers: {
        ..._authHeaders,
        "content-type": "application/json",
        _directoryOpenCodeHeader: ?directory,
      },
      body: jsonEncode(body.toJson()),
    );
    _ensureSuccess(response, "POST /session/$sessionId/prompt_async");
  }

  Future<void> abortSession({
    required String sessionId,
    required String? directory,
  }) async {
    final headers = <String, String>{
      ..._authHeaders,
      _directoryOpenCodeHeader: ?directory,
    };
    final response = await _client.post(
      Uri.parse("$serverURL/session/$sessionId/abort"),
      headers: headers,
      body: "",
    );
    _ensureSuccess(response, "POST /session/$sessionId/abort");
  }

  Future<List<AgentInfo>> listAgents() async {
    final response = await _client.get(Uri.parse("$serverURL/agent"), headers: _authHeaders);
    _ensureSuccess(response, "GET /agent");

    final decoded = jsonDecode(response.body) as List;
    return decoded.cast<Map<String, dynamic>>().map(AgentInfo.fromJson).toList();
  }

  Future<List<PendingQuestion>> getPendingQuestions({
    required String? directory,
  }) async {
    final headers = <String, String>{
      ..._authHeaders,
      _directoryOpenCodeHeader: ?directory,
    };
    final response = await _client.get(Uri.parse("$serverURL/question"), headers: headers);
    Log.v("[getPendingQuestions] response: ${response.body}");
    _ensureSuccess(response, "GET /question");

    final decoded = jsonDecode(response.body) as List;
    return decoded.cast<Map<String, dynamic>>().map(PendingQuestion.fromJson).toList();
  }

  Future<void> replyToQuestion({
    required String questionId,
    required String? directory,
    required Map<String, dynamic> body,
  }) async {
    final encodedBody = jsonEncode(body);
    Log.d("[question-api] POST /question/$questionId/reply body=$encodedBody");
    final response = await _client.post(
      Uri.parse("$serverURL/question/$questionId/reply"),
      headers: {
        ..._authHeaders,
        _directoryOpenCodeHeader: ?directory, // doesn't work well with the directory header
        "content-type": "application/json",
      },
      body: encodedBody,
    );
    Log.d("[question-api] POST /question/$questionId/reply => ${response.statusCode} body=${response.body}");
    _ensureSuccess(response, "POST /question/$questionId/reply");
  }

  Future<void> rejectQuestion({
    required String questionId,
  }) async {
    Log.d("[question-api] POST /question/$questionId/reject");
    final response = await _client.post(
      Uri.parse("$serverURL/question/$questionId/reject"),
      headers: _authHeaders,
      body: "",
    );
    Log.d("[question-api] POST /question/$questionId/reject => ${response.statusCode} body=${response.body}");
    _ensureSuccess(response, "POST /question/$questionId/reject");
  }

  Future<Project> getProject({
    required String directory,
  }) async {
    final response = await _client.get(
      Uri.parse("$serverURL/project/current"),
      headers: {
        ..._authHeaders,
        _directoryOpenCodeHeader: directory,
      },
    );
    _ensureSuccess(response, "GET /project/current");
    return Project.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Lists sessions across **all** projects via `GET /experimental/session`.
  ///
  /// Unlike [listSessions] (which is scoped to the current OpenCode instance's
  /// project), this endpoint returns sessions from every project in the
  /// database, each enriched with embedded project info ([GlobalSession]).
  ///
  /// The name "global" in OpenCode's API refers to the cross-project scope,
  /// **not** to the special `"global"` project ID that OpenCode assigns to
  /// sessions created before `git init`.
  ///
  /// - [directory]: when non-null, filters to sessions whose directory matches
  ///   exactly. Pass `null` to fetch sessions from all directories.
  /// - [roots]: when `true`, excludes child sessions (subtasks/forks) by
  ///   filtering to sessions with no `parentID`. This is the typical mode for
  ///   building project lists and session lists in the UI.
  Future<List<GlobalSession>> listAllSessions({
    required String? directory,
    required bool roots,
  }) async {
    final queryParams = <String, String>{
      // unlike the other endpoints, this uses a query param for the directory
      "directory": ?directory,
      if (roots) "roots": "true",
    };

    final uri = Uri.parse(
      "$serverURL/experimental/session",
    ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    final response = await _client.get(uri, headers: _authHeaders);
    _ensureSuccess(response, "GET /experimental/session");

    final decoded = jsonDecode(response.body) as List;
    return decoded.cast<Map<String, dynamic>>().map(GlobalSession.fromJson).toList();
  }

  Future<ProviderListResponse> listProviders() async {
    final response = await _client.get(
      Uri.parse("$serverURL/provider"),
      headers: _authHeaders,
    );
    _ensureSuccess(response, "GET /provider");
    return ProviderListResponse.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Map<String, SessionStatus>> getSessionStatuses() async {
    final response = await _client.get(
      Uri.parse("$serverURL/session/status"),
      headers: _authHeaders,
    );
    _ensureSuccess(response, "GET /session/status");

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded.map(
      (key, value) => MapEntry(key, SessionStatus.fromJson(value as Map<String, dynamic>)),
    );
  }

  Future<OpenCodeConfig> getConfig() async {
    final response = await http.get(
      Uri.parse("$serverURL/config"),
      headers: _authHeaders,
    );
    _ensureSuccess(response, "GET /config");
    return OpenCodeConfig.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Sends a message to a session and blocks until the AI responds.
  ///
  /// Uses `POST /session/{id}/message` (synchronous variant) instead of
  /// `prompt_async`. The response contains the assistant's message.
  ///
  /// Times out after 30 seconds.
  Future<MessageWithParts> sendMessageSync({
    required String sessionId,
    required String directory,
    required SendMessageSyncBody body,
  }) async {
    final client = http.Client();
    try {
      final response = await client
          .post(
            Uri.parse("$serverURL/session/$sessionId/message"),
            headers: {
              ..._authHeaders,
              "content-type": "application/json",
              _directoryOpenCodeHeader: directory,
            },
            body: jsonEncode(body.toJson()),
          )
          .timeout(const Duration(seconds: 30));
      _ensureSuccess(response, "POST /session/$sessionId/message");
      return MessageWithParts.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } finally {
      client.close();
    }
  }

  static void _ensureSuccess(http.Response response, String endpoint) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OpenCodeApiException(endpoint, response.statusCode);
    }
  }
}

class OpenCodeApiException implements Exception {
  final String endpoint;
  final int statusCode;

  OpenCodeApiException(this.endpoint, this.statusCode);

  @override
  String toString() => "OpenCodeApiException: $endpoint failed with status $statusCode";
}
