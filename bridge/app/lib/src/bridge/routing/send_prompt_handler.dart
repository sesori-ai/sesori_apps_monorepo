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
    final sessionId = pathParams[_idParam];
    if (sessionId == null || sessionId.isEmpty) {
      return buildErrorResponse(request, 400, "missing session id");
    }

    final SendPromptRequest promptRequest;
    try {
      promptRequest = SendPromptRequest.fromJson(
        jsonDecode(request.body ?? "{}") as Map<String, dynamic>,
      );
    } on FormatException {
      return buildErrorResponse(request, 400, "invalid JSON body");
    } on Object {
      return buildErrorResponse(request, 400, "invalid JSON body");
    }

    final parts = promptRequest.parts
        .map(
          (p) => switch (p) {
            PromptPartText(:final text) => PluginPromptPart.text(text: text),
          },
        )
        .toList();

    final model = promptRequest.model;

    await _plugin.sendPrompt(
      sessionId: sessionId,
      parts: parts,
      agent: promptRequest.agent,
      providerID: model?.providerID,
      modelID: model?.modelID,
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
