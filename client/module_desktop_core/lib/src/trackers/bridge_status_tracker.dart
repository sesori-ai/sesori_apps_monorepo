import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_shared/sesori_shared.dart";

import "bridge_control_status.dart";

/// Holds the supervised bridge's status as stream + snapshot.
///
/// Written by the control-message dispatcher (helper lifecycle, `status` and
/// `registered` events); read by the desktop cubits/tray/window. Defaults to
/// the offline baseline before any helper connects, so the v1 UI can render
/// "bridge off" without a control channel.
@lazySingleton
class BridgeStatusTracker {
  final BehaviorSubject<BridgeControlStatus> _status = BehaviorSubject.seeded(BridgeControlStatus.offline);

  ValueStream<BridgeControlStatus> get statusStream => _status.stream;

  BridgeControlStatus get status => _status.value;

  /// A helper completed the control-channel handshake. Health/relay fields
  /// keep their current values until the helper's first `status` push lands.
  void markHelperConnected() {
    _status.add(status.copyWith(helperOnline: true));
  }

  /// The helper's control socket dropped: its last-known status is stale, so
  /// reset to the offline baseline — but retain [BridgeControlStatus.bridgeId]
  /// (ADR A13: the offline-unregister fallback needs the id exactly when the
  /// helper is gone).
  void markHelperDisconnected() {
    _status.add(BridgeControlStatus.offline.copyWith(bridgeId: status.bridgeId));
  }

  /// A `status` push from the helper.
  void applyStatus({required ControlStatus status}) {
    _status.add(
      this.status.copyWith(
        relay: status.relay,
        plugin: status.plugin,
        activeSessionCount: status.activeSessionCount,
      ),
    );
  }

  /// The helper registered itself and announced its bridge id.
  void handleRegistered({required String bridgeId}) {
    _status.add(status.copyWith(bridgeId: bridgeId));
  }

  @disposeMethod
  void dispose() {
    _status.close();
  }
}
