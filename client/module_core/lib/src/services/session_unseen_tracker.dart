import "dart:async";

import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/sse_event.dart";
import "../logging/logging.dart";

/// Layer-3 tracker that maintains the real-time unseen (new-changes) state for
/// projects and sessions from the bridge's `SesoriSessionUnseenChanged` SSE
/// events. The project list and session list cubits subscribe to its streams;
/// initial state comes from the REST loads (`Project.hasUnseenChanges` /
/// `Session.unseen`), with these maps taking precedence once populated.
@lazySingleton
class SessionUnseenTracker with Disposable {
  final FailureReporter _failureReporter;
  late final StreamSubscription<SseEvent> _subscription;

  // project ID -> whether the project has any unseen session.
  final BehaviorSubject<Map<String, bool>> _projectUnseen = BehaviorSubject.seeded(const {});

  // project ID -> (session ID -> unseen).
  final BehaviorSubject<Map<String, Map<String, bool>>> _sessionUnseen = BehaviorSubject.seeded(const {});

  SessionUnseenTracker(
    ConnectionService connectionService, {
    required FailureReporter failureReporter,
  }) : _failureReporter = failureReporter {
    _subscription = connectionService.events.listen(_handleEvent);
  }

  /// project ID -> whether it has unseen changes. Late subscribers get the
  /// latest cached value.
  ValueStream<Map<String, bool>> get projectUnseen => _projectUnseen.stream;

  Map<String, bool> get currentProjectUnseen => _projectUnseen.value;

  /// project ID -> (session ID -> unseen). Late subscribers get the latest
  /// cached value.
  ValueStream<Map<String, Map<String, bool>>> get sessionUnseen => _sessionUnseen.stream;

  Map<String, Map<String, bool>> get currentSessionUnseen => _sessionUnseen.value;

  /// Reconciles the per-project unseen aggregate from an authoritative source
  /// (a REST `/projects` refresh). This keeps the tracker as the single source
  /// of truth so a stale live `true` (e.g. after the last unseen session was
  /// archived without a follow-up SSE event) cannot indefinitely override a
  /// fresh aggregate. Per-session state is left untouched.
  void reconcileProjectUnseen(Map<String, bool> unseenByProjectId) {
    if (_projectUnseen.isClosed) return;
    final projects = Map<String, bool>.from(_projectUnseen.value);
    projects.addAll(unseenByProjectId);
    _projectUnseen.add(projects);
  }

  void _handleEvent(SseEvent event) {
    try {
      if (event.data
          case SesoriSessionUnseenChanged(
            :final projectID,
            :final sessionId,
            :final unseen,
            :final projectHasUnseenChanges,
          )) {
        final projects = Map<String, bool>.from(_projectUnseen.value);
        projects[projectID] = projectHasUnseenChanges;
        _projectUnseen.add(projects);

        // Copy only the outer map and the affected project's inner map
        // (O(sessions in this project)), not every project's sessions.
        final sessions = Map<String, Map<String, bool>>.from(_sessionUnseen.value);
        final projectSessions = Map<String, bool>.from(sessions[projectID] ?? const {});
        projectSessions[sessionId] = unseen;
        sessions[projectID] = projectSessions;
        _sessionUnseen.add(sessions);
      }
    } catch (e, st) {
      loge("SessionUnseenTracker event handler error", e, st);
      unawaited(
        _failureReporter
            .recordFailure(
              error: e,
              stackTrace: st,
              uniqueIdentifier: "session_unseen_tracker:${event.data.runtimeType.toString()}",
              fatal: false,
              reason: "Failed to handle unseen SSE event",
              information: [event.data.runtimeType.toString()],
            )
            .catchError((_) {}),
      );
    }
  }

  @override
  FutureOr<void> onDispose() {
    _subscription.cancel();
    _projectUnseen.close();
    _sessionUnseen.close();
  }
}
