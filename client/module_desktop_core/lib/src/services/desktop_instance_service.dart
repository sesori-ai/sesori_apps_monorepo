import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../foundation/bridge_process_desired_state.dart";
import "../repositories/desktop_instance_repository.dart";

/// Result of the Layer-3 ownership decision for this desktop launch.
enum DesktopInstanceLaunchDisposition() {
  primary,
  secondaryActivated,
  secondaryActivationFailed,
}

/// Layer-3 desktop instance ownership and last-state service.
///
/// Bridge lifecycle restoration stays in `DesktopStartupOrchestrator`; this
/// service never depends on the peer `BridgeProcessService`.
@lazySingleton
class DesktopInstanceService._create({required final DesktopInstanceRepository _repository}) {
  new({required DesktopInstanceRepository repository}) : this._create(repository: repository);

  Future<void> _pendingDesiredStateWrite = Future<void>.value();
  int _restoreGeneration = 0;

  Stream<void> get focusRequests => _repository.focusRequests;

  Future<DesktopInstanceLaunchDisposition> claimLaunch() async {
    if (await _repository.tryAcquirePrimary()) {
      return DesktopInstanceLaunchDisposition.primary;
    }
    if (await _repository.signalPrimary()) {
      return DesktopInstanceLaunchDisposition.secondaryActivated;
    }
    // The owner may have exited while this launch was trying to signal it.
    // One fresh lock attempt provides stale-lock recovery without allowing two
    // live owners when the activation channel itself is unhealthy.
    if (await _repository.tryAcquirePrimary()) {
      return DesktopInstanceLaunchDisposition.primary;
    }
    logw("Another desktop instance owns the lock but could not be activated");
    return DesktopInstanceLaunchDisposition.secondaryActivationFailed;
  }

  /// Reads persisted intent only while no newer user action invalidates it.
  Future<BridgeProcessDesiredState?> readBridgeDesiredStateForRestore() async {
    final int generation = _restoreGeneration;
    final BridgeProcessDesiredState state = await _repository.readBridgeDesiredState();
    return generation == _restoreGeneration ? state : null;
  }

  /// Prevents an in-flight startup read from applying stale desired On.
  void cancelPendingBridgeRestore() {
    _restoreGeneration++;
  }

  Future<void> writeBridgeDesiredState({required BridgeProcessDesiredState state}) {
    cancelPendingBridgeRestore();
    final Future<void> previousWrite = _pendingDesiredStateWrite;
    final Future<void> operation = _writeBridgeDesiredStateAfter(
      previousWrite: previousWrite,
      state: state,
    );
    _pendingDesiredStateWrite = _observeDesiredStateWrite(operation: operation);
    return operation;
  }

  Future<void> _writeBridgeDesiredStateAfter({
    required Future<void> previousWrite,
    required BridgeProcessDesiredState state,
  }) async {
    try {
      await previousWrite;
    } on Object {
      // A failed write must not prevent the next explicit intent from being
      // persisted. The original caller retains the previous error.
    }
    await _repository.writeBridgeDesiredState(state: state);
  }

  Future<void> _observeDesiredStateWrite({required Future<void> operation}) async {
    try {
      await operation;
    } on Object {
      // The operation returned to its caller retains the persistence error.
      // This observer only leaves a completed serialization tail.
    }
  }
}
