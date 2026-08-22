import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../services/chat_history_service.dart";
import "request_handler.dart";

class GetSessionAttachmentHandler({required final ChatHistoryService _chatHistoryService})
    extends BodyRequestHandler<SessionAttachmentRequest, SessionAttachmentResponse> {
  this
    : super(
        HttpMethod.post,
        "/session/attachment",
        fromJson: SessionAttachmentRequest.fromJson,
      );

  @override
  Future<SessionAttachmentResponse> handle(
    RelayRequest request, {
    required SessionAttachmentRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    if (body.sessionId.isEmpty) {
      throw buildErrorResponse(request, 400, "empty session id");
    }
    if (body.attachmentId.isEmpty) {
      throw buildErrorResponse(request, 400, "empty attachment id");
    }

    final SessionAttachmentResult result;
    try {
      result = await _chatHistoryService.getSessionAttachment(
        sessionId: body.sessionId,
        attachmentId: body.attachmentId,
        rendition: body.rendition,
      );
    } on Object catch (error, stackTrace) {
      Log.w("Failed to read session attachment rendition", error, stackTrace);
      throw buildErrorResponse(request, 500, "attachment rendition unavailable");
    }
    return switch (result) {
      SessionAttachmentFound(:final bytes, :final mime) => SessionAttachmentResponse(
        mime: mime,
        base64: base64Encode(bytes),
        byteLength: bytes.length,
      ),
      SessionAttachmentMissing() => throw buildErrorResponse(request, 404, "attachment not found"),
      SessionAttachmentUnsupported() => throw buildErrorResponse(request, 422, "attachment rendition unsupported"),
      SessionAttachmentTooLarge() => throw buildErrorResponse(request, 413, "attachment too large"),
    };
  }
}
