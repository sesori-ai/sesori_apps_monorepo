import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "plugin_session_mapper.dart";
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
    final sessionId = pathParams[_idParam];
    if (sessionId == null || sessionId.isEmpty) {
      return buildErrorResponse(request, 400, "missing session id");
    }

    final UpdateSessionArchiveRequest archiveRequest;
    try {
      archiveRequest = UpdateSessionArchiveRequest.fromJson(
        jsonDecode(request.body ?? "{}") as Map<String, dynamic>,
      );
    } on FormatException {
      return buildErrorResponse(request, 400, "invalid JSON body");
    } on Object {
      return buildErrorResponse(request, 400, "invalid JSON body");
    }

    final updated = await _plugin.updateSessionArchiveStatus(
      sessionId,
      archived: archiveRequest.archived,
    );

    final session = updated.toSharedSession();

    return buildOkJsonResponse(request, jsonEncode(session.toJson()));
  }
}
