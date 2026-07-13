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
    if (_status.isClosed) {
      return;
    }
    _status.add(status.copyWith(helperOnline: true));
  }

  /// The helper's control socket dropped: its last-known status is stale, so
  /// reset to the offline baseline — but retain [BridgeControlStatus.bridgeId]
  /// (ADR A13: the offline-unregister fallback needs the id exactly when the
  /// helper is gone).
  void markHelperDisconnected() {
    if (_status.isClosed) {
      return;
    }
    _status.add(BridgeControlStatus.offline.copyWith(bridgeId: status.bridgeId));
  }

  /// A `status` push from the helper.
  ///
  /// Ignored while no helper is online. The dispatcher consumes one ordered
  /// event stream, so live frames cannot be dropped by this guard — it is
  /// defense-in-depth against an out-of-order writer applying a stale frame
  /// onto an offline snapshot.
  void applyStatus({required ControlStatus status}) {
    if (_status.isClosed || !this.status.helperOnline) {
      return;
    }
    _status.add(
      this.status.copyWith(
        relay: status.relay,
        plugin: status.plugin,
        activeSessionCount: status.activeSessionCount,
      ),
    );
  }

  /// The helper registered itself and announced its bridge id.
  ///
  /// Deliberately NOT gated on `helperOnline`: the id is retained across
  /// disconnects anyway, and a late-processed `registered` frame carries
  /// exactly the value worth keeping.
  void handleRegistered({required String bridgeId}) {
    if (_status.isClosed) {
      return;
    }
    _status.add(status.copyWith(bridgeId: bridgeId));
  }

  @disposeMethod
  void dispose() {
    _status.close();
  }
}
