import "dart:async";

import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/connection_status.dart";
import "../capabilities/server_connection/models/sse_event.dart";
import "../logging/logging.dart";
import "models/session_activity_info.dart";

@lazySingleton
class SseEventTracker with Disposable {
  final ConnectionService _connectionService;
  final FailureReporter _failureReporter;
  late final StreamSubscription<SseEvent> _eventSubscription;
  late final StreamSubscription<ConnectionStatus> _connectionStatusSubscription;

  final BehaviorSubject<Map<String, int>> _projectActivity = BehaviorSubject.seeded(const {});

  /// Map of project ID -> (session ID -> activity info).
  final BehaviorSubject<Map<String, Map<String, SessionActivityInfo>>> _sessionActivity = BehaviorSubject.seeded(
    const {},
  );
  bool _userInteractionOrdered = false;

  /// Map of project ID -> latest updated timestamp from complete
  /// [SesoriProjectUpdated] events seen for every project.
  ///
  /// Only emits complete updates where both the project ID and the activity
  /// time are non-null. Incomplete events are ignored so the stream does not
  /// advance with stale or partial data.
  final BehaviorSubject<Map<String, int>> _projectTimestampUpdates = BehaviorSubject.seeded(const {});

  SseEventTracker(
    ConnectionService connectionService, {
    required FailureReporter failureReporter,
  }) : _connectionService = connectionService,
       _failureReporter = failureReporter {
    _eventSubscription = _connectionService.events.listen(_handleEvent);
    _connectionStatusSubscription = _connectionService.status.listen(_handleConnectionStatus);
  }

  /// Map of project ID -> active session count.
  ///
  /// Only includes projects with active sessions (root sessions only).
  /// Late subscribers immediately receive the latest cached value.
  ValueStream<Map<String, int>> get projectActivity => _projectActivity.stream;

  /// The latest project activity map, synchronously available.
  Map<String, int> get currentProjectActivity => _projectActivity.value;

  /// Map of project ID -> (session ID -> activity info).
  ///
  /// Each entry describes a root session that is currently active — either
  /// because its main agent is running, or because it has active child tasks,
  /// or both. Only includes projects with active sessions.
  /// Late subscribers immediately receive the latest cached value.
  ValueStream<Map<String, Map<String, SessionActivityInfo>>> get sessionActivity => _sessionActivity.stream;

  /// The latest session activity map, synchronously available.
  Map<String, Map<String, SessionActivityInfo>> get currentSessionActivity => _sessionActivity.value;

  /// Whether the current activity maps preserve a bridge-authored user
  /// interaction order. False for summaries from older bridges.
  bool get currentUserInteractionOrdered => _userInteractionOrdered;

  /// Map of project ID -> latest updated timestamp from complete
  /// [SesoriProjectUpdated] events.
  ///
  /// Late subscribers immediately receive the latest cached value.
  ValueStream<Map<String, int>> get projectTimestampUpdates => _projectTimestampUpdates.stream;

  /// The latest project timestamp update map, synchronously available.
  Map<String, int> get currentProjectTimestampUpdates => _projectTimestampUpdates.value;

  void _handleConnectionStatus(ConnectionStatus status) {
    switch (status) {
      case ConnectionDisconnected():
        if (_projectTimestampUpdates.value.isNotEmpty) {
          _projectTimestampUpdates.add(const {});
        }
      case ConnectionConnected() || ConnectionReconnecting() || ConnectionLost() || ConnectionBridgeOffline():
        break;
    }
  }

