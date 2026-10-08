import "dart:async";

import "package:bloc/bloc.dart";

import "package:sesori_shared/sesori_shared.dart";

import "../../foundation/models/session_launch/session_launch.dart";
import "../../services/session_launch_service.dart";
import "session_launch_resolvers.dart";

/// One project session list's launching rows (see [resolveHeldLaunchSessions]),
/// carried from one update to the next. The list leads its active sessions
/// with the project's launches.
///
/// The rows are resolved on every launch update and on every list update the
/// surface passes to [updateList], so each update is seen once and a launch's
/// session is never missed.
class SessionListLaunchRowsCubit({
  required final SessionLaunchService _launchService,
  required final String _projectId,

  /// The active list's sessions in order, or null while it shows no active
  /// list (loading, failed or Archived). The surface passes each later value
  /// to [updateList].
  required var List<Session>? _activeSessions,
}) extends Cubit<LaunchRows> {
  late final StreamSubscription<List<SessionLaunch>> _updates;
  late var _launches = _launchService.launches.value;

  this : super(LaunchRows.none) {
    _resolve();
    // Each update as it came rather than the latest value, so a session a
    // launch names only in passing (before the launch goes) is still seen.
    _updates = _launchService.launches.skip(1).listen((launches) {
      _launches = launches;
      _resolve();
    });
  }

  void updateList({required List<Session>? activeSessions}) {
    _activeSessions = activeSessions;
    _resolve();
  }

  void _resolve() {
    final launches = resolveSessionLaunchState(launches: _launches);
    final launching = [
      for (final launch in launches.launching)
        if (launch.projectId == _projectId) launch,
    ];
    final sessions = _activeSessions;
    // Archived and loading keep what the active list last showed, so a session
    // that arrives meanwhile is still held on the way back, and still record
    // which session each launch created.
    if (sessions == null) {
      emit(latchLaunchSessions(previous: state, launching: launching, sessionIds: launches.sessionIds));
      return;
    }
    emit(
      resolveHeldLaunchSessions(
        previous: state,
        launching: launching,
        sessionIds: launches.sessionIds,
        sessions: sessions,
        slot: sessions,
        placedSessionIds: const {},
      ),
    );
  }

  @override
  Future<void> close() async {
    await _updates.cancel();
    await super.close();
  }
}
