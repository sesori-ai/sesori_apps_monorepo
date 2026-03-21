import "dart:convert";

import "package:http/http.dart" as http;

import "models/agent_info.dart";
import "models/message_with_parts.dart";
import "models/pending_question.dart";
import "models/project.dart";
import "models/provider_info.dart";
import "models/session.dart";
import "models/session_status.dart";

class OpenCodeApi {
  final String serverURL;
  final String? _password;

  OpenCodeApi({required this.serverURL, String? password}) : _password = password;

  Map<String, String> get _authHeaders {
    if (_password == null) return const {};
    final creds = base64.encode(utf8.encode("opencode:$_password"));
    return {"Authorization": "Basic $creds"};
  }

  Future<List<Project>> listProjects() async {
    final response = await http.get(
      Uri.parse("$serverURL/project"),
      headers: _authHeaders,
    );
    _ensureSuccess(response, "GET /project");

    final decoded = jsonDecode(response.body) as List;
    return decoded.cast<Map<String, dynamic>>().map(Project.fromJson).toList();
  }

  Future<List<Session>> listRootSessions() async {
    final response = await http.get(
      Uri.parse("$serverURL/session?roots=true"),
      headers: _authHeaders,
    );
    _ensureSuccess(response, "GET /session?roots=true");

    final decoded = jsonDecode(response.body) as List;
    return decoded.cast<Map<String, dynamic>>().map(Session.fromJson).toList();
  }

  Future<List<Session>> listSessions({String? directory}) async {
    final query = <String, String>{};
    if (directory != null) query["directory"] = directory;

    final uri = Uri.parse("$serverURL/session").replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders);
    _ensureSuccess(response, "GET /session");

    final decoded = jsonDecode(response.body) as List;
    return decoded.cast<Map<String, dynamic>>().map(Session.fromJson).toList();
  }

  Future<Session> createSession(String directory, {String? parentSessionId}) async {
    final client = http.Client();
    try {
      final body = <String, dynamic>{};
      if (parentSessionId case final id?) {
        body["parentSessionId"] = id;
      }
      final response = await client.post(
        Uri.parse("$serverURL/session"),
        headers: {
          ..._authHeaders,
          "content-type": "application/json",
          "x-opencode-directory": directory,
        },
        body: jsonEncode(body),
      );
      _ensureSuccess(response, "POST /session");
      return Session.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } finally {
      client.close();
    }
  }

  Future<Session> updateSession(String sessionId, Map<String, dynamic> body) async {
    final client = http.Client();
    try {
      final response = await client.patch(
        Uri.parse("$serverURL/session/$sessionId"),
        headers: {
          ..._authHeaders,
          "content-type": "application/json",
        },
        body: jsonEncode(body),
      );
      _ensureSuccess(response, "PATCH /session/$sessionId");
      return Session.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } finally {
      client.close();
    }
  }

  Future<void> deleteSession(String sessionId) async {
    final client = http.Client();
    try {
      final response = await client.delete(
        Uri.parse("$serverURL/session/$sessionId"),
        headers: _authHeaders,
      );
      _ensureSuccess(response, "DELETE /session/$sessionId");
    } finally {
      client.close();
    }
  }

  Future<List<Session>> getChildren(String sessionId) async {
    final response = await http.get(
      Uri.parse("$serverURL/session/$sessionId/children"),
      headers: _authHeaders,
    );
    _ensureSuccess(response, "GET /session/$sessionId/children");

    final decoded = jsonDecode(response.body) as List;
    return decoded.cast<Map<String, dynamic>>().map(Session.fromJson).toList();
  }

  Future<List<MessageWithParts>> getMessages(String sessionId) async {
    final response = await http.get(
      Uri.parse("$serverURL/session/$sessionId/message"),
      headers: _authHeaders,
    );
    _ensureSuccess(response, "GET /session/$sessionId/message");

    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>().map(MessageWithParts.fromJson).toList();
  }

  Future<void> sendPrompt(String sessionId, {required Map<String, dynamic> body}) async {
    final client = http.Client();
    try {
      final response = await client.post(
        Uri.parse("$serverURL/session/$sessionId/prompt_async"),
        headers: {
          ..._authHeaders,
          "content-type": "application/json",
        },
        body: jsonEncode(body),
      );
      _ensureSuccess(response, "POST /session/$sessionId/prompt_async");
    } finally {
      client.close();
    }
  }

  Future<void> abortSession(String sessionId) async {
    final client = http.Client();
    try {
      final response = await client.post(
        Uri.parse("$serverURL/session/$sessionId/abort"),
        headers: _authHeaders,
        body: "",
      );
      _ensureSuccess(response, "POST /session/$sessionId/abort");
    } finally {
      client.close();
    }
  }

  Future<List<AgentInfo>> listAgents() async {
    final response = await http.get(Uri.parse("$serverURL/agent"), headers: _authHeaders);
    _ensureSuccess(response, "GET /agent");

    final decoded = jsonDecode(response.body) as List;
    return decoded.cast<Map<String, dynamic>>().map(AgentInfo.fromJson).toList();
  }

  Future<List<PendingQuestion>> getPendingQuestions() async {
    final response = await http.get(Uri.parse("$serverURL/question"), headers: _authHeaders);
    _ensureSuccess(response, "GET /question");

    final decoded = jsonDecode(response.body) as List;
    return decoded.cast<Map<String, dynamic>>().map(PendingQuestion.fromJson).toList();
  }

  Future<void> replyToQuestion(String questionId, {required Map<String, dynamic> body}) async {
    final client = http.Client();
    try {
      final response = await client.post(
        Uri.parse("$serverURL/question/$questionId/reply"),
        headers: {
          ..._authHeaders,
          "content-type": "application/json",
        },
        body: jsonEncode(body),
      );
      _ensureSuccess(response, "POST /question/$questionId/reply");
    } finally {
      client.close();
    }
  }

  Future<void> rejectQuestion(String questionId) async {
    final client = http.Client();
    try {
      final response = await client.post(
        Uri.parse("$serverURL/question/$questionId/reject"),
        headers: _authHeaders,
        body: "",
      );
      _ensureSuccess(response, "POST /question/$questionId/reject");
    } finally {
      client.close();
    }
  }

  Future<Project> getCurrentProject(String directory) async {
    final response = await http.get(
      Uri.parse("$serverURL/project/current"),
      headers: {
        ..._authHeaders,
        "x-opencode-directory": directory,
      },
    );
    _ensureSuccess(response, "GET /project/current");
    return Project.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<GlobalSession>> listGlobalSessions({
    String? directory,
    bool roots = false,
  }) async {
    final query = <String, String>{};
    if (directory != null) query["directory"] = directory;
    if (roots) query["roots"] = "true";

    final uri = Uri.parse(
      "$serverURL/experimental/session",
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _authHeaders);
    _ensureSuccess(response, "GET /experimental/session");

    final decoded = jsonDecode(response.body) as List;
    return decoded.cast<Map<String, dynamic>>().map(GlobalSession.fromJson).toList();
  }

  Future<ProviderListResponse> listProviders() async {
    final response = await http.get(
      Uri.parse("$serverURL/provider"),
      headers: _authHeaders,
    );
    _ensureSuccess(response, "GET /provider");
    return ProviderListResponse.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Map<String, SessionStatus>> getSessionStatuses() async {
    final response = await http.get(
      Uri.parse("$serverURL/session/status"),
      headers: _authHeaders,
    );
    _ensureSuccess(response, "GET /session/status");

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded.map(
      (key, value) => MapEntry(key, SessionStatus.fromJson(value as Map<String, dynamic>)),
    );
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
