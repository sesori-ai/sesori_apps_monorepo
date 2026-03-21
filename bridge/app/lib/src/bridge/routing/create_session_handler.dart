import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

/// Handles `POST /session` — creates a session for a given project.
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
    final CreateSessionRequest createRequest;
    try {
      createRequest = CreateSessionRequest.fromJson(
        jsonDecode(request.body ?? "{}") as Map<String, dynamic>,
      );
    } on FormatException {
      return buildErrorResponse(request, 400, "invalid JSON body");
    } on Object {
      return buildErrorResponse(request, 400, "invalid JSON body");
    }

    await _plugin.createSession(
      projectId: createRequest.projectId,
      sessionId: createRequest.id,
    );

    return RelayMessage.response(
          id: request.id,
          status: 200,
          headers: {},
          body: null,
        )
        as RelayResponse;
  }
}
