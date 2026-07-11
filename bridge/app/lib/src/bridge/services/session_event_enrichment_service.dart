import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";
import "session_mutation_dispatcher.dart";

/// Prepares raw plugin session events for delivery: first syncs stored state
/// the backend won't hold (the bridge's title copy for derived-plugin
/// sessions), then overlays the stored enrichment onto the wire payload —
/// so the payload phones receive and the next REST enumeration agree.
class SessionEventEnrichmentService {
  final SessionRepository _sessionRepository;
  final SessionMutationDispatcher _sessionMutationDispatcher;
  final FailureReporter _failureReporter;

  SessionEventEnrichmentService({
    required SessionRepository sessionRepository,
    required SessionMutationDispatcher sessionMutationDispatcher,
    required FailureReporter failureReporter,
  }) : _sessionRepository = sessionRepository,
       _sessionMutationDispatcher = sessionMutationDispatcher,
       _failureReporter = failureReporter;

  Future<BridgeSseEvent?> enrich(BridgeSseEvent event) async {
    try {
      for (final sessionId in _sessionIds(event)) {
        if (await _sessionRepository.isSessionTombstoned(sessionId: sessionId)) return null;
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
          projectID: await _sessionRepository.findProjectIdForSession(sessionId: sessionID) ?? projectID,
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

  /// A title-changing `session.updated` from a derived backend is its own rename
  /// signal. Persist the title BEFORE
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
      await _sessionMutationDispatcher.captureTitle(sessionId: session.id, title: session.title);
    }
    return _sessionRepository.enrichSession(session: session);
  }

  List<String> _sessionIds(BridgeSseEvent event) {
    return switch (event) {
      BridgeSseSessionCreated(:final info) ||
      BridgeSseSessionUpdated(:final info) => [if (info["id"] case final String id) id],
      BridgeSseMessageUpdated(:final info) => [
        if (info["sessionID"] case final String sessionId) sessionId,
      ],
      BridgeSseMessagePartUpdated(:final part) => [part.sessionID],
      BridgeSsePermissionAsked(:final sessionID, :final displaySessionId) ||
      BridgeSsePermissionReplied(:final sessionID, :final displaySessionId) ||
      BridgeSseQuestionAsked(:final sessionID, :final displaySessionId) ||
      BridgeSseQuestionReplied(:final sessionID, :final displaySessionId) ||
      BridgeSseQuestionRejected(:final sessionID, :final displaySessionId) => [
        sessionID,
        ?displaySessionId,
      ],
      BridgeSseSessionsUpdated(:final sessionID) ||
      BridgeSseSessionDiff(:final sessionID) ||
      BridgeSseSessionCompacted(:final sessionID) ||
      BridgeSseSessionStatus(:final sessionID) ||
      BridgeSseSessionIdle(:final sessionID) ||
      BridgeSseCommandExecuted(:final sessionID) ||
      BridgeSseMessageRemoved(:final sessionID) ||
      BridgeSseMessagePartDelta(:final sessionID) ||
      BridgeSseMessagePartRemoved(:final sessionID) ||
      BridgeSseTodoUpdated(:final sessionID) => [sessionID],
      BridgeSseSessionError(:final sessionID) => [?sessionID],
      BridgeSseServerConnected() ||
      BridgeSseServerHeartbeat() ||
      BridgeSseServerInstanceDisposed() ||
      BridgeSseGlobalDisposed() ||
      BridgeSseSessionDeleted() ||
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
      BridgeSseWorktreeFailed() => const [],
    };
  }
}
