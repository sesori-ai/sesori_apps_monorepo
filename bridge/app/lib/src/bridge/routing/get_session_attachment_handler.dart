import "dart:convert";

import "package:sesori_shared/sesori_shared.dart";

import "../services/chat_history_service.dart";
import "request_handler.dart";

class GetSessionAttachmentHandler extends BodyRequestHandler<SessionAttachmentRequest, SessionAttachmentResponse> {
  final ChatHistoryService _chatHistoryService;

  GetSessionAttachmentHandler({required ChatHistoryService chatHistoryService})
    : _chatHistoryService = chatHistoryService,
      super(
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

    final result = await _chatHistoryService.getSessionAttachment(
      sessionId: body.sessionId,
      attachmentId: body.attachmentId,
      rendition: body.rendition,
    );
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
