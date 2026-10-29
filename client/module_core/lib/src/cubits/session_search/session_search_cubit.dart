import "dart:async";

import "package:bloc/bloc.dart";
import "package:collection/collection.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../services/models/project_list_state.dart";
import "../../services/models/session_window_state.dart";
import "../../services/project_inventory_service.dart";
import "../../services/session_window_service.dart";
import "session_search_state.dart";

/// Searches every project's sessions for a jump-to palette, through the
/// scope's active [SessionWindowService].
///
/// A query's matches among the loaded rows, and among the matches already
/// shown, appear at once; the bridge's answer replaces them [searchDelay]
/// after the last keystroke. Those first matches are mostly the newest of the
/// answer, so the answer usually only adds rows below them. A blank query
/// lists the newest loaded sessions.
class SessionSearchCubit({
  required final SessionWindowService _window,
  required final ProjectInventoryService _projectInventory,
}) extends Cubit<SessionSearchState> {
  static const int limit = 20;
  static const Duration searchDelay = Duration(milliseconds: 200);

  late final StreamSubscription<void> _loaded;
  String _query = "";

  /// Bumped by every query, so an answer the user has typed past is dropped.
  int _generation = 0;
  Timer? _searchTimer;

  this : super(const SessionSearchState(matches: [], isSearching: false)) {
    _showLoaded(isSearching: false);
    // Rows, or the projects they open in, that load later fill an empty
    // list, but never move rows already shown.
    _loaded = Rx.merge<void>([_window.state.skip(1), _projectInventory.stateStream.skip(1)]).listen((_) {
      if (state.matches.isEmpty) _showLoaded(isSearching: state.isSearching);
    });
  }

  void setQuery({required String query}) {
    if (query == _query) return;
    _query = query;
    _searchTimer?.cancel();
    final generation = ++_generation;
    final blank = searchWords(query: query).isEmpty;
    _showLoaded(isSearching: !blank);
    if (blank) return;
    _searchTimer = Timer(searchDelay, () => unawaited(_search(query: query, generation: generation)));
  }

  void _showLoaded({required bool isSearching}) => _show(
    sessions: _window.searchLoaded(
      query: _query,
      // Matches of an earlier query that still match stay, so they do not
      // vanish until the bridge answers.
      earlier: isSearching ? [for (final match in state.matches) match.session] : const [],
      limit: limit,
    ),
    isSearching: isSearching,
  );

  Future<void> _search({required String query, required int generation}) async {
    final result = await _window.search(query: query, limit: limit);
    if (isClosed || generation != _generation) return;
    switch (result) {
      case SessionWindowSearchMatches(:final sessions):
        _show(sessions: sessions, isSearching: false);
      case SessionWindowSearchFailure():
        // The loaded rows' matches stay; the window logged the failure.
        _show(sessions: [for (final match in state.matches) match.session], isSearching: false);
    }
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
        if (projects[session.projectID] case final project?) (session: session, project: project),
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
    await super.close();
  }
}
