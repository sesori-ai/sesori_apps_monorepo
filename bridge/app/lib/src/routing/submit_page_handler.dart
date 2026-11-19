import "package:sesori_shared/sesori_shared.dart";

import "../services/agent_page_service.dart";
import "request_handler.dart";

/// Handles `POST /page/submit` — settles a page an agent sent with the user's
/// answers. The first submit wins; an archived session's page is refused.
class SubmitPageHandler({required final AgentPageService _agentPageService})
    extends BodyRequestHandler<SubmitPageRequest, PageSubmitResult> {
  this
    : super(
        method: HttpMethod.post,
        path: "/page/submit",
        fromJson: SubmitPageRequest.fromJson,
      );

  @override
  Future<PageSubmitResult> handle({
    required RelayRequest request,
    required SubmitPageRequest body,
  }) async {
    requireNonEmpty(request: request, value: body.requestId, label: "request id");
    requireNonEmpty(request: request, value: body.sessionId, label: "session id");
    return switch (await _agentPageService.submit(request: body)) {
      final result? => result,
      null => throw buildErrorResponse(request: request, status: 404, message: "Page not found."),
    };
  }
}
