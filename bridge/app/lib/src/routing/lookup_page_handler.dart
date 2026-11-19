import "package:sesori_shared/sesori_shared.dart";

import "../services/agent_page_service.dart";
import "request_handler.dart";

/// Handles `POST /page` — opens a page an agent sent, pending or settled, on
/// its own session or the root session it shows on.
class LookupPageHandler({required final AgentPageService _agentPageService})
    extends BodyRequestHandler<PageLookupRequest, PageLookupResponse> {
  this
    : super(
        method: HttpMethod.post,
        path: "/page",
        fromJson: PageLookupRequest.fromJson,
      );

  @override
  Future<PageLookupResponse> handle({
    required RelayRequest request,
    required PageLookupRequest body,
  }) {
    requireNonEmpty(request: request, value: body.sessionId, label: "session id");
    requireNonEmpty(request: request, value: body.requestId, label: "request id");
    return _agentPageService.lookup(sessionId: body.sessionId, requestId: body.requestId);
  }
}
