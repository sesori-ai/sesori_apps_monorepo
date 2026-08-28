import "package:injectable/injectable.dart";

import "../api/desktop_instance_api.dart";
import "../api/desktop_instance_storage.dart";
import "../foundation/bridge_process_desired_state.dart";

/// Layer-2 aggregate over instance coordination and persisted desktop state.
@lazySingleton
class DesktopInstanceRepository._create({
  required final DesktopInstanceApi _api,
  required final DesktopInstanceStorage _storage,
}) {
  new({required DesktopInstanceApi api, required DesktopInstanceStorage storage})
    : this._create(api: api, storage: storage);

  Stream<void> get focusRequests => _api.activationRequests;

  Future<bool> tryAcquirePrimary() => _api.tryAcquirePrimary();

  Future<bool> signalPrimary() => _api.signalPrimary();

  Future<BridgeProcessDesiredState> readBridgeDesiredState() => _storage.readBridgeDesiredState();

  Future<void> writeBridgeDesiredState({required BridgeProcessDesiredState state}) =>
      _storage.writeBridgeDesiredState(state: state);
}
