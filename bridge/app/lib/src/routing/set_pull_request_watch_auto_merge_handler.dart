import "package:sesori_shared/sesori_shared.dart";
import "package:sesori_tool_pr_monitor/sesori_tool_pr_monitor.dart";

import "../services/session_view_service.dart";
import "request_handler.dart";

/// Handles `POST /session/pull-request-watch/auto-merge`: the user turns
/// auto-merge on or off for one of a root session's PR watches, with no
/// Allow since it is their own per-PR choice, and gets the updated session
/// back. The agent is not told. A watch that already ended answers the same
/// way; a missing session answers not found.
class SetPullRequestWatchAutoMergeHandler({
  required final PullRequestWatchService _watches,
  required final SessionViewService _sessionViews,
}) extends BodyRequestHandler<SetPullRequestWatchAutoMergeRequest, Session> {
  this
    : super(
        method: HttpMethod.post,
        path: "/session/pull-request-watch/auto-merge",
        fromJson: SetPullRequestWatchAutoMergeRequest.fromJson,
      );

  @override
  Future<Session> handle({required RelayRequest request, required SetPullRequestWatchAutoMergeRequest body}) async {
    requireNonEmpty(request: request, value: body.sessionId, label: "session id");
    await _watches.setAutoMerge(
      sessionId: body.sessionId,
      target: _target(request: request, repository: body.repository, number: body.number),
      enabled: body.enabled,
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
