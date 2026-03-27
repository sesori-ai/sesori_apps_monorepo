import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "plugin_session_mapper.dart";
import "request_handler.dart";

/// Handles `PATCH /session/title` — renames a session.
class RenameSessionHandler extends RequestHandler {
  final BridgePlugin _plugin;

  RenameSessionHandler(this._plugin) : super(HttpMethod.patch, "/session/title");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    final RenameSessionRequest renameRequest;
    try {
      final decoded = jsonDecode(request.body ?? "{}");
      renameRequest = RenameSessionRequest.fromJson(
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

    final updated = await _plugin.renameSession(
      sessionId: renameRequest.sessionId,
      title: renameRequest.title,
    );

    final session = updated.toSharedSession();

    return buildOkJsonResponse(request, jsonEncode(session.toJson()));
  }
}
