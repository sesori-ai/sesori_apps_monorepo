import "package:bloc/bloc.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../services/bridge_process_service.dart";
import "../../services/bridge_process_state.dart";
import "../../trackers/bridge_status_tracker.dart";
import "local_bridge_startup_state.dart";

/// Layer-4 owner of the window in which the desktop is launching this
/// computer's bridge and the app has not reached it yet. Meanwhile a
/// bridge-offline report for this computer is a load, not a disconnection.
///
/// The supervisor's Running cannot end the window: it is published as soon as
/// the child spawns, and even a fully started bridge reaches the app only after
/// the app's own relay handshake. So the window ends when the app connects to
/// this computer, or when the supervisor reports anything but starting or
/// running: a failed start, a stop, a crash. A crash restart does not reopen
/// it, since the bridge the app had is lost.
///
/// Provided once with the app, so a bridge already starting or running when it
/// is created belongs to this launch.
class LocalBridgeStartupCubit({
  required final BridgeProcessService _processService,
  required final BridgeStatusTracker _statusTracker,
  required final ConnectionService _connectionService,
}) extends Cubit<LocalBridgeStartupState> {
  final CompositeSubscription _subscriptions = CompositeSubscription();

  /// Whether a launch is under way that the app has not reached yet.
  bool _launching = switch (_processService.state) {
    BridgeProcessStarting() || BridgeProcessRunning() => true,
    BridgeProcessStopped() ||
    BridgeProcessLoginRequired() ||
    BridgeProcessStartFailed() ||
    BridgeProcessStopping() ||
    BridgeProcessContention() ||
    BridgeProcessCrashRetryScheduled() ||
    BridgeProcessCrashGiveUp() => false,
  };

  this : super(LocalBridgeStartupState.settled) {
    _onConnectionStatus(status: _connectionService.currentStatus);
    // pairwise and skip(1): the values known now were applied above.
    _subscriptions
      ..add(
        _processService.states.pairwise().listen(
          (pair) => _onProcessState(previous: pair.first, current: pair.last),
        ),
      )
      ..add(_connectionService.status.skip(1).listen((status) => _onConnectionStatus(status: status)))
      ..add(_statusTracker.statusStream.map((status) => status.bridgeId).distinct().skip(1).listen((_) => _publish()));
  }

  void _onProcessState({required BridgeProcessState previous, required BridgeProcessState current}) {
    switch (current) {
      case BridgeProcessStarting():
        if (previous is! BridgeProcessCrashRetryScheduled) _launching = true;
      case BridgeProcessRunning():
        break;
      case BridgeProcessStopped() ||
          BridgeProcessLoginRequired() ||
          BridgeProcessStartFailed() ||
          BridgeProcessStopping() ||
          BridgeProcessContention() ||
          BridgeProcessCrashRetryScheduled() ||
          BridgeProcessCrashGiveUp():
        _launching = false;
    }
    _publish();
  }

  void _onConnectionStatus({required ConnectionStatus status}) {
    if (status is ConnectionConnected && _targetsThisComputer(status: status)) _launching = false;
    _publish();
  }

  /// A connection without a target yet counts as this computer, as the
  /// computer switcher has it.
  bool _targetsThisComputer({required ConnectionStatus status}) => switch (status.targetBridgeId) {
    null => true,
    final targetId => targetId == _statusTracker.status.bridgeId,
  };

  void _publish() {
    if (isClosed) return;
    emit(
      _launching && _targetsThisComputer(status: _connectionService.currentStatus)
          ? LocalBridgeStartupState.starting
          : LocalBridgeStartupState.settled,
    );
  }

  @override
  Future<void> close() async {
    await _subscriptions.dispose();
    await super.close();
  }
}
