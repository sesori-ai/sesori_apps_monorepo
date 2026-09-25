import "dart:convert";

import "package:http/http.dart" as http;
import "package:sesori_shared/sesori_shared.dart" show jsonCastMap, jsonDecodeListMap, jsonDecodeMap;

import "../../open_code_raw_http_client.dart";
import "../models/openapi/agent_info.g.dart";
import "../models/openapi/command_info.g.dart";
import "../models/openapi/form_info.g.dart";
import "../models/openapi/form_reply.g.dart";
import "../models/openapi/location_public_info.g.dart";
import "../models/openapi/model_info.g.dart";
import "../models/openapi/permission_request.g.dart";
import "../models/openapi/project.g.dart";
import "../models/openapi/provider_info.g.dart";
import "../models/openapi/server_info.g.dart";
import "../models/openapi/session_active.g.dart";
import "../models/openapi/session_inbox_compaction.g.dart";
import "../models/openapi/session_inbox_synthetic.g.dart";
import "../models/openapi/session_inbox_user.g.dart";
import "../models/openapi/session_info.g.dart";
import "../models/openapi/session_interrupt_response.g.dart";
import "../models/openapi/session_message_info.g.dart";
import "../models/openapi/session_messages_response.g.dart";
import "../models/openapi/sessions_response.g.dart";
import "../models/openapi/worktree_remove_input.g.dart";
import "../models/v2_data_response.dart";
import "../models/v2_decode_exception.dart";
import "../models/v2_page_order.dart";
import "../models/v2_request_bodies.dart";

/// OpenCode 2.x transport boundary. Auth, status checks and request deadlines
/// remain owned by the shared raw client; only v2 wire shapes live here.
class OpenCodeV2Api({required final OpenCodeRawHttpClient _client}) {
  static const _jsonHeaders = {"content-type": "application/json"};

  Future<ServerInfo> getServerInfo() async {
    const path = "/api/info";
    return _object<ServerInfo>(
      response: await _client.get(path: path),
      operation: path,
      fromJson: ServerInfo.fromJson,
    );
  }

  Future<LocationPublicInfo> getLocation({required String directory}) async {
    const path = "/api/location";
    return _object<LocationPublicInfo>(
      response: await _client.get(
        path: path,
        queryParameters: _location(directory: directory),
      ),
      operation: path,
      fromJson: LocationPublicInfo.fromJson,
    );
  }

  Future<List<Project>> listProjects() async {
    const path = "/api/project";
    return _decode<List<Project>>(
      response: await _client.get(path: path),
      operation: path,
      decode: (body) => jsonDecodeListMap(body).map(Project.fromJson).toList(),
    );
  }

  Future<Project> updateProject({required String projectId, required V2UpdateProjectBody body}) async {
    final path = "/api/project/${Uri.encodeComponent(projectId)}";
    return _object<Project>(
      response: await _client.patch(path: path, headers: _jsonHeaders, body: jsonEncode(body.toJson())),
      operation: path,
      fromJson: Project.fromJson,
    );
  }

  Future<List<SessionInfo>> listSessions({required String? directory, required String? parentId}) async {
    const path = "/api/session";
    final sessions = <SessionInfo>[];
    String? cursor;
    do {
      final page = _object(
        response: await _client.get(
          path: path,
          queryParameters: {
            "directory": ?directory,
            "parentID": ?parentId,
            "cursor": ?cursor,
            "order": V2PageOrder.asc.name,
            "limit": "100",
          },
        ),
        operation: path,
        fromJson: SessionsResponse.fromJson,
      );
      sessions.addAll(page.data);
      cursor = page.cursor.next;
    } while (cursor != null);
    return sessions;
  }

