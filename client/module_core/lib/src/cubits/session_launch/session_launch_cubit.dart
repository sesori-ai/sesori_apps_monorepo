import "dart:async";

import "package:bloc/bloc.dart";
import "package:rxdart/rxdart.dart";

import "../../foundation/models/session_launch/session_launch.dart";
import "../../foundation/models/session_launch/session_launch_outcome.dart";
import "../../services/session_launch_service.dart";
import "session_launch_resolvers.dart";
import "session_launch_state.dart";

/// Presentation adapter for the launches every session list draws a
/// launching row for, provided for the app's lifetime on each shell.
class SessionLaunchCubit({required final SessionLaunchService _launchService}) extends Cubit<SessionLaunchState> {
  late final StreamSubscription<List<SessionLaunch>> _launches;

  this : super(resolveSessionLaunchState(launches: _launchService.launches.value)) {
    _launches = _launchService.launches
        .skip(1)
        .listen((launches) => emit(resolveSessionLaunchState(launches: launches)));
  }

  /// Creations that failed after the user left their composer, so nothing
  /// restored them; the shell tells the user once for each.
  Stream<SessionLaunchFailedAfterLeaving> get failuresAfterLeaving =>
      _launchService.outcomes.whereType<SessionLaunchFailedAfterLeaving>();

  @override
  Future<void> close() async {
    await _launches.cancel();
    await super.close();
  }
}
