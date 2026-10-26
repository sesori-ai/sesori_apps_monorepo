import "dart:async";

import "package:bloc/bloc.dart";
import "package:collection/collection.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../services/models/project_list_state.dart";
import "../../services/models/recent_sessions_entry.dart";
import "../../services/project_inventory_service.dart";
import "../../services/recent_session_inventory_service.dart";
import "../../services/session_list_filter_tracker.dart";
import "../../services/session_list_service.dart";
import "../../utils/title_matcher.dart";
import "../recent_sessions/recent_sessions_resolvers.dart";
import "../session_list/session_list_quick_filter.dart";
import "all_sessions_state.dart";

/// The session list across every listed project: one flat list from the
/// scoped inventories, narrowed by the shared project filter, a query and a
/// chip.
///
/// [AllSessionsMode.archived] reloads the inventory when it opens: the bridge
/// publishes no event on archive.
class AllSessionsCubit({
  required final AllSessionsMode _mode,
  required final RecentSessionInventoryService _recentInventory,
  required final ProjectInventoryService _projectInventory,
  required final SessionListFilterTracker _filterTracker,
  required final SessionListService _sessionListService,
}) extends Cubit<AllSessionsState> {
  final CompositeSubscription _subscriptions = CompositeSubscription();
  Set<String> _hiddenSessionIds = const {};

  this
    : super(
        _resolve(
          mode: _mode,
          projects: _projectInventory.state,
          entries: _recentInventory.state.value,
          projectId: _filterTracker.projectId.value,
          query: "",
          quickFilter: SessionListQuickFilter.all,
          hiddenSessionIds: const {},
          sessionListService: _sessionListService,
        ),
      ) {
    _subscriptions
      ..add(_recentInventory.state.skip(1).listen((_) => _update()))
      ..add(_projectInventory.stateStream.skip(1).listen((_) => _update()))
      // [selectProject] already shows its own selection.
      ..add(
        _filterTracker.projectId.skip(1).where((projectId) => projectId != state.projectId).listen((_) => _update()),
      );
    if (_mode == AllSessionsMode.archived) unawaited(_recentInventory.refresh());
  }

  AllSessionsMode get mode => _mode;

  /// Filters the list to [projectId], or lists every project for null. The
  /// filter is shared by every all-projects list and lasts for the app's run.
  ///
  /// The state follows at once, so a list opened filtered never draws a frame
  /// of the previous filter.
  void selectProject({required String? projectId}) {
    _filterTracker.select(projectId: projectId);
    _update();
  }

  void setQuery({required String query}) => _emit(query: query, quickFilter: state.quickFilter);

  void setQuickFilter({required SessionListQuickFilter filter}) => _emit(query: state.query, quickFilter: filter);

  /// Sessions the list leaves out while they still read as unarchived: those
  /// inside an archive's Undo window, and those a launching row holds back.
  void setHiddenSessionIds({required Set<String> sessionIds}) {
    _hiddenSessionIds = Set.unmodifiable(sessionIds);
    _emit(query: state.query, quickFilter: state.quickFilter);
  }

  Future<void> retry({required String projectId}) => _recentInventory.retry(projectId: projectId);

  void _update() => _emit(query: state.query, quickFilter: state.quickFilter);

  void _emit({required String query, required SessionListQuickFilter quickFilter}) => emit(
    _resolve(
      mode: _mode,
      projects: _projectInventory.state,
      entries: _recentInventory.state.value,
      projectId: _filterTracker.projectId.value,
      query: query,
      quickFilter: quickFilter,
      hiddenSessionIds: _hiddenSessionIds,
      sessionListService: _sessionListService,
    ),
  );

  static AllSessionsState _resolve({
    required AllSessionsMode mode,
    required ProjectListState projects,
    required Map<String, RecentSessionsEntry> entries,
    required String? projectId,
    required String query,
    required SessionListQuickFilter quickFilter,
    required Set<String> hiddenSessionIds,
    required SessionListService sessionListService,
  }) {
    final (known, scratchProjectId) = switch (projects) {
      ProjectListLoaded(:final projects, :final scratchProject) => (projects, scratchProject?.id),
      ProjectListLoading() ||
      ProjectListFailed() ||
      ProjectListBridgeDisconnected() => (const <ProjectSummary>[], null),
    };
    final listed = [
      for (final project in known)
        if (projectId == null || project.id == projectId) project,
    ];
    final everyProject =
        <AllSessionsRow>[
          for (final project in known)
            if (entries[project.id] case final RecentSessionsLoaded entry)
              for (final session in switch (mode) {
                AllSessionsMode.active => entry.visibleSessions,
                AllSessionsMode.archived => entry.archivedSessions,
              })
                AllSessionsRow(
                  session: session,
                  project: project,
                  isRunning: entry.isRunning(session: session),
                  isUnseen: entry.isUnseen(session: session),
                  isAwaitingInput: entry.isAwaitingInput(session: session),
                  isRetrying: entry.activityBySessionId[session.id]?.isRetrying ?? false,
                  backgroundTaskCount: entry.activityBySessionId[session.id]?.backgroundTaskCount ?? 0,
                ),
        ]..sort(
          (a, b) => switch (mode) {
            AllSessionsMode.active => sessionListService.compareByUpdate(a: a.session, b: b.session),
            AllSessionsMode.archived => sessionListService.compareByArchive(a: a.session, b: b.session),
          },
        );
    final merged = projectId == null ? everyProject : everyProject.where((row) => row.project.id == projectId).toList();
    // Only a still-unarchived session hides, as on every list.
    bool shown(AllSessionsRow row) => row.session.time?.archived != null || !hiddenSessionIds.contains(row.session.id);
    final counted = matchTitles(
      items: merged,
      titleOf: (row) => row.session.title,
      query: query,
    ).where(shown).toList();
    final isLoading =
        projects is ProjectListLoading ||
        listed.any(
          (project) => switch (entries[project.id]) {
            RecentSessionsLoading() || null => true,
            RecentSessionsLoaded() || RecentSessionsFailed() => false,
          },
        );
    return AllSessionsState(
      projectId: projectId,
      query: query,
      quickFilter: quickFilter,
      everyProjectRows: List.unmodifiable(everyProject.where(shown)),
      rows: List.unmodifiable(
        counted.where(
          (row) => switch (quickFilter) {
            SessionListQuickFilter.all => true,
            SessionListQuickFilter.running => row.isRunning,
            SessionListQuickFilter.unread => row.isUnseen,
          },
        ),
      ),
      counts: SessionListChipCounts(
        all: counted.length,
        running: counted.where((row) => row.isRunning).length,
        unread: counted.where((row) => row.isUnseen).length,
      ),
      failures: List.unmodifiable([
        for (final project in listed)
          if (entries[project.id] case RecentSessionsFailed(:final reason))
            AllSessionsFailure(project: project, reason: reason),
      ]),
      isLoading: isLoading,
      scratchProjectId: scratchProjectId,
      // The newest session is only known once every project's sessions have
      // loaded: the first project to answer is not the default.
      defaultProjectId: projectId ?? scratchProjectId ?? (isLoading ? null : merged.firstOrNull?.project.id),
    );
  }

  @override
  Future<void> close() async {
    await _subscriptions.dispose();
    await super.close();
  }
}
