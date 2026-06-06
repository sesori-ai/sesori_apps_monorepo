// GENERATED FILE - DO NOT EDIT BY HAND
//
// Auto-generated OpenCode v2 client generated from the OpenAPI spec.
//
// To regenerate, run:
//   dart run tool/generate_opencode_client.dart

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models/agent.dart';
import 'models/auth.dart';
import 'models/command.dart';
import 'models/config.dart';
import 'models/console_state.dart';
import 'models/file.dart';
import 'models/file_content.dart';
import 'models/file_node.dart';
import 'models/formatter_status.dart';
import 'models/global_session.dart';
import 'models/lspstatus.dart';
import 'models/mcpstatus.dart';
import 'models/part.dart';
import 'models/path.dart';
import 'models/permission_request.dart';
import 'models/project.dart';
import 'models/project_copy_copy.dart';
import 'models/project_directories.dart';
import 'models/provider_auth_authorization.dart';
import 'models/pty.dart';
import 'models/question_request.dart';
import 'models/question_v2_reply.dart';
import 'models/session.dart';
import 'models/snapshot_file_diff.dart';
import 'models/symbol.dart';
import 'models/todo.dart';
import 'models/tool_ids.dart';
import 'models/tool_list.dart';
import 'models/v2_session_messages_response.dart';
import 'models/v2_sessions_response.dart';
import 'models/vcs_file_diff.dart';
import 'models/vcs_file_status.dart';
import 'models/vcs_info.dart';
import 'models/workspace.dart';
import 'models/worktree.dart';
import 'models/worktree_create_input.dart';
import 'models/worktree_remove_input.dart';
import 'models/worktree_reset_input.dart';

/// OpenCode REST API client.
///
/// HTTP Basic auth: username `opencode`, password supplied at construction.
class OpenCodeClient {
  OpenCodeClient({
    required this.baseUrl,
    required String password,
    http.Client? httpClient,
  })  : _password = password,
        _http = httpClient ?? http.Client();

  /// Base URL of the OpenCode server, e.g. `http://127.0.0.1:4096`.
  final String baseUrl;
  final String _password;
  final http.Client _http;

  Map<String, String> get _authHeaders => {
    'Authorization': 'Basic ${base64Encode(utf8.encode('opencode:$_password'))}',
  };

  void close() => _http.close();

