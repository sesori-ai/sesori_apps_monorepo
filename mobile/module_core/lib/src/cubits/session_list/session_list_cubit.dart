import "dart:async";

import "package:bloc/bloc.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/project/project_service.dart";
import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/sse_event.dart";
import "../../capabilities/session/session_service.dart";
import "../../capabilities/sse/sse_event_repository.dart";
import "../../logging/logging.dart";
import "session_list_state.dart";

class SessionListCubit extends Cubit<SessionListState> {
  final CompositeSubscription _subscriptions = CompositeSubscription();

  final SessionService _service;
  final ProjectService _projectService;
  final SseEventRepository _sseEventRepository;
  final String _projectId;
  final String _worktree;

  /// Tracks the session state before the last archive/unarchive action
  /// so the screen can offer an undo toast.
  Session? _undoSnapshot;

  SessionListCubit(
    SessionService service,
    ProjectService projectService,
    ConnectionService connectionService,
    SseEventRepository sseEventRepository, {
    required String projectId,
    required String worktree,
  }) : _service = service,
       _projectService = projectService,
       _sseEventRepository = sseEventRepository,
       _projectId = projectId,
       _worktree = worktree,
       super(const SessionListState.loading()) {
    loadSessions();
    _subscriptions.add(connectionService.events.listen(_handleEvent));
    _subscriptions.add(
      _sseEventRepository.sessionActivity.listen(_onSessionActivityUpdated),
    );
  }

  /// Returns `true` when [session] belongs to this project's worktree.
  ///
  /// Filters by directory path: includes sessions from the worktree root
  /// and any subdirectories. Project ID checking is handled server-side
  /// by the bridge's session merging mapper.
  bool _belongsHere(Session session) {
    if (_worktree == "/") return true;
    return session.directory == _worktree || session.directory.startsWith("$_worktree/");
  }

  void _handleEvent(SseEvent event) {
    switch (event.data) {
      case SesoriSessionCreated(:final info):
        _onSessionCreated(info);
      case SesoriSessionUpdated(:final info):
        _onSessionUpdated(info);
      case SesoriSessionDeleted(:final info):
        _onSessionDeleted(info);
      default:
        break;
    }
  }

  void _onSessionActivityUpdated(Map<String, Set<String>> activityById) {
    if (isClosed) return;
    if (state is! SessionListLoaded) return;
    final activeIds = activityById[_worktree] ?? {};
    emit(
      SessionListState.loaded(
        sessions: (state as SessionListLoaded).sessions,
        showArchived: (state as SessionListLoaded).showArchived,
        activeSessionIds: activeIds,
      ),
    );
  }

  void _onSessionCreated(Session session) {
    // Only add root sessions belonging to this project's worktree.
    if (session.parentID != null) return;
    if (!_belongsHere(session)) return;

    if (state is! SessionListLoaded) return;

    // Avoid duplicates.
    if (_allSessions.any((s) => s.id == session.id)) return;

    _allSessions = [session, ..._allSessions];
    _emitFiltered();
  }

  void _onSessionUpdated(Session session) {
    if (state is! SessionListLoaded) return;

    final index = _allSessions.indexWhere((s) => s.id == session.id);

    if (index < 0) {
      // Session was unarchived (or created elsewhere) — add it if it belongs here.
      _onSessionCreated(session);
      return;
    }

    _allSessions = List<Session>.from(_allSessions);
    _allSessions[index] = session;
    _emitFiltered();
  }

  void _onSessionDeleted(Session session) {
    if (state is! SessionListLoaded) return;

    final before = _allSessions.length;
    _allSessions = _allSessions.where((s) => s.id != session.id).toList();
    if (_allSessions.length == before) return;

    _emitFiltered();
  }

  // ---------------------------------------------------------------------------
  // Archive / Unarchive / Delete
  // ---------------------------------------------------------------------------

  /// Archives a session. Returns `true` on success so the screen can show
  /// an undo toast.
  Future<bool> archiveSession(String sessionId) async {
    if (state is! SessionListLoaded) return false;

    final index = _allSessions.indexWhere((s) => s.id == sessionId);
    if (index < 0) return false;

    // Store for undo before removing.
    _undoSnapshot = _allSessions[index];

    // Optimistically mark as archived in the backing list so _emitFiltered
    // hides it when showArchived is off.
    _allSessions = List<Session>.from(_allSessions);
    _allSessions[index] = _allSessions[index].copyWith(
      time: _allSessions[index].time?.copyWith(archived: DateTime.now().millisecondsSinceEpoch),
    );
    _emitFiltered();

    final response = await _service.archiveSession(sessionId);
    if (isClosed) return false;

    return switch (response) {
      SuccessResponse() => true,
      ErrorResponse(:final error) => () {
        loge("Failed to archive session: $error");
        // Rollback — re-insert the original session.
        _rollbackLastAction();
        return false;
      }(),
    };
  }

  /// Unarchives a session. Returns `true` on success so the screen can show
  /// an undo toast.
  Future<bool> unarchiveSession(String sessionId) async {
    if (state is! SessionListLoaded) return false;

    final index = _allSessions.indexWhere((s) => s.id == sessionId);
    if (index < 0) return false;

    // Store for undo before modifying.
    _undoSnapshot = _allSessions[index];

    // Optimistically mark as unarchived.
    _allSessions = List<Session>.from(_allSessions);
    _allSessions[index] = _allSessions[index].copyWith(
      time: _allSessions[index].time?.copyWith(archived: null),
    );
    _emitFiltered();

    final response = await _service.unarchiveSession(sessionId);
    if (isClosed) return false;

    return switch (response) {
      SuccessResponse(:final data) => () {
        // Replace with fresh server data.
        _reinsertSession(data);
        return true;
      }(),
      ErrorResponse(:final error) => () {
        loge("Failed to unarchive session: $error");
        // Rollback — restore the archived session.
        _rollbackLastAction();
        return false;
      }(),
    };
  }

