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
    final state = await _repository.readBridgeDesiredState() ?? BridgeProcessDesiredState.off;
    return generation == _restoreGeneration ? state : null;
  }

  /// Admits the first-run default only while no explicit intent supersedes it.
  /// Reuses the desired-state write queue so a later Off always wins on disk.
  Future<bool> initializeFirstRunBridgeState() {
    // An explicit intent remains authoritative even when its disk write fails.
    if (_restoreGeneration != 0) return Future.value(false);
    final operation = _initializeFirstRunBridgeStateAfter(
      previousWrite: _pendingDesiredStateWrite,
      generation: _restoreGeneration,
    );
    _pendingDesiredStateWrite = _observeDesiredStateWrite(operation: operation.then((_) {}));
    return operation;
  }

  Future<bool> _initializeFirstRunBridgeStateAfter({
    required Future<void> previousWrite,
    required int generation,
  }) async {
    await previousWrite;
    final persisted = await _repository.readBridgeDesiredState();
    if (persisted != null || generation != _restoreGeneration) return false;
    await _repository.writeBridgeDesiredState(state: BridgeProcessDesiredState.on);
    return generation == _restoreGeneration;
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
