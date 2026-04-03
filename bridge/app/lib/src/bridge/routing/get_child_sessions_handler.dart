import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../persistence/dao_interfaces.dart";
import "plugin_session_mapper.dart";
import "pr_enum_helpers.dart";
import "request_handler.dart";

/// Handles `GET /session/:id/children` — returns direct child sessions.
class GetChildSessionsHandler extends BodyRequestHandler<SessionIdRequest, SessionListResponse> {
  final BridgePlugin _plugin;
  final PullRequestDaoLike _prDao;

  GetChildSessionsHandler(this._plugin, this._prDao)
    : super(
        HttpMethod.post,
        "/session/children",
        fromJson: SessionIdRequest.fromJson,
      );

  @override
  Future<SessionListResponse> handle(
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

    final pluginSessions = await _plugin.getChildSessions(sessionId);

    final sessions = pluginSessions.map((s) => s.toSharedSession()).toList();
    final sessionIds = sessions.map((s) => s.id).toList();
    final prsBySessionId = await _prDao.getPrsBySessionIds(sessionIds: sessionIds);

    final mergedSessions = sessions.map((session) {
      final pr = prsBySessionId[session.id];
      if (pr == null) {
        return session;
      }
      return session.copyWith(
        pullRequest: PullRequestInfo(
          number: pr.prNumber,
          url: pr.url,
          title: pr.title,
          state: stringToPrState(pr.state),
          mergeableStatus: stringToPrMergeableStatus(pr.mergeableStatus),
          reviewDecision: stringToPrReviewDecision(pr.reviewDecision),
          checkStatus: stringToPrCheckStatus(pr.checkStatus),
        ),
      );
    }).toList();

    return SessionListResponse(items: mergedSessions);
  }
}
