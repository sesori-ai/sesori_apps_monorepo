import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "file_diff_mapper.dart";
import "request_handler.dart";

const _idParam = "id";

/// Handles `GET /session/:id/diff` — returns file diffs for a session.
class GetSessionDiffsHandler extends RequestHandler {
  final BridgePlugin _plugin;

  GetSessionDiffsHandler(this._plugin) : super(HttpMethod.get, "/session/:$_idParam/diff");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    final sessionId = pathParams[_idParam];
    if (sessionId == null || sessionId.isEmpty) {
      return buildErrorResponse(request, 400, "missing session id");
    }

    final pluginDiffs = await _plugin.getSessionDiffs(sessionId);
    final diffs = pluginDiffs.map(toFileDiff).toList();
    final body = jsonEncode(diffs.map((d) => d.toJson()).toList());
    return buildOkJsonResponse(request, body);
  }
}
