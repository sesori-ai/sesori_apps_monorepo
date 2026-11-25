import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginOperationException;
import "package:sesori_tool_interface/sesori_tool_interface.dart";

import "../../repositories/bridge_settings_repository.dart";
import "../../repositories/models/session_notice.dart";
import "../../repositories/models/session_operation.dart";
import "../../repositories/session_repository.dart";
import "../../services/session_notice_service.dart";
import "../../services/tool_group_approval_service.dart";

/// One tool group's [SesoriToolHost]: its [store], toggle, notices,
/// sessions and approvals, all scoped to [_groupId].
class BridgeSesoriToolHostImpl({
  required final SesoriToolGroupId _groupId,
  required final SesoriToolStore _store,
  required final SessionNoticeService _notices,
  required final SessionRepository _sessions,
  required final BridgeSettingsRepository _settings,
  required final ToolGroupApprovalService _approvals,
}) implements SesoriToolHost {
  @override
  SesoriToolStore get store => _store;

  @override
  bool get enabled => _settings.currentSettings.toolGroupEnabled(id: _groupId);

  @override
  Stream<bool> get enabledChanges => _settings.settingsChanges
      .map(
        (change) => (
          was: change.previous.toolGroupEnabled(id: _groupId),
          now: change.current.toolGroupEnabled(id: _groupId),
        ),
      )
      .where((toggle) => toggle.was != toggle.now)
      .map((toggle) => toggle.now);

  @override
  Future<SesoriToolNoticeOutcome> deliverNotice({
    required String sessionId,
    required String summary,
    required String guidance,
    required SesoriToolNoticeTiming timing,
    required Future<bool> Function()? claim,
  }) async {
    final outcome = await _notices.deliver(
      sessionId: sessionId,
      notice: SessionNotice(summary: summary, guidance: guidance, pageRequestId: null),
      timing: switch (timing) {
        SesoriToolNoticeTiming.derived => SessionNoticeTiming.derived,
        SesoriToolNoticeTiming.afterTurn => SessionNoticeTiming.afterTurn,
      },
      claim: claim,
    );
    return switch (outcome) {
      SessionNoticeOutcome.sent => SesoriToolNoticeOutcome.sent,
      SessionNoticeOutcome.skippedInactive => SesoriToolNoticeOutcome.skippedInactive,
      SessionNoticeOutcome.claimLost => SesoriToolNoticeOutcome.claimLost,
      SessionNoticeOutcome.dropped => SesoriToolNoticeOutcome.dropped,
    };
  }

  @override
  Future<Map<String, SesoriToolSession>> sessions({required Set<String> sessionIds}) async {
    final found = <String, SesoriToolSession>{};
    for (final sessionId in sessionIds) {
      final session = await _sessions.getStoredSession(sessionId: sessionId);
      if (session == null) continue;
      final String rootSessionId;
      try {
        rootSessionId = (await _sessions.resolveSessionFamily(
          sessionId: sessionId,
          operation: SessionOperation.lookUpToolSessions,
        )).rootSessionId;
      } on PluginOperationException catch (error, stackTrace) {
        // Deleted between the two reads, or with broken ancestry: either way
        // it is no longer a session a group can act for.
        Log.w("Left session $sessionId out of a ${_groupId.value} session lookup", error, stackTrace);
        continue;
      }
      found[sessionId] = SesoriToolSession(
        rootSessionId: rootSessionId,
        workingDirectory: session.worktreePath ?? session.directory,
        archived: session.archivedAt != null,
      );
    }
    return found;
  }

  @override
  Future<SesoriToolApprovalOutcome> requestApproval({
    required String sessionId,
    required String title,
    required String body,
  }) => _approvals.request(groupId: _groupId, sessionId: sessionId, title: title, body: body);
}