  /// Undoes the last archive or unarchive operation by reversing the action.
  Future<bool> undoLastArchiveAction() async {
    final snapshot = _undoSnapshot;
    if (snapshot == null) return false;
    _undoSnapshot = null;

    // If the snapshot was archived, the last action was an unarchive → re-archive.
    // If the snapshot was not archived, the last action was an archive → unarchive.
    final wasArchived = snapshot.time?.archived != null;
    final response = wasArchived
        ? await _service.archiveSession(snapshot.id)
        : await _service.unarchiveSession(snapshot.id);
    if (isClosed) return false;

    switch (response) {
      case SuccessResponse(:final data):
        _reinsertSession(data);
        return true;
      case ErrorResponse(:final error):
        loge("Failed to undo archive action: $error");
        return false;
    }
  }

  /// Clears undo state. Called when the undo toast dismisses.
  void clearLastActionUndo() {
    _undoSnapshot = null;
  }

  /// Deletes a session permanently.
  Future<bool> deleteSession(String sessionId) async {
    if (state is! SessionListLoaded) return false;

    final index = _allSessions.indexWhere((s) => s.id == sessionId);
    if (index < 0) return false;

    // Optimistically remove.
    _allSessions = List<Session>.from(_allSessions)..removeAt(index);
    _emitFiltered();

    final response = await _service.deleteSession(sessionId);
    if (isClosed) return false;

    return switch (response) {
      SuccessResponse() => true,
      ErrorResponse(:final error) => () {
        loge("Failed to delete session: $error");
        // Reload to restore consistent state.
        loadSessions();
        return false;
      }(),
    };
  }

  void _rollbackLastAction() {
    final session = _undoSnapshot;
    if (session == null) return;
    _undoSnapshot = null;
    _reinsertSession(session);
  }

  void _reinsertSession(Session session) {
    if (state is! SessionListLoaded) return;

    // Replace or insert in backing list.
    final index = _allSessions.indexWhere((s) => s.id == session.id);
    _allSessions = List<Session>.from(_allSessions);
    if (index >= 0) {
      _allSessions[index] = session;
    } else {
      _allSessions.insert(0, session);
    }
    _emitFiltered();
  }

  // ---------------------------------------------------------------------------

  /// Creates a new session via POST /session and returns it, or null on failure.
  Future<Session?> createSession() async {
    final response = await _service.createSession(projectId: _projectId);

    if (isClosed) return null;

    return switch (response) {
      SuccessResponse(:final data) => data,
      ErrorResponse() => null,
    };
  }

  /// Tracks the full unfiltered server response so toggling archived
  /// doesn't require a network round-trip.
  List<Session> _allSessions = [];
  bool _showArchived = false;

  void toggleArchived() {
    _showArchived = !_showArchived;
    _emitFiltered();
  }

  void _emitFiltered() {
    var visible = _allSessions.where(_belongsHere);
    if (!_showArchived) {
      visible = visible.where((s) => s.time?.archived == null);
    }
    final sorted = visible.toList()..sort((a, b) => (b.time?.updated ?? 0).compareTo(a.time?.updated ?? 0));

    if (isClosed) return;
    emit(
      SessionListState.loaded(
        sessions: sorted,
        showArchived: _showArchived,
        activeSessionIds: _sseEventRepository.currentSessionActivity[_worktree] ?? {},
      ),
    );
  }

  Future<void> loadSessions() async {
    emit(const SessionListState.loading());
    await _fetchSessions();
  }

  /// Re-fetches sessions without showing the full-screen loading indicator.
  /// Returns `false` when the refresh fails so the UI can show feedback.
  Future<bool> refreshSessions() async {
    return _fetchSessions(silent: true);
  }

  Future<bool> _fetchSessions({bool silent = false}) async {
    final response = await _service.listSessions(projectId: _projectId);
    if (isClosed) return false;

    switch (response) {
      case SuccessResponse(:final data):
        _allSessions = data;

        // If no sessions belong to this project at all, check whether the
        // stored worktree is stale (directory renamed/deleted). We check
        // AFTER loading to avoid false-positives: non-git directories also
        // resolve to "global" but their sessions are still valid.
        if (!_allSessions.any(_belongsHere)) {
          final projectResponse = await _projectService.getCurrentProject(projectId: _projectId);
          if (isClosed) return false;

          if (projectResponse case SuccessResponse(data: final current) when current.id != _projectId) {
            logw("Stale project: expected $_projectId, server resolved ${current.id}");
            emit(SessionListState.staleProject(resolvedProjectId: current.id));
            return true;
          }
        }

        _emitFiltered();
        return true;

      case ErrorResponse(:final error):
        if (silent) {
          logw("Failed to refresh sessions: $error");
        } else {
          emit(SessionListState.failed(error: error));
        }
        return false;
    }
  }

  @override
  Future<void> close() {
    _subscriptions.dispose();
    return super.close();
  }
}
