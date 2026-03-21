import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

const _idParam = "id";

/// Handles `PATCH /session/:id` — updates archive status for a session.
class UpdateSessionArchiveStatusHandler extends RequestHandler {
  final BridgePlugin _plugin;

  UpdateSessionArchiveStatusHandler(this._plugin) : super(HttpMethod.patch, "/session/:$_idParam");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    final sessionId = pathParams[_idParam]!;

    int? archived;
    try {
      final body = jsonDecode(request.body ?? "{}") as Map<String, dynamic>;
      final time = body["time"] as Map<String, dynamic>?;
      if (time == null || !time.containsKey("archived")) {
        return buildErrorResponse(request, 400, "missing time.archived in body");
      }

      archived = time["archived"] as int?;
    } on FormatException {
      return buildErrorResponse(request, 400, "invalid JSON body");
    } on Exception {
      return buildErrorResponse(request, 400, "invalid JSON body");
    }

    final updated = await _plugin.updateSessionArchiveStatus(
      sessionId,
      archivedAt: archived,
    );

    final session = Session(
      id: updated.id,
      projectID: updated.projectID,
      directory: updated.directory,
      parentID: updated.parentID,
      title: updated.title,
      time: switch (updated.time) {
        PluginSessionTime(:final created, :final updated, :final archived) => SessionTime(
          created: created,
          updated: updated,
          archived: archived,
        ),
        null => null,
      },
      summary: switch (updated.summary) {
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
