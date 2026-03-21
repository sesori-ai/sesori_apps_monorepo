import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

/// Handles `GET /session` — returns sessions for a given project.
///
/// Requires `projectId` query parameter. Supports `start` and `limit`
/// query parameters for pagination.
class GetSessionsHandler extends RequestHandler {
  final BridgePlugin _plugin;

  GetSessionsHandler(this._plugin) : super(HttpMethod.get, "/session");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    final projectId = queryParams["projectId"];
    if (projectId == null || projectId.isEmpty) {
      return buildErrorResponse(
        request,
        400,
        "missing projectId query parameter",
      );
    }

    final start = queryParams["start"] != null ? int.tryParse(queryParams["start"]!) : null;
    final limit = queryParams["limit"] != null ? int.tryParse(queryParams["limit"]!) : null;

    final pluginSessions = await _plugin.getSessions(
      projectId,
      start: start,
      limit: limit,
    );

    final sessions = pluginSessions
        .map(
          (s) => Session(
            id: s.id,
            projectID: s.projectID,
            directory: s.directory,
            parentID: s.parentID,
            title: s.title,
            time: switch (s.time) {
              PluginSessionTime(
                :final created,
                :final updated,
                :final archived,
              ) =>
                SessionTime(
                  created: created,
                  updated: updated,
                  archived: archived,
                ),
              null => null,
            },
            summary: switch (s.summary) {
              PluginSessionSummary(
                :final additions,
                :final deletions,
                :final files,
              ) =>
                SessionSummary(
                  additions: additions,
                  deletions: deletions,
                  files: files,
                ),
              null => null,
            },
          ),
        )
        .toList();

    final body = jsonEncode(sessions.map((s) => s.toJson()).toList());
    return buildOkJsonResponse(request, body);
  }
}
