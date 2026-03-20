import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

/// Handles `POST /session` — creates a session for a given worktree.
class CreateSessionHandler extends RequestHandler {
  final BridgePlugin _plugin;

  CreateSessionHandler(this._plugin) : super(HttpMethod.post, "/session");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    final worktree = findHeader(request.headers, "x-opencode-directory");
    if (worktree == null || worktree.isEmpty) {
      return buildErrorResponse(request, 400, "missing x-opencode-directory header");
    }

    final created = await _plugin.createSession(worktree);
    final session = Session(
      id: created.id,
      projectID: created.projectID,
      directory: created.directory,
      parentID: created.parentID,
      title: created.title,
      time: switch (created.time) {
        PluginSessionTime(:final created, :final updated, :final archived) => SessionTime(
          created: created,
          updated: updated,
          archived: archived,
        ),
        null => null,
      },
      summary: switch (created.summary) {
        PluginSessionSummary(:final additions, :final deletions, :final files) => SessionSummary(
          additions: additions,
          deletions: deletions,
          files: files,
        ),
        null => null,
      },
    );

    return buildOkJsonResponse(request, jsonEncode(session.toJson()));
  }
}
