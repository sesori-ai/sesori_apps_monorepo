import "dart:async";

import "package:bloc/bloc.dart";
import "package:collection/collection.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../foundation/models/session_launch/session_launch.dart";
import "../../services/models/session_list_quick_filter.dart";
import "../../services/models/session_window_state.dart";
import "../../services/session_launch_service.dart";
import "../../services/session_window_service.dart";
import "session_launch_resolvers.dart";

typedef _Update = ({SessionWindowState window, List<SessionLaunch> launches});

/// One surface's launching rows per project (see [resolveProjectLaunchRows]),
/// carried from one update to the next. Each surface that draws launches per
/// project owns one.
///
/// The rows are resolved on every window and launch update, so each update is
/// seen once and a launch's session is never missed. Only the window's own
/// answer for an unsearched key on chip All settles launches; under any other
/// key, or while it loads or failed, they keep their rows until it returns.
class ProjectLaunchRowsCubit({
  required final SessionWindowService _window,
  required final SessionLaunchService _launchService,

  /// The rows to continue from. A surface opened from another that already
  /// draws these launches passes that one's rows, so it keeps the launching
  /// rows that one still holds after their launches have left the service.
  required final Map<String, LaunchRows> initialRows,
}) extends Cubit<Map<String, LaunchRows>> {
  late final StreamSubscription<_Update> _updates;
  late _Update _latest = (window: _window.state.value, launches: _launchService.launches.value);

  /// The window's rows on the last update that settled launches, in order;
  /// empty after one that did not.
  List<String> _listedSessionIds = const [];

  this : super(initialRows) {
    _resolve();
    // Each update as it came rather than the latest values, so a session a
    // launch names only in passing (before the launch goes) is still seen.
    _updates =
        Rx.combineLatest2(
          _window.state,
          _launchService.launches,
          (window, launches) => (window: window, launches: launches),
        ).skip(1).listen((update) {
          _latest = update;
          _resolve();
        });
  }

  void _resolve() {
    final launches = resolveSessionLaunchState(launches: _latest.launches);
    final key = _window.key;
    final sessions = switch (_latest.window) {
      SessionWindowLoaded(:final sessions, awaitingAnswer: false)
          when key.query == null && key.filter == SessionListQuickFilter.all =>
        sessions,
      // Rows narrowed from another key may lack a launch's session.
      SessionWindowLoaded() || SessionWindowLoading() || SessionWindowFailed() => null,
    };
    if (sessions == null) {
      _listedSessionIds = const [];
      emit(
        resolveProjectLaunchRows(
          previous: state,
          launches: launches,
          sessionsByProject: const {},
          appendedSessionIds: const {},
        ),
      );
      return;
    }
    // Under a project filter the other projects are not listed, so they keep
    // their rows.
    bool listed(String projectId) => key.projectId == null || key.projectId == projectId;
    final sessionsByProject = <String, List<Session>>{
      for (final projectId in {...state.keys, for (final launch in launches.launching) launch.projectId})
        if (listed(projectId)) projectId: [],
    };
    for (final session in sessions) {
      if (listed(session.projectID)) sessionsByProject.putIfAbsent(session.projectID, () => []).add(session);
    }
    final appended = _appendedSessionIds(sessions: sessions);
    _listedSessionIds = [for (final session in sessions) session.id];
    emit(
      resolveProjectLaunchRows(
        previous: state,
        launches: launches,
        sessionsByProject: sessionsByProject,
        appendedSessionIds: appended,
      ),
    );
  }

  /// The sessions listed after the last update's last row that it did not
  /// list: a page the window appended.
  Set<String> _appendedSessionIds({required List<Session> sessions}) {
    final last = _listedSessionIds.lastOrNull;
    if (last == null) return const {};
    final lastIndex = sessions.indexWhere((session) => session.id == last);
    if (lastIndex < 0) return const {};
    final known = _listedSessionIds.toSet();
    return {
      for (final session in sessions.skip(lastIndex + 1))
        if (!known.contains(session.id)) session.id,
    };
  }

  @override
  Future<void> close() async {
    await _updates.cancel();
    await super.close();
  }
}
