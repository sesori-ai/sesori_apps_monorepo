import "dart:convert";

import "package:http/http.dart" as http;

import "models/message_with_parts.dart";
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

  Future<List<MessageWithParts>> getMessages(String sessionId) async {
    final response = await http.get(
      Uri.parse("$serverURL/session/$sessionId/message"),
      headers: _authHeaders,
    );
    _ensureSuccess(response, "GET /session/$sessionId/message");

    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>().map(MessageWithParts.fromJson).toList();
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
