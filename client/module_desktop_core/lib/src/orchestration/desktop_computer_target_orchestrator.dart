import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../trackers/bridge_status_tracker.dart";

/// Layer-4 owner of which computer the desktop works on by default: its own.
///
/// At start-up the stored pick wins, else this computer's supervised bridge is
/// pinned. Afterwards, whenever the supervised bridge's id appears or changes
/// (a fresh install, a new login, or a re-registration), the app follows it,
/// unless the user has picked another computer in this sign-in. Without that
/// the connection would keep the relay's default computer or an id that is
/// gone. A sign-out forgets the pick.
@lazySingleton
class DesktopComputerTargetOrchestrator({
  required final BridgeStatusTracker _statusTracker,
  required final SelectedComputerService _selectedComputerService,
  required final AuthSession _authSession,
}) {
  StreamSubscription<String?>? _localIdSubscription;
  StreamSubscription<AuthState>? _authSubscription;

  /// Call once the status tracker holds the persisted bridge id (the control
  /// dispatcher has started) and before the relay connects.
  Future<void> start() async {
    // The tracker's id does not reliably clear at sign-out (it stays when the
    // server could not unregister the bridge), so the auth state marks it. A
    // sign-out also clears the stored target, so each sign-in pins this
    // computer again; the stored target makes that a no-op otherwise.
    // skip(1): the state known now is the start-up one resolved below.
    _authSubscription = _authSession.authStateStream.skip(1).listen((state) {
      switch (state) {
        case AuthUnauthenticated():
          _selectedComputerService.forgetPick();
        case AuthAuthenticated():
          unawaited(_selectedComputerService.ensureInitialTarget(localBridgeId: _statusTracker.status.bridgeId));
        case AuthInitial() || AuthAuthenticating() || AuthFailed():
          break;
      }
    });
    // skip(1): the id known now is the one ensureInitialTarget uses.
    _localIdSubscription = _statusTracker.statusStream
        .map((status) => status.bridgeId)
        .distinct()
        .skip(1)
        .listen(_followLocalComputer);
    await _selectedComputerService.ensureInitialTarget(localBridgeId: _statusTracker.status.bridgeId);
  }

  void _followLocalComputer(String? bridgeId) {
    // A cleared id (logout) leaves the target to the logout's own reset.
    if (bridgeId == null) return;
    unawaited(_selectedComputerService.followLocalComputer(bridgeId: bridgeId));
  }

  @disposeMethod
  Future<void> dispose() async {
    await _localIdSubscription?.cancel();
    await _authSubscription?.cancel();
  }
}
