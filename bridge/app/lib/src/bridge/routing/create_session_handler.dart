import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../worktree_service.dart";
import "request_handler.dart";

/// Handles `POST /session` — creates a session for a given project.
class CreateSessionHandler extends RequestHandler {
  final BridgePlugin _plugin;
  final WorktreeService _worktreeService;

  CreateSessionHandler({
    required BridgePlugin plugin,
    required WorktreeService worktreeService,
  }) : _plugin = plugin,
       _worktreeService = worktreeService,
       super(HttpMethod.post, "/session");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    final CreateSessionRequest createRequest;
    try {
      final decoded = jsonDecode(request.body ?? "{}");
      createRequest = CreateSessionRequest.fromJson(
        switch (decoded) {
          final Map<String, dynamic> map => map,
          _ => throw const FormatException("invalid JSON body"),
        },
      );
    } on FormatException {
      return buildErrorResponse(request, 400, "invalid JSON body");
    } on Object {
      return buildErrorResponse(request, 400, "invalid JSON body");
    }

    final projectId = createRequest.projectId;
    final parentSessionId = createRequest.parentSessionId;

    final worktreeResult = await _worktreeService.prepareWorktreeForSession(
      projectId: projectId,
      parentSessionId: parentSessionId,
    );

    final created = await _plugin.createSession(
      directory: switch (worktreeResult) {
        WorktreeSuccess(:final path) => path,
        WorktreeFallback(:final originalPath) => originalPath,
      },
      parentSessionId: parentSessionId,
    );

    if (worktreeResult case WorktreeSuccess(:final path, :final branchName)) {
      await _worktreeService.recordSessionWorktree(
        sessionId: created.id,
        projectId: projectId,
        worktreePath: path,
        branchName: branchName,
      );
    }

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
