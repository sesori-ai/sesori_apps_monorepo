import "dart:async";

import "package:bloc/bloc.dart";
import "package:collection/collection.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../logging/logging.dart";
import "../../repositories/plugin_repository.dart";
import "../../services/models/project_list_state.dart";
import "../../services/models/session_window_state.dart";
import "../../services/project_inventory_service.dart";
import "../../services/session_window_service.dart";
import "../../services/sse_event_tracker.dart";
import "session_search_state.dart";

/// Searches every project's sessions for a jump-to palette or a session
/// picker, through the scope's active [SessionWindowService].
///
/// A query's matches among the loaded rows, and among the matches already
/// shown, appear at once; the bridge's answer replaces them [searchDelay]
/// after the last keystroke. Those first matches are mostly the newest of the
/// answer, so the answer usually only adds rows below them. A blank query
/// lists the newest sessions of every project, whatever the sidebar's key: the
/// loaded rows at once, then the bridge's answer, asked as soon as the palette
/// opens.
///
/// [_excludedSessionId] never shows, such as the session a picker sends
/// from. A running match says what a prompt to it does, from its plugin's
/// declaration, listed once when the cubit opens.
class SessionSearchCubit({
  required final SessionWindowService _window,
  required final ProjectInventoryService _projectInventory,
  required final SseEventTracker _sseEventTracker,
  required final PluginRepository _pluginRepository,
  required final String? _excludedSessionId,
}) extends Cubit<SessionSearchState> {
  static const int limit = 20;
  static const Duration searchDelay = Duration(milliseconds: 200);

  late final StreamSubscription<void> _loaded;
  late final StreamSubscription<void> _activity;
  String _query = "";

  /// The bridge's latest answer for a blank query, shown again at once when
  /// the query is cleared.
  List<Session> _newest = const [];

  /// Bumped by every query, so an answer the user has typed past is dropped.
  int _generation = 0;
  Timer? _searchTimer;

  /// Each plugin's declaration, empty until the bridge lists them or when it
  /// could not.
  Map<String, BusyPromptHandling> _busyPromptHandling = const {};

  this : super(const SessionSearchState(matches: [], isSearching: false)) {
    _showLoaded(isSearching: true);
    unawaited(_search(query: _query, generation: _generation));
    unawaited(_listPlugins());
    // Rows, or the projects they open in, that load later fill an empty
    // list, but never move rows already shown.
    _loaded = Rx.merge<void>([_window.state.skip(1), _projectInventory.stateStream.skip(1)]).listen((_) {
      if (state.matches.isEmpty) _showLoaded(isSearching: state.isSearching);
    });
    _activity = _sseEventTracker.sessionActivity.skip(1).listen((_) => _showShown());
  }

  void setQuery({required String query}) {
    if (query == _query) return;
    _query = query;
    _searchTimer?.cancel();
    final generation = ++_generation;
    _showLoaded(isSearching: true);
    _searchTimer = Timer(searchDelay, () => unawaited(_search(query: query, generation: generation)));
  }

  void _showLoaded({required bool isSearching}) => _show(
    sessions: _window.searchLoaded(
      query: _query,
      // Matches of an earlier query that still match stay, so they do not
      // vanish until the bridge answers. A cleared query brings back the
      // newest the bridge listed.
      earlier: searchWords(query: _query).isEmpty
          ? _newest
          : isSearching
          ? [for (final match in state.matches) match.session]
          : const [],
      limit: limit,
    ),
    isSearching: isSearching,
  );

  /// The matches already shown again, with their running state now.
  void _showShown() =>
      _show(sessions: [for (final match in state.matches) match.session], isSearching: state.isSearching);

  Future<void> _search({required String query, required int generation}) async {
    final result = await _window.search(query: query, limit: limit);
    if (isClosed || generation != _generation) return;
    switch (result) {
      case SessionWindowSearchMatches(:final sessions):
        if (searchWords(query: query).isEmpty) _newest = sessions;
        _show(sessions: sessions, isSearching: false);
      case SessionWindowSearchFailure():
        // The loaded rows' matches stay; the window logged the failure.
        _show(sessions: [for (final match in state.matches) match.session], isSearching: false);
    }
  }

  Future<void> _listPlugins() async {
    final response = await _pluginRepository.listPlugins();
    if (isClosed) return;
    switch (response) {
      case SuccessResponse(:final data):
        _busyPromptHandling = {for (final plugin in data.plugins) plugin.id: plugin.busyPromptHandling};
        _showShown();
      case ErrorResponse(:final error):
        // Running matches keep the label that warns of nothing.
        logw("[SessionSearch] Could not list plugins for running matches", error);
    }
  }

  RunningTarget? _runningOf({required Session session}) {
    final running = _sseEventTracker.currentSessionActivity[session.projectID]?[session.id]?.isRunning ?? false;
    if (!running) return null;
    return switch (_busyPromptHandling[session.pluginId]) {
      BusyPromptHandling.stopTurn => RunningTarget.stopsTurn,
      BusyPromptHandling.steer || BusyPromptHandling.unknown || null => RunningTarget.keepsTurn,
    };
  }

  void _show({required List<Session> sessions, required bool isSearching}) {
    final projects = switch (_projectInventory.state) {
      ProjectListLoaded(:final projects) => {for (final project in projects) project.id: project},
      ProjectListLoading() ||
      ProjectListFailed() ||
      ProjectListBridgeDisconnected() => const <String, ProjectSummary>{},
    };
    final matches = [
      for (final session in sessions)
        if (session.id != _excludedSessionId)
          if (projects[session.projectID] case final project?)
            (session: session, project: project, running: _runningOf(session: session)),
    ];
    final unchanged = const ListEquality<SessionSearchMatch>().equals(matches, state.matches);
    if (unchanged && isSearching == state.isSearching) return;
    emit(
      SessionSearchState(
        matches: unchanged ? state.matches : List.unmodifiable(matches),
        isSearching: isSearching,
      ),
    );
  }

  @override
  Future<void> close() async {
    _searchTimer?.cancel();
    await _loaded.cancel();
    await _activity.cancel();
    await super.close();
  }
}
