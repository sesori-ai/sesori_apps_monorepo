import "dart:async";

import "package:bloc/bloc.dart";
import "package:collection/collection.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../errors/remote_failure_reason.dart";
import "../../services/models/all_sessions_mode.dart";
import "../../services/models/project_list_state.dart";
import "../../services/models/session_list_quick_filter.dart";
import "../../services/models/session_window_state.dart";
import "../../services/project_inventory_service.dart";
import "../../services/session_list_filter_tracker.dart";
import "../../services/session_unseen_tracker.dart";
import "../../services/session_window_service.dart";
import "../../services/sse_event_tracker.dart";
import "all_sessions_state.dart";

/// The session list across every listed project: the rows of a
/// [SessionWindowService], under the shared project filter, a query and a
/// chip, each with its project and live state.
///
/// The window owns which sessions match; this only hands it the key and
/// leaves out the sessions the list hides.
class AllSessionsCubit({
  required final SessionWindowService _window,
  required final ProjectInventoryService _projectInventory,
  required final SessionListFilterTracker _filterTracker,
  required final SseEventTracker _sseEventTracker,
  required final SessionUnseenTracker _sessionUnseenTracker,
}) extends Cubit<AllSessionsState> {
  final CompositeSubscription _subscriptions = CompositeSubscription();
  Set<String> _hiddenSessionIds = const {};
  bool _retrying = false;

  /// The project of the newest session, read while nothing narrows the list.
  String? _newestProjectId;

  this : super(_initial) {
    // One live change often moves several of these at once, such as a
    // session update moving the window and its activity: one resolve follows
    // them all.
    _subscriptions.add(
      Rx.merge<void>([
        _window.state.skip(1),
        _projectInventory.stateStream.distinct().skip(1),
        _sseEventTracker.sessionActivity.skip(1),
        _sessionUnseenTracker.sessionUnseen.skip(1),
        // [selectProject] already shows its own selection.
        _filterTracker.projectId.skip(1).where((projectId) => projectId != state.projectId),
      ]).debounceTime(Duration.zero).listen((_) => _update()),
    );
    _update();
  }

  static const AllSessionsState _initial = AllSessionsState(
    projectId: null,
    query: "",
    quickFilter: SessionListQuickFilter.all,
    rows: [],
    counts: SessionListChipCounts(all: 0, running: 0, unread: 0),
    loadMore: null,
    awaitingAnswer: false,
    failure: null,
    isLoading: true,
    scratchProjectId: null,
    defaultProjectId: null,
  );

  AllSessionsMode get mode => _window.mode;

  /// Filters the list to [projectId], or lists every project for null. The
  /// filter is shared by every all-projects list and lasts for the app's run.
  ///
  /// The state follows at once, so a list opened filtered never draws a frame
  /// of the previous filter.
  void selectProject({required String? projectId}) {
    _filterTracker.select(projectId: projectId);
    _update();
  }

  /// The loaded rows narrow at once; the window asks the bridge once typing
  /// pauses.
  void setQuery({required String query}) => _emit(query: query, quickFilter: state.quickFilter);

  void setQuickFilter({required SessionListQuickFilter filter}) => _emit(query: state.query, quickFilter: filter);

  /// Sessions the list leaves out while they still read as unarchived: those
  /// inside an archive's Undo window, and those a launching row holds back.
  void setHiddenSessionIds({required Set<String> sessionIds}) {
    _hiddenSessionIds = Set.unmodifiable(sessionIds);
    _update();
  }

  /// Asks for the page after the rows, when one follows and none is on its
  /// way.
  Future<void> loadMore() => _window.loadMore();

  /// Loads the sessions again after they failed, loading meanwhile.
  Future<void> retry() async {
    _retrying = true;
    _update();
    await _window.reload();
    _retrying = false;
    if (!isClosed) _update();
  }

  void _update() => _emit(query: state.query, quickFilter: state.quickFilter);

  void _emit({required String query, required SessionListQuickFilter quickFilter}) {
    final projectId = _filterTracker.projectId.value;
    final searched = searchWords(query: query).isNotEmpty;
    // The window narrows its rows to a new key at once, so they are read
    // after it.
    _window.select(key: (projectId: projectId, query: searched ? query : null, filter: quickFilter));
    final window = _window.state.value;
    final (projects, scratchProjectId) = switch (_projectInventory.state) {
      ProjectListLoaded(:final projects, :final scratchProject) => (
        {for (final project in projects) project.id: project},
        scratchProject?.id,
      ),
      ProjectListLoading() || ProjectListFailed() || ProjectListBridgeDisconnected() => (
        const <String, ProjectSummary>{},
        null,
      ),
    };
    switch (window) {
      // The newest listed session: one whose project the inventory knows.
      case SessionWindowLoaded(:final sessions, awaitingAnswer: false)
          when projectId == null && !searched && quickFilter == SessionListQuickFilter.all:
        _newestProjectId = sessions.firstWhereOrNull((session) => projects.containsKey(session.projectID))?.projectID;
      case SessionWindowLoaded():
        break;
      // Nothing listed, as on another computer, names no newest session.
      case SessionWindowLoading() || SessionWindowFailed():
        _newestProjectId = null;
    }
    final activity = _sseEventTracker.currentSessionActivity;
    final unseen = _sessionUnseenTracker.currentSessionUnseen;
    final sessions = switch (window) {
      SessionWindowLoaded(:final sessions) => sessions,
      SessionWindowLoading() || SessionWindowFailed() => const <Session>[],
    };
    final next = AllSessionsState(
      projectId: projectId,
      query: query,
      quickFilter: quickFilter,
      rows: List.unmodifiable([
        for (final session in sessions)
          if (projects[session.projectID] case final project?)
            // Only a still-unarchived session hides, as on every list.
            if (session.time?.archived != null || !_hiddenSessionIds.contains(session.id))
              AllSessionsRow(
                session: session,
                project: project,
                isRunning: activity[project.id]?[session.id]?.isRunning ?? false,
                isUnseen: unseen[project.id]?[session.id]?.unseen ?? session.unseen,
                isAwaitingInput: activity[project.id]?[session.id]?.awaitingInput ?? false,
                isRetrying: activity[project.id]?[session.id]?.isRetrying ?? false,
                backgroundTaskCount: activity[project.id]?[session.id]?.backgroundTaskCount ?? 0,
              ),
      ]),
      counts: switch (window) {
        SessionWindowLoaded(:final counts) => SessionListChipCounts(
          all: counts.all,
          running: counts.running,
          unread: counts.unread,
        ),
        SessionWindowLoading() || SessionWindowFailed() => const SessionListChipCounts(all: 0, running: 0, unread: 0),
      },
      loadMore: switch (window) {
        SessionWindowLoaded(nextCursor: _?, :final loadMore) => loadMore,
        SessionWindowLoaded() || SessionWindowLoading() || SessionWindowFailed() => null,
      },
      awaitingAnswer: window is SessionWindowLoaded && window.awaitingAnswer,
      failure: switch (window) {
        SessionWindowFailed(:final reason) when !_retrying => reason,
        // Its row offers Retry beside the rows that did load, and shows no reason.
        SessionWindowLoaded(nextCursor: null, loadMore: SessionWindowLoadMore.failed) when !_retrying =>
          RemoteFailureReason.unknown,
        SessionWindowFailed() || SessionWindowLoading() || SessionWindowLoaded() => null,
      },
      isLoading: _retrying || window is SessionWindowLoading || _projectInventory.state is ProjectListLoading,
      scratchProjectId: scratchProjectId,
      defaultProjectId: projectId ?? scratchProjectId ?? _newestProjectId,
    );
    // A cubit's first emit goes out even when equal to its initial state.
    if (next != state) emit(next);
  }

  @override
  Future<void> close() async {
    await _subscriptions.dispose();
    await super.close();
  }
}
