import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeListMap, jsonDecodeMap;

import "models/openapi/agent.g.dart";
import "models/openapi/command.g.dart";
import "models/openapi/config_providers_response.g.dart";
import "models/openapi/global_session.g.dart";
import "models/openapi/permission_request.g.dart";
import "models/openapi/project.g.dart";
import "models/openapi/provider_list_response.g.dart";
import "models/openapi/question_request.g.dart";
import "models/openapi/session.g.dart";
import "models/openapi/session_messages_response_item.g.dart";
import "models/openapi/session_status.g.dart";
import "models/question_reply_body.dart";
import "models/send_command_body.dart";
import "models/send_prompt_body.dart";
import "models/summarize_body.dart";
import "open_code_raw_http_client.dart";

const _directoryOpenCodeHeader = "x-opencode-directory";

/// Typed facade over the OpenCode REST API.
///
/// Knows each endpoint's path, request-specific headers, body encoding, and how
/// to map the JSON response into models. All transport concerns — timeouts,
/// success enforcement, auth headers, endpoint labeling — are delegated to
/// [OpenCodeRawHttpClient], so they apply uniformly and can't be forgotten on a
/// new endpoint.
class OpenCodeApi {
  final OpenCodeRawHttpClient _client;

  OpenCodeApi({required OpenCodeRawHttpClient client}) : _client = client;