  // -------------------------------------------------------------------
  // Operations
  // -------------------------------------------------------------------

/// List agents
///
/// Get a list of all available AI agents in the OpenCode system.
///
/// `operationId`: `app.agents`
Future<List<Agent>> appAgents({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/agent',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as List<dynamic>;
    return decoded.map((e) => Agent.fromJson(e as Map<String, dynamic>)).toList();
  }


/// Write log
///
/// Write a log entry to the server logs with specified level and metadata.
///
/// `operationId`: `app.log`
Future<bool> appLog({
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/log',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// List skills
///
/// Get a list of all available skills in the OpenCode system.
///
/// `operationId`: `app.skills`
Future<List<dynamic>> appSkills({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/skill',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as List<dynamic>;
    return decoded.cast<dynamic>();
  }


/// Remove auth credentials
///
/// Remove authentication credentials
///
/// `operationId`: `auth.remove`
Future<bool> authRemove({
    required String providerID,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/auth/$providerID',
      queryParameters: {},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.delete(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// Set auth credentials
///
/// Set authentication credentials
///
/// `operationId`: `auth.set`
Future<bool> authSet({
    required String providerID,
    required Auth body,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/auth/$providerID',
      queryParameters: {},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body.toJson());
    final http.Response resp = await _http.put(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// List commands
///
/// Get a list of all available commands in the OpenCode system.
///
/// `operationId`: `command.list`
Future<List<Command>> commandList({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/command',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as List<dynamic>;
    return decoded.map((e) => Command.fromJson(e as Map<String, dynamic>)).toList();
  }


/// Get configuration
///
/// Retrieve the current OpenCode configuration settings and preferences.
///
/// `operationId`: `config.get`
Future<Config> configGet({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/config',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return Config.fromJson(decoded);
  }


/// List config providers
///
/// Get a list of all configured AI providers and their default models.
///
/// `operationId`: `config.providers`
Future<dynamic> configProviders({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/config/providers',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// Update configuration
///
/// Update OpenCode configuration settings and preferences.
///
/// `operationId`: `config.update`
Future<Config> configUpdate({
    required Config body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/config',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body.toJson());
    final http.Response resp = await _http.patch(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return Config.fromJson(decoded);
  }


/// Subscribe to events
///
/// Get events
///
/// `operationId`: `event.subscribe`
Future<dynamic> eventSubscribe({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/event',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// Get active Console provider metadata
///
/// Get the active Console org name and the set of provider IDs managed by that Console org.
///
/// `operationId`: `experimental.console.get`
Future<ConsoleState> experimentalConsoleGet({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/experimental/console',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return ConsoleState.fromJson(decoded);
  }


/// List switchable Console orgs
///
/// Get the available Console orgs across logged-in accounts, including the current active org.
///
/// `operationId`: `experimental.console.listOrgs`
Future<dynamic> experimentalConsoleListOrgs({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/experimental/console/orgs',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// Switch active Console org
///
/// Persist a new active Console account/org selection for the current local OpenCode state.
///
/// `operationId`: `experimental.console.switchOrg`
Future<bool> experimentalConsoleSwitchOrg({
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/experimental/console/switch',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// Move session
///
/// Move a session to another project directory, optionally transferring local changes.
///
/// `operationId`: `experimental.controlPlane.moveSession`
Future<void> experimentalControlPlaneMoveSession({
    required Map<String, dynamic> body,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/experimental/control-plane/move-session',
      queryParameters: {},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return;
  }


/// Create project copy
///
/// Create a local physical copy of a project using the selected strategy.
///
/// `operationId`: `experimental.projectCopy.create`
Future<ProjectCopyCopy> experimentalProjectCopyCreate({
    required String projectID,
    required Map<String, dynamic> body,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/experimental/project/$projectID/copy',
      queryParameters: {if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return ProjectCopyCopy.fromJson(decoded);
  }


/// Refresh project copies
///
/// Discover local project copies using one or all configured strategies.
///
/// `operationId`: `experimental.projectCopy.refresh`
Future<void> experimentalProjectCopyRefresh({
    required String projectID,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/experimental/project/$projectID/copy/refresh',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.post(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return;
  }


/// Remove project copy
///
/// Remove a local physical copy of a project using the selected strategy.
///
/// `operationId`: `experimental.projectCopy.remove`
Future<void> experimentalProjectCopyRemove({
    required String projectID,
    required Map<String, dynamic> body,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/experimental/project/$projectID/copy',
      queryParameters: {if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.delete(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return;
  }


/// Get MCP resources
///
/// Get all available MCP resources from connected servers. Optionally filter by name.
///
/// `operationId`: `experimental.resource.list`
Future<dynamic> experimentalResourceList({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/experimental/resource',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// Background subagents
///
/// Detach any synchronous subagents currently blocking the session and continue them in the background.
///
/// `operationId`: `experimental.session.background`
Future<bool> experimentalSessionBackground({
    required String sessionID,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/experimental/session/$sessionID/background',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.post(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// List sessions
///
/// Get a list of all OpenCode sessions across projects, sorted by most recently updated. Archived sessions are excluded by default.
///
/// `operationId`: `experimental.session.list`
Future<List<GlobalSession>> experimentalSessionList({
    String? directory,
    String? workspace,
    String? roots,
    double? start,
    double? cursor,
    String? search,
    double? limit,
    String? archived,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/experimental/session',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString(), if (roots != null) 'roots': roots.toString(), if (start != null) 'start': start.toString(), if (cursor != null) 'cursor': cursor.toString(), if (search != null) 'search': search.toString(), if (limit != null) 'limit': limit.toString(), if (archived != null) 'archived': archived.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as List<dynamic>;
    return decoded.map((e) => GlobalSession.fromJson(e as Map<String, dynamic>)).toList();
  }


/// List workspace adapters
///
/// List all available workspace adapters for the current project.
///
/// `operationId`: `experimental.workspace.adapter.list`
Future<List<dynamic>> experimentalWorkspaceAdapterList({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/experimental/workspace/adapter',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as List<dynamic>;
    return decoded.cast<dynamic>();
  }


/// Create workspace
///
/// Create a workspace for the current project.
///
/// `operationId`: `experimental.workspace.create`
Future<Workspace> experimentalWorkspaceCreate({
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/experimental/workspace',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return Workspace.fromJson(decoded);
  }


/// List workspaces
///
/// List all workspaces.
///
/// `operationId`: `experimental.workspace.list`
Future<List<Workspace>> experimentalWorkspaceList({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/experimental/workspace',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as List<dynamic>;
    return decoded.map((e) => Workspace.fromJson(e as Map<String, dynamic>)).toList();
  }


/// Remove workspace
///
/// Remove an existing workspace.
///
/// `operationId`: `experimental.workspace.remove`
Future<Workspace> experimentalWorkspaceRemove({
    required String id,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/experimental/workspace/$id',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.delete(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return Workspace.fromJson(decoded);
  }


/// Workspace status
///
/// Get connection status for workspaces in the current project.
///
/// `operationId`: `experimental.workspace.status`
Future<List<dynamic>> experimentalWorkspaceStatus({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/experimental/workspace/status',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as List<dynamic>;
    return decoded.cast<dynamic>();
  }


/// Sync workspace list
///
/// Register missing workspaces returned by workspace adapters.
///
/// `operationId`: `experimental.workspace.syncList`
Future<void> experimentalWorkspaceSyncList({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/experimental/workspace/sync-list',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.post(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return;
  }


/// Warp session into workspace
///
/// Move a session's sync history into the target workspace, or detach it to the local project.
///
/// `operationId`: `experimental.workspace.warp`
Future<void> experimentalWorkspaceWarp({
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/experimental/workspace/warp',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return;
  }


/// List files
///
/// List files and directories in a specified path.
///
/// `operationId`: `file.list`
Future<List<FileNode>> fileList({
    String? directory,
    String? workspace,
    required String path,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/file',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString(), 'path': path.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as List<dynamic>;
    return decoded.map((e) => FileNode.fromJson(e as Map<String, dynamic>)).toList();
  }


/// Read file
///
/// Read the content of a specified file.
///
/// `operationId`: `file.read`
Future<FileContent> fileRead({
    String? directory,
    String? workspace,
    required String path,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/file/content',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString(), 'path': path.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return FileContent.fromJson(decoded);
  }


/// Get file status
///
/// Get the git status of all files in the project.
///
/// `operationId`: `file.status`
Future<List<File>> fileStatus({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/file/status',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as List<dynamic>;
    return decoded.map((e) => File.fromJson(e as Map<String, dynamic>)).toList();
  }


/// Find files
///
/// Search for files or directories by name or pattern in the project directory.
///
/// `operationId`: `find.files`
Future<List<String>> findFiles({
    String? directory,
    String? workspace,
    required String query,
    String? dirs,
    String? type,
    int? limit,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/find/file',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString(), 'query': query.toString(), if (dirs != null) 'dirs': dirs.toString(), if (type != null) 'type': type.toString(), if (limit != null) 'limit': limit.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as List<dynamic>;
    return decoded.cast<String>();
  }


/// Find symbols
///
/// Search for workspace symbols like functions, classes, and variables using LSP.
///
/// `operationId`: `find.symbols`
Future<List<Symbol>> findSymbols({
    String? directory,
    String? workspace,
    required String query,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/find/symbol',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString(), 'query': query.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as List<dynamic>;
    return decoded.map((e) => Symbol.fromJson(e as Map<String, dynamic>)).toList();
  }


/// Find text
///
/// Search for text patterns across files in the project using ripgrep.
///
/// `operationId`: `find.text`
Future<List<dynamic>> findText({
    String? directory,
    String? workspace,
    required String pattern,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/find',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString(), 'pattern': pattern.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as List<dynamic>;
    return decoded.cast<dynamic>();
  }


/// Get formatter status
///
/// `operationId`: `formatter.status`
Future<List<FormatterStatus>> formatterStatus({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/formatter',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as List<dynamic>;
    return decoded.map((e) => FormatterStatus.fromJson(e as Map<String, dynamic>)).toList();
  }


/// Get global configuration
///
/// Retrieve the current global OpenCode configuration settings and preferences.
///
/// `operationId`: `global.config.get`
Future<Config> globalConfigGet() async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/global/config',
      queryParameters: {},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return Config.fromJson(decoded);
  }


/// Update global configuration
///
/// Update global OpenCode configuration settings and preferences.
///
/// `operationId`: `global.config.update`
Future<Config> globalConfigUpdate({
    required Config body,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/global/config',
      queryParameters: {},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body.toJson());
    final http.Response resp = await _http.patch(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return Config.fromJson(decoded);
  }


/// Dispose instance
///
/// Clean up and dispose all OpenCode instances, releasing all resources.
///
/// `operationId`: `global.dispose`
Future<bool> globalDispose() async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/global/dispose',
      queryParameters: {},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.post(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// Get global events
///
/// Subscribe to global events from the OpenCode system using server-sent events.
///
/// `operationId`: `global.event`
Future<dynamic> globalEvent() async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/global/event',
      queryParameters: {},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// Get health
///
/// Get health information about the OpenCode server.
///
/// `operationId`: `global.health`
Future<dynamic> globalHealth() async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/global/health',
      queryParameters: {},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// Upgrade opencode
///
/// Upgrade opencode to the specified version or latest if not specified.
///
/// `operationId`: `global.upgrade`
Future<dynamic> globalUpgrade({
    required Map<String, dynamic> body,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/global/upgrade',
      queryParameters: {},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// Dispose instance
///
/// Clean up and dispose the current OpenCode instance, releasing all resources.
///
/// `operationId`: `instance.dispose`
Future<bool> instanceDispose({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/instance/dispose',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.post(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// Get LSP status
///
/// Get LSP server status
///
/// `operationId`: `lsp.status`
Future<List<LSPStatus>> lspStatus({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/lsp',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as List<dynamic>;
    return decoded.map((e) => LSPStatus.fromJson(e as Map<String, dynamic>)).toList();
  }


/// Add MCP server
///
/// Dynamically add a new Model Context Protocol (MCP) server to the system.
///
/// `operationId`: `mcp.add`
Future<dynamic> mcpAdd({
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/mcp',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// Authenticate MCP OAuth
///
/// Start OAuth flow and wait for callback (opens browser).
///
/// `operationId`: `mcp.auth.authenticate`
Future<MCPStatus> mcpAuthAuthenticate({
    required String name,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/mcp/$name/auth/authenticate',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.post(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return MCPStatus.fromJson(decoded);
  }


/// Complete MCP OAuth
///
/// Complete OAuth authentication for a Model Context Protocol (MCP) server using the authorization code.
///
/// `operationId`: `mcp.auth.callback`
Future<MCPStatus> mcpAuthCallback({
    required String name,
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/mcp/$name/auth/callback',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return MCPStatus.fromJson(decoded);
  }


/// Remove MCP OAuth
///
/// Remove OAuth credentials for an MCP server.
///
/// `operationId`: `mcp.auth.remove`
Future<dynamic> mcpAuthRemove({
    required String name,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/mcp/$name/auth',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.delete(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// Start MCP OAuth
///
/// Start OAuth authentication flow for a Model Context Protocol (MCP) server.
///
/// `operationId`: `mcp.auth.start`
Future<dynamic> mcpAuthStart({
    required String name,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/mcp/$name/auth',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.post(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// Connect an MCP server.
///
/// Connect an MCP server.
///
/// `operationId`: `mcp.connect`
Future<bool> mcpConnect({
    required String name,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/mcp/$name/connect',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.post(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// Disconnect an MCP server.
///
/// Disconnect an MCP server.
///
/// `operationId`: `mcp.disconnect`
Future<bool> mcpDisconnect({
    required String name,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/mcp/$name/disconnect',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.post(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// Get MCP status
///
/// Get the status of all Model Context Protocol (MCP) servers.
///
/// `operationId`: `mcp.status`
Future<dynamic> mcpStatus({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/mcp',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// Delete a part from a message.
///
/// Delete a part from a message.
///
/// `operationId`: `part.delete`
Future<bool> partDelete({
    required String sessionID,
    required String messageID,
    required String partID,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/session/$sessionID/message/$messageID/part/$partID',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.delete(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// Update a part in a message.
///
/// Update a part in a message.
///
/// `operationId`: `part.update`
Future<Part> partUpdate({
    required String sessionID,
    required String messageID,
    required String partID,
    required Part body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/session/$sessionID/message/$messageID/part/$partID',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body.toJson());
    final http.Response resp = await _http.patch(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return Part.fromJson(decoded);
  }


/// Get paths
///
/// Retrieve the current working directory and related path information for the OpenCode instance.
///
/// `operationId`: `path.get`
Future<Path> pathGet({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/path',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return Path.fromJson(decoded);
  }


/// List pending permissions
///
/// Get all pending permission requests across all sessions.
///
/// `operationId`: `permission.list`
Future<List<PermissionRequest>> permissionList({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/permission',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as List<dynamic>;
    return decoded.map((e) => PermissionRequest.fromJson(e as Map<String, dynamic>)).toList();
  }


/// Respond to permission request
///
/// Approve or deny a permission request from the AI assistant.
///
/// `operationId`: `permission.reply`
Future<bool> permissionReply({
    required String requestID,
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/permission/$requestID/reply',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// Respond to permission
///
/// Approve or deny a permission request from the AI assistant.
///
/// `operationId`: `permission.respond`
Future<bool> permissionRespond({
    required String sessionID,
    required String permissionID,
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/session/$sessionID/permissions/$permissionID',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// Get current project
///
/// Retrieve the currently active project that OpenCode is working with.
///
/// `operationId`: `project.current`
Future<Project> projectCurrent({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/project/current',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return Project.fromJson(decoded);
  }


/// List project directories
///
/// List known local absolute directories for a project.
///
/// `operationId`: `project.directories`
Future<ProjectDirectories> projectDirectories({
    required String projectID,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/project/$projectID/directories',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as List<dynamic>;
    return ProjectDirectories.fromJson(decoded);
  }


/// Initialize git repository
///
/// Create a git repository for the current project and return the refreshed project info.
///
/// `operationId`: `project.initGit`
Future<Project> projectInitGit({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/project/git/init',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.post(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return Project.fromJson(decoded);
  }


/// List all projects
///
/// Get a list of projects that have been opened with OpenCode.
///
/// `operationId`: `project.list`
Future<List<Project>> projectList({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/project',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as List<dynamic>;
    return decoded.map((e) => Project.fromJson(e as Map<String, dynamic>)).toList();
  }


/// Update project
///
/// Update project properties such as name, icon, and commands.
///
/// `operationId`: `project.update`
Future<Project> projectUpdate({
    required String projectID,
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/project/$projectID',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.patch(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return Project.fromJson(decoded);
  }


/// Get provider auth methods
///
/// Retrieve available authentication methods for all AI providers.
///
/// `operationId`: `provider.auth`
Future<dynamic> providerAuth({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/provider/auth',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// List providers
///
/// Get a list of all available AI providers, including both available and connected ones.
///
/// `operationId`: `provider.list`
Future<dynamic> providerList({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/provider',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// Start OAuth authorization
///
/// Start the OAuth authorization flow for a provider.
///
/// `operationId`: `provider.oauth.authorize`
Future<ProviderAuthAuthorization> providerOauthAuthorize({
    required String providerID,
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/provider/$providerID/oauth/authorize',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return ProviderAuthAuthorization.fromJson(decoded);
  }


/// Handle OAuth callback
///
/// Handle the OAuth callback from a provider after user authorization.
///
/// `operationId`: `provider.oauth.callback`
Future<bool> providerOauthCallback({
    required String providerID,
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/provider/$providerID/oauth/callback',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// Connect to PTY session
///
/// Establish a WebSocket connection to interact with a pseudo-terminal (PTY) session in real-time.
///
/// `operationId`: `pty.connect`
Future<bool> ptyConnect({
    required String ptyID,
    String? directory,
    String? workspace,
    String? cursor,
    String? ticket,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/pty/$ptyID/connect',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString(), if (cursor != null) 'cursor': cursor.toString(), if (ticket != null) 'ticket': ticket.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// Create PTY WebSocket token
///
/// Create a short-lived ticket for opening a PTY WebSocket connection.
///
/// `operationId`: `pty.connectToken`
Future<dynamic> ptyConnectToken({
    required String ptyID,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/pty/$ptyID/connect-token',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.post(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// Create PTY session
///
/// Create a new pseudo-terminal (PTY) session for running shell commands and processes.
///
/// `operationId`: `pty.create`
Future<Pty> ptyCreate({
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/pty',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return Pty.fromJson(decoded);
  }


/// Get PTY session
///
/// Retrieve detailed information about a specific pseudo-terminal (PTY) session.
///
/// `operationId`: `pty.get`
Future<Pty> ptyGet({
    required String ptyID,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/pty/$ptyID',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return Pty.fromJson(decoded);
  }


/// List PTY sessions
///
/// Get a list of all active pseudo-terminal (PTY) sessions managed by OpenCode.
///
/// `operationId`: `pty.list`
Future<List<Pty>> ptyList({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/pty',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as List<dynamic>;
    return decoded.map((e) => Pty.fromJson(e as Map<String, dynamic>)).toList();
  }


/// Remove PTY session
///
/// Remove and terminate a specific pseudo-terminal (PTY) session.
///
/// `operationId`: `pty.remove`
Future<bool> ptyRemove({
    required String ptyID,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/pty/$ptyID',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.delete(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// List available shells
///
/// Get a list of available shells on the system.
///
/// `operationId`: `pty.shells`
Future<List<dynamic>> ptyShells({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/pty/shells',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as List<dynamic>;
    return decoded.cast<dynamic>();
  }


/// Update PTY session
///
/// Update properties of an existing pseudo-terminal (PTY) session.
///
/// `operationId`: `pty.update`
Future<Pty> ptyUpdate({
    required String ptyID,
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/pty/$ptyID',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.put(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return Pty.fromJson(decoded);
  }


/// List pending questions
///
/// Get all pending question requests across all sessions.
///
/// `operationId`: `question.list`
Future<List<QuestionRequest>> questionList({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/question',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as List<dynamic>;
    return decoded.map((e) => QuestionRequest.fromJson(e as Map<String, dynamic>)).toList();
  }


/// Reject question request
///
/// Reject a question request from the AI assistant.
///
/// `operationId`: `question.reject`
Future<bool> questionReject({
    required String requestID,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/question/$requestID/reject',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.post(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// Reply to question request
///
/// Provide answers to a question request from the AI assistant.
///
/// `operationId`: `question.reply`
Future<bool> questionReply({
    required String requestID,
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/question/$requestID/reply',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// Abort session
///
/// Abort an active session and stop any ongoing AI processing or command execution.
///
/// `operationId`: `session.abort`
Future<bool> sessionAbort({
    required String sessionID,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/session/$sessionID/abort',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.post(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// Get session children
///
/// Retrieve all child sessions that were forked from the specified parent session.
///
/// `operationId`: `session.children`
Future<List<Session>> sessionChildren({
    required String sessionID,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/session/$sessionID/children',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as List<dynamic>;
    return decoded.map((e) => Session.fromJson(e as Map<String, dynamic>)).toList();
  }


/// Send command
///
/// Send a new command to a session for execution by the AI assistant.
///
/// `operationId`: `session.command`
Future<dynamic> sessionCommand({
    required String sessionID,
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/session/$sessionID/command',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// Create session
///
/// Create a new OpenCode session for interacting with AI assistants and managing conversations.
///
/// `operationId`: `session.create`
Future<Session> sessionCreate({
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/session',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return Session.fromJson(decoded);
  }


/// Delete session
///
/// Delete a session and permanently remove all associated data, including messages and history.
///
/// `operationId`: `session.delete`
Future<bool> sessionDelete({
    required String sessionID,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/session/$sessionID',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.delete(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// Delete message
///
/// Permanently delete a specific message and all of its parts from a session without reverting file changes.
///
/// `operationId`: `session.deleteMessage`
Future<bool> sessionDeleteMessage({
    required String sessionID,
    required String messageID,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/session/$sessionID/message/$messageID',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.delete(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// Get message diff
///
/// Get the file changes (diff) that resulted from a specific user message in the session.
///
/// `operationId`: `session.diff`
Future<List<SnapshotFileDiff>> sessionDiff({
    required String sessionID,
    String? directory,
    String? workspace,
    String? messageID,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/session/$sessionID/diff',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString(), if (messageID != null) 'messageID': messageID.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as List<dynamic>;
    return decoded.map((e) => SnapshotFileDiff.fromJson(e as Map<String, dynamic>)).toList();
  }


/// Fork session
///
/// Create a new session by forking an existing session at a specific message point.
///
/// `operationId`: `session.fork`
Future<Session> sessionFork({
    required String sessionID,
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/session/$sessionID/fork',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return Session.fromJson(decoded);
  }


/// Get session
///
/// Retrieve detailed information about a specific OpenCode session.
///
/// `operationId`: `session.get`
Future<Session> sessionGet({
    required String sessionID,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/session/$sessionID',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return Session.fromJson(decoded);
  }


/// Initialize session
///
/// Analyze the current application and create an AGENTS.md file with project-specific agent configurations.
///
/// `operationId`: `session.init`
Future<bool> sessionInit({
    required String sessionID,
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/session/$sessionID/init',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// List sessions
///
/// Get a list of all OpenCode sessions, sorted by most recently updated.
///
/// `operationId`: `session.list`
Future<List<Session>> sessionList({
    String? directory,
    String? workspace,
    String? scope,
    String? path,
    String? roots,
    double? start,
    String? search,
    double? limit,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/session',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString(), if (scope != null) 'scope': scope.toString(), if (path != null) 'path': path.toString(), if (roots != null) 'roots': roots.toString(), if (start != null) 'start': start.toString(), if (search != null) 'search': search.toString(), if (limit != null) 'limit': limit.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as List<dynamic>;
    return decoded.map((e) => Session.fromJson(e as Map<String, dynamic>)).toList();
  }


/// Get message
///
/// Retrieve a specific message from a session by its message ID.
///
/// `operationId`: `session.message`
Future<dynamic> sessionMessage({
    required String sessionID,
    required String messageID,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/session/$sessionID/message/$messageID',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// Get session messages
///
/// Retrieve all messages in a session, including user prompts and AI responses.
///
/// `operationId`: `session.messages`
Future<List<dynamic>> sessionMessages({
    required String sessionID,
    String? directory,
    String? workspace,
    int? limit,
    String? before,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/session/$sessionID/message',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString(), if (limit != null) 'limit': limit.toString(), if (before != null) 'before': before.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as List<dynamic>;
    return decoded.cast<dynamic>();
  }


/// Send message
///
/// Create and send a new message to a session, streaming the AI response.
///
/// `operationId`: `session.prompt`
Future<dynamic> sessionPrompt({
    required String sessionID,
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/session/$sessionID/message',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// Send async message
///
/// Create and send a new message to a session asynchronously, starting the session if needed and returning immediately.
///
/// `operationId`: `session.prompt_async`
Future<void> sessionPromptAsync({
    required String sessionID,
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/session/$sessionID/prompt_async',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return;
  }


/// Revert message
///
/// Revert a specific message in a session, undoing its effects and restoring the previous state.
///
/// `operationId`: `session.revert`
Future<Session> sessionRevert({
    required String sessionID,
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/session/$sessionID/revert',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return Session.fromJson(decoded);
  }


/// Share session
///
/// Create a shareable link for a session, allowing others to view the conversation.
///
/// `operationId`: `session.share`
Future<Session> sessionShare({
    required String sessionID,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/session/$sessionID/share',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.post(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return Session.fromJson(decoded);
  }


/// Run shell command
///
/// Execute a shell command within the session context and return the AI's response.
///
/// `operationId`: `session.shell`
Future<dynamic> sessionShell({
    required String sessionID,
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/session/$sessionID/shell',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// Get session status
///
/// Retrieve the current status of all sessions, including active, idle, and completed states.
///
/// `operationId`: `session.status`
Future<dynamic> sessionStatus({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/session/status',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// Summarize session
///
/// Generate a concise summary of the session using AI compaction to preserve key information.
///
/// `operationId`: `session.summarize`
Future<bool> sessionSummarize({
    required String sessionID,
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/session/$sessionID/summarize',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// Get session todos
///
/// Retrieve the todo list associated with a specific session, showing tasks and action items.
///
/// `operationId`: `session.todo`
Future<List<Todo>> sessionTodo({
    required String sessionID,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/session/$sessionID/todo',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as List<dynamic>;
    return decoded.map((e) => Todo.fromJson(e as Map<String, dynamic>)).toList();
  }


/// Restore reverted messages
///
/// Restore all previously reverted messages in a session.
///
/// `operationId`: `session.unrevert`
Future<Session> sessionUnrevert({
    required String sessionID,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/session/$sessionID/unrevert',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.post(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return Session.fromJson(decoded);
  }


/// Unshare session
///
/// Remove the shareable link for a session, making it private again.
///
/// `operationId`: `session.unshare`
Future<Session> sessionUnshare({
    required String sessionID,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/session/$sessionID/share',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.delete(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return Session.fromJson(decoded);
  }


/// Update session
///
/// Update properties of an existing session, such as title or other metadata.
///
/// `operationId`: `session.update`
Future<Session> sessionUpdate({
    required String sessionID,
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/session/$sessionID',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.patch(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return Session.fromJson(decoded);
  }


/// List sync events
///
/// List sync events for all aggregates. Keys are aggregate IDs the client already knows about, values are the last known sequence ID. Events with seq > value are returned for those aggregates. Aggregates not listed in the input get their full history.
///
/// `operationId`: `sync.history.list`
Future<List<dynamic>> syncHistoryList({
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/sync/history',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as List<dynamic>;
    return decoded.cast<dynamic>();
  }


/// Replay sync events
///
/// Validate and replay a complete sync event history.
///
/// `operationId`: `sync.replay`
Future<dynamic> syncReplay({
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/sync/replay',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// Start workspace sync
///
/// Start sync loops for workspaces in the current project that have active sessions.
///
/// `operationId`: `sync.start`
Future<bool> syncStart({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/sync/start',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.post(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// Steal session into workspace
///
/// Update a session to belong to the current workspace through the sync event system.
///
/// `operationId`: `sync.steal`
Future<dynamic> syncSteal({
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/sync/steal',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// List tool IDs
///
/// Get a list of all available tool IDs, including both built-in tools and dynamically registered tools.
///
/// `operationId`: `tool.ids`
Future<ToolIDs> toolIds({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/experimental/tool/ids',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as List<dynamic>;
    return ToolIDs.fromJson(decoded);
  }


/// List tools
///
/// Get a list of available tools with their JSON schema parameters for a specific provider and model combination.
///
/// `operationId`: `tool.list`
Future<ToolList> toolList({
    String? directory,
    String? workspace,
    required String provider,
    required String model,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/experimental/tool',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString(), 'provider': provider.toString(), 'model': model.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as List<dynamic>;
    return ToolList.fromJson(decoded);
  }


/// Append TUI prompt
///
/// Append prompt to the TUI.
///
/// `operationId`: `tui.appendPrompt`
Future<bool> tuiAppendPrompt({
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/tui/append-prompt',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// Clear TUI prompt
///
/// Clear the prompt.
///
/// `operationId`: `tui.clearPrompt`
Future<bool> tuiClearPrompt({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/tui/clear-prompt',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.post(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// Get next TUI request
///
/// Retrieve the next TUI request from the queue for processing.
///
/// `operationId`: `tui.control.next`
Future<dynamic> tuiControlNext({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/tui/control/next',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// Submit TUI response
///
/// Submit a response to the TUI request queue to complete a pending request.
///
/// `operationId`: `tui.control.response`
Future<bool> tuiControlResponse({
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/tui/control/response',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// Execute TUI command
///
/// Execute a TUI command.
///
/// `operationId`: `tui.executeCommand`
Future<bool> tuiExecuteCommand({
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/tui/execute-command',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// Open help dialog
///
/// Open the help dialog in the TUI to display user assistance information.
///
/// `operationId`: `tui.openHelp`
Future<bool> tuiOpenHelp({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/tui/open-help',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.post(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// Open models dialog
///
/// Open the model dialog.
///
/// `operationId`: `tui.openModels`
Future<bool> tuiOpenModels({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/tui/open-models',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.post(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// Open sessions dialog
///
/// Open the session dialog.
///
/// `operationId`: `tui.openSessions`
Future<bool> tuiOpenSessions({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/tui/open-sessions',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.post(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// Open themes dialog
///
/// Open the theme dialog.
///
/// `operationId`: `tui.openThemes`
Future<bool> tuiOpenThemes({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/tui/open-themes',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.post(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// Publish TUI event
///
/// Publish a TUI event.
///
/// `operationId`: `tui.publish`
Future<bool> tuiPublish({
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/tui/publish',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// Select session
///
/// Navigate the TUI to display the specified session.
///
/// `operationId`: `tui.selectSession`
Future<bool> tuiSelectSession({
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/tui/select-session',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// Show TUI toast
///
/// Show a toast notification in the TUI.
///
/// `operationId`: `tui.showToast`
Future<bool> tuiShowToast({
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/tui/show-toast',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// Submit TUI prompt
///
/// Submit the prompt.
///
/// `operationId`: `tui.submitPrompt`
Future<bool> tuiSubmitPrompt({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/tui/submit-prompt',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.post(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// List v2 agents
///
/// Retrieve currently registered v2 agents.
///
/// `operationId`: `v2.agent.list`
Future<dynamic> v2AgentList({
    Map<String, dynamic>? location,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/api/agent',
      queryParameters: {if (location != null) 'location': location.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// List v2 commands
///
/// Retrieve currently registered v2 commands.
///
/// `operationId`: `v2.command.list`
Future<dynamic> v2CommandList({
    Map<String, dynamic>? location,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/api/command',
      queryParameters: {if (location != null) 'location': location.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// Subscribe to v2 events
///
/// Subscribe to native EventV2 payloads for a location.
///
/// `operationId`: `v2.event.subscribe`
Future<dynamic> v2EventSubscribe({
    Map<String, dynamic>? location,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/api/event',
      queryParameters: {if (location != null) 'location': location.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// List directory
///
/// List direct children of one directory relative to the requested location.
///
/// `operationId`: `v2.fs.list`
Future<dynamic> v2FsList({
    Map<String, dynamic>? location,
    String? path,
    String? reference,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/api/fs/list',
      queryParameters: {if (location != null) 'location': location.toString(), if (path != null) 'path': path.toString(), if (reference != null) 'reference': reference.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// Read file
///
/// Read one file relative to the requested location.
///
/// `operationId`: `v2.fs.read`
Future<dynamic> v2FsRead({
    Map<String, dynamic>? location,
    required String path,
    String? reference,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/api/fs/read',
      queryParameters: {if (location != null) 'location': location.toString(), 'path': path.toString(), if (reference != null) 'reference': reference.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// Check v2 server health
///
/// Check whether the v2 API server is ready to accept requests.
///
/// `operationId`: `v2.health.get`
Future<dynamic> v2HealthGet() async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/api/health',
      queryParameters: {},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// List v2 models
///
/// Retrieve available v2 models ordered by release date.
///
/// `operationId`: `v2.model.list`
Future<dynamic> v2ModelList({
    Map<String, dynamic>? location,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/api/model',
      queryParameters: {if (location != null) 'location': location.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// List pending permission requests
///
/// Retrieve pending permission requests for a location.
///
/// `operationId`: `v2.permission.request.list`
Future<dynamic> v2PermissionRequestList({
    Map<String, dynamic>? location,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/api/permission/request',
      queryParameters: {if (location != null) 'location': location.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// List saved permissions
///
/// Retrieve saved permissions, optionally filtered by project.
///
/// `operationId`: `v2.permission.saved.list`
Future<dynamic> v2PermissionSavedList({
    String? projectID,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/api/permission/saved',
      queryParameters: {if (projectID != null) 'projectID': projectID.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// Remove saved permission
///
/// Remove a saved permission by ID.
///
/// `operationId`: `v2.permission.saved.remove`
Future<void> v2PermissionSavedRemove({
    required String id,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/api/permission/saved/$id',
      queryParameters: {},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.delete(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return;
  }


/// Get v2 provider
///
/// Retrieve a single v2 AI provider so clients can inspect its availability and endpoint settings.
///
/// `operationId`: `v2.provider.get`
Future<dynamic> v2ProviderGet({
    required String providerID,
    Map<String, dynamic>? location,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/api/provider/$providerID',
      queryParameters: {if (location != null) 'location': location.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// List v2 providers
///
/// Retrieve active v2 AI providers so clients can show provider availability and configuration.
///
/// `operationId`: `v2.provider.list`
Future<dynamic> v2ProviderList({
    Map<String, dynamic>? location,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/api/provider',
      queryParameters: {if (location != null) 'location': location.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// List pending question requests
///
/// Retrieve pending question requests for a location.
///
/// `operationId`: `v2.question.request.list`
Future<dynamic> v2QuestionRequestList({
    Map<String, dynamic>? location,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/api/question/request',
      queryParameters: {if (location != null) 'location': location.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// Compact v2 session
///
/// Compact a v2 session conversation.
///
/// `operationId`: `v2.session.compact`
Future<void> v2SessionCompact({
    required String sessionID,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/api/session/$sessionID/compact',
      queryParameters: {},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.post(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return;
  }


/// Get v2 session context
///
/// Retrieve the active context messages for a v2 session (all messages after the last compaction).
///
/// `operationId`: `v2.session.context`
Future<dynamic> v2SessionContext({
    required String sessionID,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/api/session/$sessionID/context',
      queryParameters: {},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// List v2 sessions
///
/// Retrieve sessions in the requested order. Items keep that order across pages; use cursor.next or cursor.previous to move through the ordered list.
///
/// `operationId`: `v2.session.list`
Future<V2SessionsResponse> v2SessionList({
    String? workspace,
    double? limit,
    String? order,
    String? search,
    String? directory,
    String? project,
    String? subpath,
    String? cursor,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/api/session',
      queryParameters: {if (workspace != null) 'workspace': workspace.toString(), if (limit != null) 'limit': limit.toString(), if (order != null) 'order': order.toString(), if (search != null) 'search': search.toString(), if (directory != null) 'directory': directory.toString(), if (project != null) 'project': project.toString(), if (subpath != null) 'subpath': subpath.toString(), if (cursor != null) 'cursor': cursor.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return V2SessionsResponse.fromJson(decoded);
  }


/// Get v2 session messages
///
/// Retrieve projected v2 messages for a session. Items keep the requested order across pages; use cursor.next or cursor.previous to move through the ordered timeline.
///
/// `operationId`: `v2.session.messages`
Future<V2SessionMessagesResponse> v2SessionMessages({
    required String sessionID,
    double? limit,
    String? order,
    String? cursor,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/api/session/$sessionID/message',
      queryParameters: {if (limit != null) 'limit': limit.toString(), if (order != null) 'order': order.toString(), if (cursor != null) 'cursor': cursor.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return V2SessionMessagesResponse.fromJson(decoded);
  }


/// List session permission requests
///
/// Retrieve pending permission requests owned by a session.
///
/// `operationId`: `v2.session.permission.list`
Future<dynamic> v2SessionPermissionList({
    required String sessionID,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/api/session/$sessionID/permission/request',
      queryParameters: {},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// Reply to pending permission request
///
/// Respond to a pending permission request owned by a session.
///
/// `operationId`: `v2.session.permission.reply`
Future<void> v2SessionPermissionReply({
    required String sessionID,
    required String requestID,
    required Map<String, dynamic> body,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/api/session/$sessionID/permission/request/$requestID/reply',
      queryParameters: {},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return;
  }


/// Send v2 message
///
/// Durably admit one v2 session input and schedule agent-loop execution unless resume is false.
///
/// `operationId`: `v2.session.prompt`
Future<dynamic> v2SessionPrompt({
    required String sessionID,
    required Map<String, dynamic> body,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/api/session/$sessionID/prompt',
      queryParameters: {},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// Reject pending question request
///
/// Reject a pending question request owned by a session.
///
/// `operationId`: `v2.session.question.reject`
Future<void> v2SessionQuestionReject({
    required String sessionID,
    required String requestID,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/api/session/$sessionID/question/request/$requestID/reject',
      queryParameters: {},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.post(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return;
  }


/// Reply to pending question request
///
/// Answer a pending question request owned by a session.
///
/// `operationId`: `v2.session.question.reply`
Future<void> v2SessionQuestionReply({
    required String sessionID,
    required String requestID,
    required QuestionV2Reply body,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/api/session/$sessionID/question/request/$requestID/reply',
      queryParameters: {},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body.toJson());
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return;
  }


/// Wait for v2 session
///
/// Wait for a v2 session agent loop to become idle.
///
/// `operationId`: `v2.session.wait`
Future<void> v2SessionWait({
    required String sessionID,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/api/session/$sessionID/wait',
      queryParameters: {},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.post(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return;
  }


/// List v2 skills
///
/// Retrieve currently registered v2 skills.
///
/// `operationId`: `v2.skill.list`
Future<dynamic> v2SkillList({
    Map<String, dynamic>? location,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/api/skill',
      queryParameters: {if (location != null) 'location': location.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// Apply VCS patch
///
/// Apply a raw patch to the current working tree.
///
/// `operationId`: `vcs.apply`
Future<dynamic> vcsApply({
    required Map<String, dynamic> body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/vcs/apply',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body);
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// Get VCS diff
///
/// Retrieve the current git diff for the working tree or against the default branch.
///
/// `operationId`: `vcs.diff`
Future<List<VcsFileDiff>> vcsDiff({
    String? directory,
    String? workspace,
    required String mode,
    int? context,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/vcs/diff',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString(), 'mode': mode.toString(), if (context != null) 'context': context.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as List<dynamic>;
    return decoded.map((e) => VcsFileDiff.fromJson(e as Map<String, dynamic>)).toList();
  }


/// Get raw VCS diff
///
/// Retrieve a raw patch for current uncommitted changes.
///
/// `operationId`: `vcs.diff.raw`
Future<dynamic> vcsDiffRaw({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/vcs/diff/raw',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return jsonDecode(resp.body) as dynamic;
  }


/// Get VCS info
///
/// Retrieve version control system (VCS) information for the current project, such as git branch.
///
/// `operationId`: `vcs.get`
Future<VcsInfo> vcsGet({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/vcs',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return VcsInfo.fromJson(decoded);
  }


/// Get VCS status
///
/// Retrieve changed files in the current working tree without patches.
///
/// `operationId`: `vcs.status`
Future<List<VcsFileStatus>> vcsStatus({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/vcs/status',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as List<dynamic>;
    return decoded.map((e) => VcsFileStatus.fromJson(e as Map<String, dynamic>)).toList();
  }


/// Create worktree
///
/// Create a new git worktree for the current project and run any configured startup scripts.
///
/// `operationId`: `worktree.create`
Future<Worktree> worktreeCreate({
    required WorktreeCreateInput body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/experimental/worktree',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body.toJson());
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return Worktree.fromJson(decoded);
  }


/// List worktrees
///
/// List all sandbox worktrees for the current project.
///
/// `operationId`: `worktree.list`
Future<List<String>> worktreeList({
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/experimental/worktree',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    final decoded = jsonDecode(resp.body) as List<dynamic>;
    return decoded.cast<String>();
  }


/// Remove worktree
///
/// Remove a git worktree and delete its branch.
///
/// `operationId`: `worktree.remove`
Future<bool> worktreeRemove({
    required WorktreeRemoveInput body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/experimental/worktree',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body.toJson());
    final http.Response resp = await _http.delete(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


/// Reset worktree
///
/// Reset a worktree branch to the primary default branch.
///
/// `operationId`: `worktree.reset`
Future<bool> worktreeReset({
    required WorktreeResetInput body,
    String? directory,
    String? workspace,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/experimental/worktree/reset',
      queryParameters: {if (directory != null) 'directory': directory.toString(), if (workspace != null) 'workspace': workspace.toString()},
    );
    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final encoded = jsonEncode(body.toJson());
    final http.Response resp = await _http.post(uri, headers: headers, body: encoded);
    if (resp.statusCode >= 400) {
      throw OpenCodeApiException(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    }
    return resp.body == "true";
  }


}

class OpenCodeApiException implements Exception {
  const OpenCodeApiException({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;

  @override
  String toString() => "OpenCodeApiException($statusCode): $body";
}