  void _handleEvent(SseEvent event) {
    try {
      final data = event.data;
      switch (data) {
        case SesoriProjectsSummary(:final projects, :final userInteractionOrdered):
          _updateActivityFromSummary(
            projects,
            userInteractionOrdered: userInteractionOrdered,
          );
        case SesoriProjectUpdated(:final projectID, :final updatedAt):
          if (projectID != null && updatedAt != null) {
            final currentUpdates = _projectTimestampUpdates.value;
            final currentUpdatedAt = currentUpdates[projectID];
            if (currentUpdatedAt == null || updatedAt > currentUpdatedAt) {
              _projectTimestampUpdates.add({...currentUpdates, projectID: updatedAt});
            }
          }
        case SesoriSessionCreated() ||
            SesoriSessionUpdated() ||
            SesoriSessionDeleted() ||
            SesoriServerConnected() ||
            SesoriServerHeartbeat() ||
            SesoriServerInstanceDisposed() ||
            SesoriGlobalDisposed() ||
            SesoriSessionDiff() ||
            SesoriSessionError() ||
            SesoriSessionCompacted() ||
            SesoriSessionStatus() ||
            SesoriMessageUpdated() ||
            SesoriMessageRemoved() ||
            SesoriMessagePartUpdated() ||
            SesoriMessagePartDelta() ||
            SesoriMessagePartRemoved() ||
            SesoriPtyCreated() ||
            SesoriPtyUpdated() ||
            SesoriPtyExited() ||
            SesoriPtyDeleted() ||
            SesoriPermissionAsked() ||
            SesoriPermissionReplied() ||
            SesoriPermissionUpdated() ||
            SesoriQuestionAsked() ||
            SesoriQuestionReplied() ||
            SesoriQuestionRejected() ||
            SesoriCommandExecuted() ||
            SesoriTodoUpdated() ||
            SesoriSessionPromptDefaultsChanged() ||
            SesoriVcsBranchUpdated() ||
            SesoriSessionsUpdated() ||
            SesoriSessionUnseenChanged() ||
            SesoriFileEdited() ||
            SesoriFileWatcherUpdated() ||
            SesoriLspUpdated() ||
            SesoriLspClientDiagnostics() ||
            SesoriMcpToolsChanged() ||
            SesoriMcpBrowserOpenFailed() ||
            SesoriInstallationUpdated() ||
            SesoriInstallationUpdateAvailable() ||
            SesoriWorkspaceReady() ||
            SesoriWorkspaceFailed() ||
            SesoriTuiToastShow() ||
            SesoriWorktreeReady() ||
            SesoriWorktreeFailed():
          break;
      }
    } catch (e, st) {
      loge("SSE event handler error", e, st);
      unawaited(
        _failureReporter
            .recordFailure(
              error: e,
              stackTrace: st,
              uniqueIdentifier: "sse_event_tracker:${event.data.runtimeType.toString()}",
              fatal: false,
              reason: "Failed to handle SSE event in tracker",
              information: [event.data.runtimeType.toString()],
            )
            .catchError((Object error, StackTrace stackTrace) {
              loge("Failed to report SSE event handler error", error, stackTrace);
            }),
      );
    }
  }

  void _updateActivityFromSummary(
    List<ProjectActivitySummary> projects, {
    required bool userInteractionOrdered,
  }) {
    final projectMap = <String, int>{};
    final sessionMap = <String, Map<String, SessionActivityInfo>>{};
    for (final summary in projects) {
      if (summary.activeSessions.isNotEmpty) {
        projectMap[summary.id] = summary.activeSessions.length;
        final infoMap = <String, SessionActivityInfo>{};
        for (final session in summary.activeSessions) {
          infoMap[session.id] = SessionActivityInfo(
            mainAgentRunning: session.mainAgentRunning,
            awaitingInput: session.awaitingInput,
            backgroundTaskCount: session.childSessionIds.length,
            isRetrying: session.isRetrying,
          );
        }
        sessionMap[summary.id] = infoMap;
      }
    }
    _userInteractionOrdered = userInteractionOrdered;
    _projectActivity.add(projectMap);
    _sessionActivity.add(sessionMap);
  }

  @override
  Future<void> onDispose() async {
    try {
      await Future.wait([
        _eventSubscription.cancel(),
        _connectionStatusSubscription.cancel(),
      ]);
    } finally {
      await Future.wait([
        _projectActivity.close(),
        _sessionActivity.close(),
        _projectTimestampUpdates.close(),
      ]);
    }
  }
}
