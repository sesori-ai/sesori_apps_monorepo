import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "file_diff_mapper.dart";
import "request_handler.dart";

const _idParam = "id";
const _messageIdParam = "messageId";

/// Handles `GET /session/:id/message/:messageId/diff` — returns file diffs for a specific message.
class GetMessageDiffsHandler extends RequestHandler {
  final BridgePlugin _plugin;

  GetMessageDiffsHandler(this._plugin) : super(HttpMethod.get, "/session/:$_idParam/message/:$_messageIdParam/diff");

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

    final messageId = pathParams[_messageIdParam];
    if (messageId == null || messageId.isEmpty) {
      return buildErrorResponse(request, 400, "missing message id");
    }

    final pluginDiffs = await _plugin.getMessageDiffs(sessionId, messageId);
    final diffs = pluginDiffs.map(toFileDiff).toList();
    final body = jsonEncode(diffs.map((d) => d.toJson()).toList());
    return buildOkJsonResponse(request, body);
  }
}