  Future<List<SessionMessageInfo>> listMessages({required String sessionId}) async {
    final path = "${_sessionPath(sessionId: sessionId)}/message";
    final messages = <SessionMessageInfo>[];
    String? cursor;
    do {
      final page = _object(
        response: await _client.get(
          path: path,
          queryParameters: {"cursor": ?cursor, "order": V2PageOrder.asc.name, "limit": "100"},
        ),
        operation: path,
        fromJson: SessionMessagesResponse.fromJson,
      );
      messages.addAll(page.data);
      cursor = page.cursor.next;
    } while (cursor != null);
    return messages;
  }

  Future<Map<String, SessionActive>> getActiveSessions() => _getData(
    path: "/api/session/active",
    directory: null,
    fromJson: (value) => jsonCastMap(value).map(
      (id, state) => MapEntry(id, SessionActive.fromJson(jsonCastMap(state))),
    ),
  );

  Future<SessionInfo> getSession({required String sessionId}) => _getData(
    path: _sessionPath(sessionId: sessionId),
    directory: null,
    fromJson: (value) => SessionInfo.fromJson(jsonCastMap(value)),
  );

  Future<SessionInfo> createSession({required V2CreateSessionBody body}) => _postData(
    path: "/api/session",
    body: body.toJson(),
    fromJson: (value) => SessionInfo.fromJson(jsonCastMap(value)),
  );

  Future<void> renameSession({required String sessionId, required V2RenameSessionBody body}) async {
    await _client.patch(
      path: _sessionPath(sessionId: sessionId),
      headers: _jsonHeaders,
      body: jsonEncode(body.toJson()),
    );
  }

  Future<void> deleteSession({required String sessionId}) async {
    await _client.delete(path: _sessionPath(sessionId: sessionId));
  }

  Future<void> switchAgent({required String sessionId, required V2SwitchAgentBody body}) async {
    await _client.post(
      path: "${_sessionPath(sessionId: sessionId)}/agent",
      headers: _jsonHeaders,
      body: jsonEncode(body.toJson()),
    );
  }

  Future<void> switchModel({required String sessionId, required V2SwitchModelBody body}) async {
    await _client.post(
      path: "${_sessionPath(sessionId: sessionId)}/model",
      headers: _jsonHeaders,
      body: jsonEncode(body.toJson()),
    );
  }

  Future<SessionInboxUser> prompt({required String sessionId, required V2PromptBody body}) => _postData(
    path: "${_sessionPath(sessionId: sessionId)}/prompt",
    body: body.toJson(),
    fromJson: (value) => SessionInboxUser.fromJson(jsonCastMap(value)),
  );

  Future<void> command({required String sessionId, required V2CommandBody body}) async {
    await _client.post(
      path: "${_sessionPath(sessionId: sessionId)}/command",
      headers: _jsonHeaders,
      body: jsonEncode(body.toJson()),
    );
  }

  Future<SessionInboxSynthetic> synthetic({required String sessionId, required V2SyntheticBody body}) => _postData(
    path: "${_sessionPath(sessionId: sessionId)}/synthetic",
    body: body.toJson(),
    fromJson: (value) => SessionInboxSynthetic.fromJson(jsonCastMap(value)),
  );

  Future<SessionInboxCompaction> compact({required String sessionId, required V2CompactBody body}) => _postData(
    path: "${_sessionPath(sessionId: sessionId)}/compact",
    body: body.toJson(),
    fromJson: (value) => SessionInboxCompaction.fromJson(jsonCastMap(value)),
  );

  Future<SessionInterruptResponse> interrupt({required String sessionId, required bool resume}) async {
    final path = "${_sessionPath(sessionId: sessionId)}/interrupt";
    return _object<SessionInterruptResponse>(
      response: await _client.post(path: path, queryParameters: {"resume": "$resume"}),
      operation: path,
      fromJson: SessionInterruptResponse.fromJson,
    );
  }

  Future<List<AgentInfo>> listAgents({required String directory}) =>
      _getList(path: "/api/agent", directory: directory, fromJson: AgentInfo.fromJson);