  Future<bool> healthCheck() async {
    try {
      await _client.get(
        path: "/global/health",
        timeout: const Duration(seconds: 5),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Project>> listProjects() async {
    final response = await _client.get(path: "/project");

    final decoded = jsonDecodeListMap(response.body);
    return decoded.map(Project.fromJson).toList();
  }

  Future<List<Session>> listRootSessions() async {
    final response = await _client.get(
      path: "/session",
      queryParameters: const {"roots": "true"},
    );

    final decoded = jsonDecodeListMap(response.body);
    return decoded.map(Session.fromJson).toList();
  }

  Future<List<Session>> listSessions({String? directory, required bool roots}) async {
    final response = await _client.get(
      path: "/session",
      queryParameters: {
        if (roots) "roots": "true",
      },
      headers: {
        _directoryOpenCodeHeader: ?directory,
      },
    );

    final decoded = jsonDecodeListMap(response.body);
    return decoded.map(Session.fromJson).toList();
  }

  Future<List<Command>> listCommands({required String? directory}) async {
    final response = await _client.get(
      path: "/command",
      headers: {
        _directoryOpenCodeHeader: ?directory,
      },
    );

    final decoded = jsonDecodeListMap(response.body);
    return decoded.map(Command.fromJson).toList();
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
      path: "/session",
      headers: {
        "content-type": "application/json",
        _directoryOpenCodeHeader: directory,
      },
      body: jsonEncode(body),
    );
    return Session.fromJson(jsonDecodeMap(response.body));
  }

  Future<Session> getSession({
    required String sessionId,
    required String? directory,
  }) async {
    final response = await _client.get(
      path: "/session/$sessionId",
      headers: {
        _directoryOpenCodeHeader: ?directory,
      },
    );
    return Session.fromJson(jsonDecodeMap(response.body));
  }

  Future<Session> updateSession({
    required String sessionId,
    required Map<String, dynamic> body,
    required String? directory,
  }) async {
    final response = await _client.patch(
      path: "/session/$sessionId",
      headers: {
        "content-type": "application/json",
        _directoryOpenCodeHeader: ?directory,
      },
      body: jsonEncode(body),
    );
    return Session.fromJson(jsonDecodeMap(response.body));
  }

  /// Updates a project by its OpenCode-assigned ID (NOT the worktree path
  /// that Sesori uses as the project identifier).
  Future<Project> updateProject({
    required String projectId,
    required String directory,
    required Map<String, dynamic> body,
  }) async {
    final response = await _client.patch(
      path: "/project/$projectId",
      headers: {
        "content-type": "application/json",
        _directoryOpenCodeHeader: directory,
      },
      body: jsonEncode(body),
    );
    return Project.fromJson(jsonDecodeMap(response.body));
  }

  Future<void> deleteSession({
    required String sessionId,
    required String? directory,
  }) async {
    await _client.delete(
      path: "/session/$sessionId",
      headers: {
        _directoryOpenCodeHeader: ?directory,
      },
    );
  }

  /// Removes a worktree (workspace) from OpenCode.
  ///
  /// Sends `DELETE /experimental/worktree` with the worktree directory in the
  /// body. The [directory] header must be the project root worktree so that
  /// OpenCode knows which project the sandbox belongs to.
  Future<void> removeWorktree({
    required String directory,
    required String worktreePath,
  }) async {
    await _client.delete(
      path: "/experimental/worktree",
      headers: {
        "content-type": "application/json",
        _directoryOpenCodeHeader: directory,
      },
      body: jsonEncode({"directory": worktreePath}),
    );
  }

  Future<List<Session>> getChildren({
    required String sessionId,
    required String? directory,
  }) async {
    final response = await _client.get(
      path: "/session/$sessionId/children",
      headers: {
        _directoryOpenCodeHeader: ?directory, // probably irrelevant for this endpoint
      },
    );

    final decoded = jsonDecodeListMap(response.body);
    return decoded.map(Session.fromJson).toList();
  }

  Future<Session> forkSession({
    required String sessionId,
    required String directory,
  }) async {
    final response = await _client.post(
      path: "/session/$sessionId/fork",
      headers: {
        _directoryOpenCodeHeader: directory,
      },
    );
    return Session.fromJson(jsonDecodeMap(response.body));
  }

  Future<List<SessionMessagesResponseItem>> getMessages({
    required String sessionId,
    required String? directory,
  }) async {
    final response = await _client.get(
      path: "/session/$sessionId/message",
      headers: {
        _directoryOpenCodeHeader: ?directory, // probably irrelevant for this endpoint
      },
    );

    final decoded = jsonDecodeListMap(response.body);
    return decoded.map(SessionMessagesResponseItem.fromJson).toList();
  }

  Future<void> sendPrompt({
    required String sessionId,
    required SendPromptBody body,
    // 100% required for this endpoint
    // because otherwise it picks the CWD of where bridge is running
    required String? directory,
  }) async {
    await _client.post(
      path: "/session/$sessionId/prompt_async",
      headers: {
        "content-type": "application/json",
        _directoryOpenCodeHeader: ?directory,
      },
      body: jsonEncode(body.toJson()),
    );
  }

  /// Sends a slash command to a session via `POST /session/:id/command`.
  ///
  /// WARNING: this OpenCode endpoint is **synchronous** — the HTTP response
  /// (and therefore the returned future) does not complete until the
  /// command's full agent run has finished, which can take minutes. No async
  /// variant exists upstream (unlike prompts, which have `prompt_async`).
  /// Callers that must not block on the run (see [OpenCodeService]) are
  /// responsible for detaching; this Layer 1 method stays a dumb HTTP call.
  ///
  /// Passed `timeout: null` explicitly. Writes already default to no timeout
  /// (`Future.timeout` cannot abort the underlying request, so a client-side
  /// deadline on this synchronous, minutes-long run would only surface a
  /// spurious post-dispatch failure), but stating it at the call site keeps
  /// that intent obvious for an endpoint where an accidental timeout would be
  /// especially harmful. [OpenCodeService] already detaches after a fast-fail
  /// window, and the orchestrator abandons in-flight routes on shutdown, so an
  /// unbounded command never blocks teardown.
  Future<void> sendCommand({
    required String sessionId,
    required SendCommandBody body,
    required String? directory,
  }) async {
    await _client.post(
      path: "/session/$sessionId/command",
      headers: {
        "content-type": "application/json",
        _directoryOpenCodeHeader: ?directory,
      },
      body: jsonEncode(body.toJson()),
      timeout: null,
    );
  }

  /// Triggers AI compaction of a session via `POST /session/:id/summarize`.
  ///
  /// WARNING: like [sendCommand], this OpenCode endpoint is **synchronous** —
  /// the HTTP response does not complete until the compaction agent run has
  /// finished, which can take minutes. Callers that must not block on the run
  /// (see [OpenCodeService]) are responsible for detaching; this Layer 1 method
  /// stays a dumb HTTP call. Sent with `timeout: null` for the same reason as
  /// [sendCommand].
  Future<void> summarize({
    required String sessionId,
    required SummarizeBody body,
    required String? directory,
  }) async {
    await _client.post(
      path: "/session/$sessionId/summarize",
      headers: {
        "content-type": "application/json",
        _directoryOpenCodeHeader: ?directory,
      },
      body: jsonEncode(body.toJson()),
      timeout: null,
    );
  }

  Future<void> abortSession({
    required String sessionId,
    required String? directory,
  }) async {
    await _client.post(
      path: "/session/$sessionId/abort",
      headers: {
        _directoryOpenCodeHeader: ?directory,
      },
      body: "",
    );
  }

  Future<List<Agent>> listAgents({required String directory}) async {
    // OpenCode resolves agents per project; newer releases reject requests
    // that carry no directory context with a 500.
    final response = await _client.get(
      path: "/agent",
      headers: {
        _directoryOpenCodeHeader: directory,
      },
    );

    final decoded = jsonDecodeListMap(response.body);
    return decoded.map(Agent.fromJson).toList();
  }

  Future<List<QuestionRequest>> getPendingQuestions({
    required String? directory,
  }) async {
    final response = await _client.get(
      path: "/question",
      headers: {
        _directoryOpenCodeHeader: ?directory,
      },
    );
    Log.v("[getPendingQuestions] response: ${response.body}");

    final decoded = jsonDecodeListMap(response.body);
    return decoded.map(QuestionRequest.fromJson).toList();
  }

  Future<List<PermissionRequest>> getPendingPermissions({
    required String? directory,
  }) async {
    final response = await _client.get(
      path: "/permission",
      headers: {
        _directoryOpenCodeHeader: ?directory,
      },
    );
    Log.v("[getPendingPermissions] response: ${response.body}");

    final decoded = jsonDecodeListMap(response.body);
    return decoded.map(PermissionRequest.fromJson).toList();
  }

  Future<void> replyToQuestion({
    required String questionId,
    required String? directory,
    required QuestionReplyBody body,
  }) async {
    final encodedBody = jsonEncode(body.toJson());
    Log.d("[question-api] POST /question/$questionId/reply body=$encodedBody");
    final response = await _client.post(
      path: "/question/$questionId/reply",
      headers: {
        _directoryOpenCodeHeader: ?directory, // doesn't work well with the directory header
        "content-type": "application/json",
      },
      body: encodedBody,
    );
    Log.d("[question-api] POST /question/$questionId/reply => ${response.statusCode} body=${response.body}");
  }

  Future<void> replyToPermission({
    required String requestId,
    required String? directory,
    required PluginPermissionReply reply,
  }) async {
    final body = jsonEncode({"reply": reply.name});
    Log.d("[permission-api] POST /permission/$requestId/reply for session directory $directory");
    await _client.post(
      path: "/permission/$requestId/reply",
      headers: {
        _directoryOpenCodeHeader: ?directory,
        "content-type": "application/json",
      },
      body: body,
    );
  }

  Future<void> rejectQuestion({
    required String questionId,
    required String? directory,
  }) async {
    Log.d("[question-api] POST /question/$questionId/reject for session directory $directory");
    final response = await _client.post(
      path: "/question/$questionId/reject",
      headers: {
        _directoryOpenCodeHeader: ?directory,
      },
      body: "",
    );
    Log.d("[question-api] POST /question/$questionId/reject => ${response.statusCode} body=${response.body}");
  }

  Future<Project> getProject({
    required String directory,
  }) async {
    final response = await _client.get(
      path: "/project/current",
      headers: {
        _directoryOpenCodeHeader: directory,
      },
    );
    return Project.fromJson(jsonDecodeMap(response.body));
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
    final response = await _client.get(
      path: "/experimental/session",
      queryParameters: {
        // unlike the other endpoints, this uses a query param for the directory
        "directory": ?directory,
        if (roots) "roots": "true",
      },
    );

    final decoded = jsonDecodeListMap(response.body);
    return decoded.map(GlobalSession.fromJson).toList();
  }

  Future<ProviderListResponse> listProviders() async {
    final response = await _client.get(path: "/provider");
    return ProviderListResponse.fromJson(jsonDecodeMap(response.body));
  }

  Future<ConfigProvidersResponse> listConfigProviders({required String? directory}) async {
    final response = await _client.get(
      path: "/config/providers",
      headers: {
        _directoryOpenCodeHeader: ?directory,
      },
    );
    return ConfigProvidersResponse.fromJson(
      jsonDecodeMap(response.body),
    );
  }

  Future<Map<String, SessionStatus>> getSessionStatuses({required String? directory}) async {
    final response = await _client.get(
      path: "/session/status",
      headers: {
        _directoryOpenCodeHeader: ?directory,
      },
    );

    final decoded = jsonDecodeMap(response.body);
    return decoded.map(
      (key, value) => MapEntry(key, SessionStatus.fromJson(value as Map<String, dynamic>)),
    );
  }
}
