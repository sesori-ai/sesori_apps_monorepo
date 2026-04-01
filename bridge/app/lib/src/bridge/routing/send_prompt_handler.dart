import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "prompt_part_mapper.dart";
import "request_handler.dart";

/// Handles `POST /session/prompt_async` — sends a prompt to a session.
class SendPromptHandler extends BodyRequestHandler<SendPromptRequest, SuccessEmptyResponse> {
  final BridgePlugin _plugin;

  SendPromptHandler(this._plugin)
    : super(
        HttpMethod.post,
        "/session/prompt_async",
        fromJson: SendPromptRequest.fromJson,
      );

  @override
  Future<SuccessEmptyResponse> handle(
    RelayRequest request, {
    required SendPromptRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final sessionId = body.sessionId;
    if (sessionId.isEmpty) {
      throw buildErrorResponse(request, 400, "empty session id");
    }

    final parts = body.parts.map((p) => p.toPlugin()).toList();

    final model = switch (body.model) {
      PromptModel(:final providerID, :final modelID) => (providerID: providerID, modelID: modelID),
      null => null,
    };

    await _plugin.sendPrompt(
      sessionId: sessionId,
      parts: parts,
      agent: body.agent,
      model: model,
    );

    return const SuccessEmptyResponse();
  }
}