  Future<List<ModelInfo>> listModels({required String directory}) =>
      _getList(path: "/api/model", directory: directory, fromJson: ModelInfo.fromJson);

  Future<ModelInfo?> getDefaultModel({required String directory}) => _getData(
    path: "/api/model/default",
    directory: directory,
    fromJson: (value) => value == null ? null : ModelInfo.fromJson(jsonCastMap(value)),
  );

  Future<List<ProviderInfo>> listProviders({required String directory}) =>
      _getList(path: "/api/provider", directory: directory, fromJson: ProviderInfo.fromJson);

  Future<List<CommandInfo>> listCommands({required String directory}) =>
      _getList(path: "/api/command", directory: directory, fromJson: CommandInfo.fromJson);

  Future<List<PermissionRequest>> listPermissions({required String directory}) =>
      _getList(path: "/api/permission/request", directory: directory, fromJson: PermissionRequest.fromJson);

  Future<List<FormInfo>> listForms({required String directory}) =>
      _getList(path: "/api/form", directory: directory, fromJson: FormInfo.fromJson);

  Future<void> replyPermission({
    required String sessionId,
    required String requestId,
    required V2PermissionReplyBody body,
  }) async {
    await _client.post(
      path: "${_sessionPath(sessionId: sessionId)}/permission/${Uri.encodeComponent(requestId)}/reply",
      headers: _jsonHeaders,
      body: jsonEncode(body.toJson()),
    );
  }

  Future<void> replyForm({required String sessionId, required String formId, required FormReply body}) async {
    await _client.post(
      path: "${_sessionPath(sessionId: sessionId)}/form/${Uri.encodeComponent(formId)}/reply",
      headers: _jsonHeaders,
      body: jsonEncode(body.toJson()),
    );
  }

  Future<void> cancelForm({required String sessionId, required String formId}) async {
    await _client.delete(path: "${_sessionPath(sessionId: sessionId)}/form/${Uri.encodeComponent(formId)}");
  }

  Future<void> removeWorktree({required WorktreeRemoveInput body}) async {
    await _client.delete(path: "/api/worktree", headers: _jsonHeaders, body: jsonEncode(body.toJson()));
  }

  Future<List<T>> _getList<T>({
    required String path,
    required String directory,
    required T Function(Map<String, dynamic>) fromJson,
  }) => _getData(
    path: path,
    directory: directory,
    fromJson: (value) => (value! as List<Object?>).map((item) => fromJson(jsonCastMap(item))).toList(),
  );

  Future<T> _getData<T>({
    required String path,
    required String? directory,
    required T Function(Object?) fromJson,
  }) async => _data<T>(
    response: await _client.get(
      path: path,
      queryParameters: _location(directory: directory),
    ),
    operation: path,
    fromJson: fromJson,
  );

  Future<T> _postData<T>({
    required String path,
    required Map<String, dynamic> body,
    required T Function(Object?) fromJson,
  }) async => _data<T>(
    response: await _client.post(path: path, headers: _jsonHeaders, body: jsonEncode(body)),
    operation: path,
    fromJson: fromJson,
  );

  T _object<T>({
    required http.Response response,
    required String operation,
    required T Function(Map<String, dynamic>) fromJson,
  }) => _decode(response: response, operation: operation, decode: (body) => fromJson(jsonDecodeMap(body)));

  T _data<T>({required http.Response response, required String operation, required T Function(Object?) fromJson}) =>
      _decode(
        response: response,
        operation: operation,
        decode: (body) => V2DataResponse<T>.fromJson(jsonDecodeMap(body), fromJson).data,
      );

  T _decode<T>({required http.Response response, required String operation, required T Function(String) decode}) {
    try {
      return decode(response.body);
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(V2DecodeException(operation: operation, innerError: error), stackTrace);
    }
  }

  Map<String, String> _location({required String? directory}) => {"location[directory]": ?directory};

  String _sessionPath({required String sessionId}) => "/api/session/${Uri.encodeComponent(sessionId)}";
}
