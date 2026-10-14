import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../trackers/bridge_status_tracker.dart";

/// Layer-4 owner of which computer the desktop works on by default: its own.
///
/// At start-up the stored pick wins, else this computer's supervised bridge is
/// pinned. Afterwards, whenever the supervised bridge's id appears or changes
/// (a fresh install, a new login, or a re-registration), the app follows it,
/// unless the user has picked a computer since start-up. Without that the
/// connection would keep the relay's default computer or an id that is gone.
@lazySingleton
class DesktopComputerTargetOrchestrator({
  required final BridgeStatusTracker _statusTracker,
  required final SelectedComputerService _selectedComputerService,
}) {
  StreamSubscription<String?>? _localIdSubscription;

  /// Call once the status tracker holds the persisted bridge id (the control
  /// dispatcher has started) and before the relay connects.
  Future<void> start() async {
    // skip(1): the id known now is the one ensureInitialTarget already uses.
    _localIdSubscription = _statusTracker.statusStream
        .map((status) => status.bridgeId)
        .distinct()
        .skip(1)
        .listen(_followLocalComputer);
    await _selectedComputerService.ensureInitialTarget();
  }

  void _followLocalComputer(String? bridgeId) {
    // A cleared id (logout) leaves the target to the logout's own reset.
    if (bridgeId == null) return;
    unawaited(_selectedComputerService.followLocalComputer(bridgeId: bridgeId));
  }

  @disposeMethod
  Future<void> dispose() async {
    await _localIdSubscription?.cancel();
  }
}
