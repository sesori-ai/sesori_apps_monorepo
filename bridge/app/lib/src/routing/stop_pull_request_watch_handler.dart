import "package:sesori_shared/sesori_shared.dart";
import "package:sesori_tool_pr_monitor/sesori_tool_pr_monitor.dart";

import "../services/session_view_service.dart";
import "request_handler.dart";

/// Handles `POST /session/pull-request-watch/stop`: the user stops one of a
/// root session's PR watches, a merged one included, and gets the updated
/// session back. The agent is not told. A watch that already ended answers
/// the same way; a missing session answers not found.
class StopPullRequestWatchHandler({
  required final PullRequestWatchService _watches,
  required final SessionViewService _sessionViews,
}) extends BodyRequestHandler<StopPullRequestWatchRequest, Session> {
  this
    : super(
        method: HttpMethod.post,
        path: "/session/pull-request-watch/stop",
        fromJson: StopPullRequestWatchRequest.fromJson,
      );

  @override
  Future<Session> handle({required RelayRequest request, required StopPullRequestWatchRequest body}) async {
    requireNonEmpty(request: request, value: body.sessionId, label: "session id");
    await _watches.unwatch(
      sessionId: body.sessionId,
      target: _target(request: request, repository: body.repository, number: body.number),
    );
    return await _sessionViews.get(sessionId: body.sessionId);
  }

  /// The PR the request names as `owner/repo` and a number, or a 400.
  PullRequestTarget _target({required RelayRequest request, required String repository, required int number}) {
    try {
      return PullRequestTarget.parse(input: "$repository#$number");
    } on FormatException {
      throw buildErrorResponse(request: request, status: 400, message: "invalid pull request $repository#$number");
    }
  }
}
