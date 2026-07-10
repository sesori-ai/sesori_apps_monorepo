import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";
import "session_title_service.dart";

/// Prepares raw plugin session events for delivery: first syncs stored state
/// the backend won't hold (the bridge's title copy for derived-plugin
/// sessions), then overlays the stored enrichment onto the wire payload —
/// so the payload phones receive and the next REST enumeration agree.
class SessionEventEnrichmentService {
  final SessionRepository _sessionRepository;
  final SessionTitleService _sessionTitleService;
  final FailureReporter _failureReporter;

  SessionEventEnrichmentService({
    required SessionRepository sessionRepository,
    required SessionTitleService sessionTitleService,
    required FailureReporter failureReporter,
  }) : _sessionRepository = sessionRepository,
       _sessionTitleService = sessionTitleService,
       _failureReporter = failureReporter;

  Future<BridgeSseEvent?> enrich(BridgeSseEvent event) async {
    try {
      final sessionId = _sessionId(event);
      if (sessionId != null && await _sessionRepository.isSessionTombstoned(sessionId: sessionId)) {
        return null;
      }
      return switch (event) {
        BridgeSseSessionCreated(:final info) => BridgeSseSessionCreated(
          info: (await _sessionRepository.enrichSessionJson(sessionJson: info)).toJson(),
        ),
        BridgeSseSessionUpdated(:final info, :final titleChanged) => BridgeSseSessionUpdated(
          info: (await _captureTitleAndEnrich(info: info, titleChanged: titleChanged)).toJson(),
          titleChanged: titleChanged,
        ),
        BridgeSseSessionsUpdated(:final sessionID, :final projectID) => BridgeSseSessionsUpdated(
          sessionID: sessionID,
          projectID:
              await _sessionRepository.findProjectIdForSession(sessionId: sessionID) ?? projectID,
        ),
        _ => event,
      };
    } catch (e, st) {
      Log.w("[sse] failed to enrich ${event.runtimeType}: $e");
      try {
        await _failureReporter.recordFailure(
          error: e,
          stackTrace: st,
          uniqueIdentifier: "bridge.sse.enrichment",
          fatal: false,
          reason: "failed to enrich plugin SSE event",
          information: [event.runtimeType],
        );
      } catch (reportError, reportStackTrace) {
        Log.w("[sse] failed to report enrichment failure: $reportError\n$reportStackTrace");
      }
      return event;
    }
  }

  /// A `session.updated` from a derived backend is its own rename signal (ACP's
  /// `session_info_update` — where an explicit null deliberately clears the
  /// title — and codex's `thread/name/updated`). Persist the title BEFORE
  /// enriching, so the stored-wins overlay serves the new value both on this
  /// very event and on every later enumeration. `session.created` events are
  /// deliberately not captured: their null title means "unknown", not
  /// "cleared".
  Future<Session> _captureTitleAndEnrich({
    required Map<String, dynamic> info,
    required bool titleChanged,
  }) async {
    final session = Session.fromJson(info);
    if (titleChanged) {
      await _sessionTitleService.captureTitle(sessionId: session.id, title: session.title);
    }
    return _sessionRepository.enrichSession(session: session);
  }

  String? _sessionId(BridgeSseEvent event) {
    return switch (event) {
      BridgeSseSessionCreated(:final info) ||
      BridgeSseSessionUpdated(:final info) ||
      BridgeSseSessionDeleted(:final info) => info["id"] is String ? info["id"] as String : null,
      BridgeSseMessageUpdated(:final info) =>
        info["sessionID"] is String ? info["sessionID"] as String : null,
      BridgeSseMessagePartUpdated(:final part) => part.sessionID,
      BridgeSseSessionsUpdated(:final sessionID) ||
      BridgeSseSessionDiff(:final sessionID) ||
      BridgeSseSessionCompacted(:final sessionID) ||
      BridgeSseSessionStatus(:final sessionID) ||
      BridgeSseSessionIdle(:final sessionID) ||
      BridgeSseCommandExecuted(:final sessionID) ||
      BridgeSseMessageRemoved(:final sessionID) ||
      BridgeSseMessagePartDelta(:final sessionID) ||
      BridgeSseMessagePartRemoved(:final sessionID) ||
      BridgeSsePermissionAsked(:final sessionID) ||
      BridgeSsePermissionReplied(:final sessionID) ||
      BridgeSseQuestionAsked(:final sessionID) ||
      BridgeSseQuestionReplied(:final sessionID) ||
      BridgeSseQuestionRejected(:final sessionID) ||
      BridgeSseTodoUpdated(:final sessionID) => sessionID,
      BridgeSseSessionError(:final sessionID) => sessionID,
      BridgeSseServerConnected() ||
      BridgeSseServerHeartbeat() ||
      BridgeSseServerInstanceDisposed() ||
      BridgeSseGlobalDisposed() ||
      BridgeSsePtyCreated() ||
      BridgeSsePtyUpdated() ||
      BridgeSsePtyExited() ||
      BridgeSsePtyDeleted() ||
      BridgeSsePermissionUpdated() ||
      BridgeSseProjectUpdated() ||
      BridgeSseVcsBranchUpdated() ||
      BridgeSseFileEdited() ||
      BridgeSseFileWatcherUpdated() ||
      BridgeSseLspUpdated() ||
      BridgeSseLspClientDiagnostics() ||
      BridgeSseMcpToolsChanged() ||
      BridgeSseMcpBrowserOpenFailed() ||
      BridgeSseInstallationUpdated() ||
      BridgeSseInstallationUpdateAvailable() ||
      BridgeSseWorkspaceReady() ||
      BridgeSseWorkspaceFailed() ||
      BridgeSseTuiToastShow() ||
      BridgeSseWorktreeReady() ||
      BridgeSseWorktreeFailed() => null,
    };
  }
}
