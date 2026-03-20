import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

const _idParam = "id";

/// Handles `POST /session/:id/prompt_async` — sends a prompt to a session.
class SendPromptHandler extends RequestHandler {
  final BridgePlugin _plugin;

  SendPromptHandler(this._plugin) : super(HttpMethod.post, "/session/:$_idParam/prompt_async");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    final sessionId = pathParams[_idParam]!;

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(request.body ?? "{}") as Map<String, dynamic>;
    } on FormatException {
      return buildErrorResponse(request, 400, "invalid JSON body");
    } on Exception {
      return buildErrorResponse(request, 400, "invalid JSON body");
    }

    final partsJson = (body["parts"] as List<dynamic>? ?? const <dynamic>[]).cast<Map<String, dynamic>>();
    final parts = partsJson
        .map(
          (p) => PluginPromptPart(
            type: p["type"] as String,
            text: p["text"] as String?,
          ),
        )
        .toList();

    final model = body["model"] as Map<String, dynamic>?;

    await _plugin.sendPrompt(
      sessionId: sessionId,
      parts: parts,
      agent: body["agent"] as String?,
      providerID: model?["providerID"] as String?,
      modelID: model?["modelID"] as String?,
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
