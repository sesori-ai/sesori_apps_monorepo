import "dart:async";

import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../server_connection/connection_service.dart";
import "../server_connection/models/sse_event.dart";
import "session_activity_info.dart";

@lazySingleton
class SseEventRepository with Disposable {
  final ConnectionService _connectionService;
  late final StreamSubscription<SseEvent> _subscription;

  final BehaviorSubject<Map<String, int>> _projectActivity = BehaviorSubject.seeded(const {});

  /// Map of project ID -> (session ID -> activity info).
  final BehaviorSubject<Map<String, Map<String, SessionActivityInfo>>> _sessionActivity = BehaviorSubject.seeded(
    const {},
  );

  SseEventRepository(ConnectionService connectionService) : _connectionService = connectionService {
    _subscription = _connectionService.events.listen(_handleEvent);
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

  void _handleEvent(SseEvent event) {
    if (event.data case SesoriProjectsSummary(:final projects)) {
      final projectMap = <String, int>{};
      final sessionMap = <String, Map<String, SessionActivityInfo>>{};
      for (final summary in projects) {
        if (summary.activeSessions.isNotEmpty) {
          projectMap[summary.id] = summary.activeSessions.length;
          final infoMap = <String, SessionActivityInfo>{};
          for (final session in summary.activeSessions) {
            infoMap[session.id] = SessionActivityInfo(
              mainAgentRunning: session.mainAgentRunning,
              backgroundTaskCount: session.childSessionIds.length,
            );
          }
          sessionMap[summary.id] = infoMap;
        }
      }
      _projectActivity.add(projectMap);
      _sessionActivity.add(sessionMap);
    }
  }

  @override
  FutureOr<void> onDispose() {
    _subscription.cancel();
    _projectActivity.close();
    _sessionActivity.close();
  }
}
