import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/tool_output_lookup.dart";
import "../services/chat_history_service.dart";
import "request_handler.dart";

/// Handles `POST /session/tool-output` — returns the output and error that a
/// page's summary tool part withheld. Answers 404 when the part is missing or
/// is not a tool.
class GetSessionToolOutputHandler({required final ChatHistoryService _chatHistoryService})
    extends BodyRequestHandler<SessionToolOutputRequest, SessionToolOutputResponse> {
  this
    : super(
        HttpMethod.post,
        "/session/tool-output",
        fromJson: SessionToolOutputRequest.fromJson,
      );

  @override
  Future<SessionToolOutputResponse> handle(
    RelayRequest request, {
    required SessionToolOutputRequest body,
  }) async {
    requireNonEmpty(request: request, value: body.sessionId, label: "session id");
    requireNonEmpty(request: request, value: body.messageId, label: "message id");
    requireNonEmpty(request: request, value: body.partId, label: "part id");
    final lookup = await _chatHistoryService.getToolOutput(
      sessionId: body.sessionId,
      messageId: body.messageId,
      partId: body.partId,
    );
    return switch (lookup) {
      ToolOutputFound(:final output, :final error) => SessionToolOutputResponse(output: output, error: error),
      ToolOutputMissing() => throw buildErrorResponse(request, 404, "tool part not found"),
    };
  }
}
