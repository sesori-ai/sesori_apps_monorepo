import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/mappers/plugin_message_mapper.dart";
import "request_handler.dart";

/// Handles `POST /session/messages` — returns all messages for a session.
class GetSessionMessagesHandler extends BodyRequestHandler<SessionIdRequest, MessageWithPartsResponse> {
  final BridgePlugin _plugin;

  GetSessionMessagesHandler(this._plugin)
    : super(
        HttpMethod.post,
        "/session/messages",
        fromJson: SessionIdRequest.fromJson,
      );

  @override
  Future<MessageWithPartsResponse> handle(
    RelayRequest request, {
    required SessionIdRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final sessionId = body.sessionId;
    if (sessionId.isEmpty) {
      throw buildErrorResponse(request, 400, "empty session id");
    }

    final pluginMessages = await _plugin.getSessionMessages(sessionId);

    return MessageWithPartsResponse(
      messages: pluginMessages.toSharedMessageWithParts(),
    );
  }
}
