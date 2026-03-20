import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

const _idParam = "id";

/// Handles `GET /session/:id/children` — returns direct child sessions.
class GetChildSessionsHandler extends RequestHandler {
  final BridgePlugin _plugin;

  GetChildSessionsHandler(this._plugin) : super(HttpMethod.get, "/session/:$_idParam/children");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    final sessionId = pathParams[_idParam]!;
    final pluginSessions = await _plugin.getChildSessions(sessionId);

    final sessions = pluginSessions
        .map(
          (s) => Session(
            id: s.id,
            projectID: s.projectID,
            directory: s.directory,
            parentID: s.parentID,
            title: s.title,
            time: switch (s.time) {
              PluginSessionTime(:final created, :final updated, :final archived) => SessionTime(
                created: created,
                updated: updated,
                archived: archived,
              ),
              null => null,
            },
            summary: switch (s.summary) {
              PluginSessionSummary(:final additions, :final deletions, :final files) => SessionSummary(
                additions: additions,
                deletions: deletions,
                files: files,
              ),
              null => null,
            },
          ),
        )
        .toList();

    return buildOkJsonResponse(
      request,
      jsonEncode(sessions.map((s) => s.toJson()).toList()),
    );
  }
}
