import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

/// Handles `POST /session/:id/command` — executes a slash command in a session.
class SendCommandHandler extends BodyRequestHandler<SendCommandRequest, SuccessEmptyResponse> {
  final BridgePlugin _plugin;

  SendCommandHandler(this._plugin)
    : super(
        HttpMethod.post,
        "/session/:id/command",
        fromJson: SendCommandRequest.fromJson,
      );

  @override
  Future<SuccessEmptyResponse> handle(
    RelayRequest request, {
    required SendCommandRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final sessionId = pathParams["id"] ?? "";
    if (sessionId.isEmpty) {
      throw buildErrorResponse(request, 400, "empty session id");
    }
    if (body.command.trim().isEmpty) {
      throw buildErrorResponse(request, 400, "empty command");
    }

    await _plugin.sendCommand(
      sessionId: sessionId,
      command: body.command,
      arguments: body.arguments,
    );

    return const SuccessEmptyResponse();
  }
}
