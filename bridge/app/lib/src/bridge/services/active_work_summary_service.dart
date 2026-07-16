import "dart:async";

import "package:collection/collection.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show ProjectActivitySummary;

import "../repositories/models/stored_session.dart";
import "../repositories/session_repository.dart";

typedef ActiveWorkRefresh = ({
  bool changed,
  Object? error,
  List<ProjectActivitySummary> projects,
  StackTrace? stackTrace,
});

/// Owns the bridge's authoritative active-work ordering and refresh state.
class ActiveWorkSummaryService {
  static const ListEquality<ProjectActivitySummary> _summaryEquality = ListEquality<ProjectActivitySummary>();

  final SessionRepository _sessionRepository;
  final Duration _retryDelay;
  final StreamController<List<ProjectActivitySummary>> _changes =
      StreamController<List<ProjectActivitySummary>>.broadcast(sync: true);

  List<ProjectActivitySummary> _current = const [];
  Future<ActiveWorkRefresh>? _refreshing;
  Timer? _retryTimer;
  bool _dirty = false;
  bool _hasSnapshot = false;
  bool _disposed = false;

  ActiveWorkSummaryService({
    required SessionRepository sessionRepository,
    required Duration retryDelay,
  }) : _sessionRepository = sessionRepository,
       _retryDelay = retryDelay;

  Stream<List<ProjectActivitySummary>> get changedSnapshots => _changes.stream;

  List<ProjectActivitySummary>? get currentSnapshot => _hasSnapshot ? _current : null;

  /// Rebuilds from committed bridge state. Concurrent triggers coalesce, while
  /// a trigger received during a build guarantees one subsequent build.
  Future<ActiveWorkRefresh> refresh() {
    if (_disposed) {
      return Future.value((changed: false, error: null, projects: _current, stackTrace: null));
    }
    _dirty = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    return _refreshing ??= _drainRefreshes();
  }

  Future<ActiveWorkRefresh> _drainRefreshes() async {
    var changed = false;
    Object? refreshError;
    StackTrace? refreshStackTrace;
    try {
      while (_dirty && !_disposed) {
        _dirty = false;
        try {
          final next = await _buildSnapshot();
          if (!_hasSnapshot || !_summaryEquality.equals(_current, next)) {
            _current = next;
            _hasSnapshot = true;
            changed = true;
            if (!_changes.isClosed) _changes.add(next);
          }
        } on Object catch (error, stackTrace) {
          _dirty = true;
          refreshError = error;
          refreshStackTrace = stackTrace;
          Log.w("Active-work summary refresh failed; retrying", error, stackTrace);
          _scheduleRetry();
          break;
        }
      }
      return (
        changed: changed,
        error: refreshError,
        projects: _current,
        stackTrace: refreshStackTrace,
      );
    } finally {
      _refreshing = null;
      if (_dirty && _retryTimer == null && !_disposed) {
        unawaited(refresh());
      }
    }
  }

  Future<List<ProjectActivitySummary>> _buildSnapshot() async {
    final summaries = await _sessionRepository.getProjectActivitySummaries();
    final storedByProject = <String, List<StoredSession>>{};
    await Future.wait([
      for (final project in summaries)
        _sessionRepository.getStoredSessionsByProjectId(projectId: project.id).then((sessions) {
          storedByProject[project.id] = sessions;
        }),
    ]);
    final interactionBySessionId = <String, int?>{};
    final interactionByProjectId = <String, int?>{};
    for (final project in summaries) {
      int? projectInteraction;
      for (final session in storedByProject[project.id] ?? const <StoredSession>[]) {
        if (session.parentSessionId != null) continue;
        final interaction = session.lastUserInteractionAt;
        interactionBySessionId[session.id] = interaction;
        if (interaction != null && (projectInteraction == null || interaction > projectInteraction)) {
          projectInteraction = interaction;
        }
      }
      interactionByProjectId[project.id] = projectInteraction;
    }

    final projects = <ProjectActivitySummary>[];
    for (final project in summaries) {
      if (project.activeSessions.isEmpty) continue;
      final sessions = project.activeSessions.toList()
        ..sort((a, b) {
          final interactionCompare = _compareInteraction(
            a: interactionBySessionId[a.id],
            b: interactionBySessionId[b.id],
          );
          return interactionCompare != 0 ? interactionCompare : a.id.compareTo(b.id);
        });
      projects.add(project.copyWith(activeSessions: sessions));
    }
    projects.sort((a, b) {
      final interactionCompare = _compareInteraction(
        a: interactionByProjectId[a.id],
        b: interactionByProjectId[b.id],
      );
      return interactionCompare != 0 ? interactionCompare : a.id.compareTo(b.id);
    });
    return List<ProjectActivitySummary>.unmodifiable(projects);
  }

  int _compareInteraction({required int? a, required int? b}) {
    if (a == null) return b == null ? 0 : 1;
    if (b == null) return -1;
    return b.compareTo(a);
  }

  void _scheduleRetry() {
    if (_retryTimer != null || _disposed) return;
    _retryTimer = Timer(_retryDelay, () {
      _retryTimer = null;
      unawaited(refresh());
    });
  }

  Future<void> dispose() async {
    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    await _refreshing;
    await _changes.close();
  }
}
