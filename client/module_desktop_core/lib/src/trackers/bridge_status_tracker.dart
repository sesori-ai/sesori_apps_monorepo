import "dart:async";

import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/bridge_id_storage.dart";
import "../api/bridge_registration_record.dart";
import "bridge_control_status.dart";

/// Holds the supervised bridge's status as stream + snapshot.
///
/// Written by the control-message dispatcher (helper lifecycle, `status` and
/// `registered` events); read by the desktop cubits/tray/window. Defaults to
/// the offline baseline before any helper connects, so the v1 UI can render
/// "bridge off" without a control channel.
@lazySingleton
class BridgeStatusTracker({required BridgeIdStorage bridgeIdStorage}) {
  final BridgeIdStorage _bridgeIdStorage = bridgeIdStorage;
  final BehaviorSubject<BridgeControlStatus> _status = BehaviorSubject.seeded(BridgeControlStatus.offline);
  final StreamController<BridgeRegistrationRecord> _registrationEvents =
      StreamController<BridgeRegistrationRecord>.broadcast(sync: true);
  Future<void>? _initialization;
  Future<void> _bridgeIdMutationTail = Future<void>.value();
  BridgeRegistrationRecord? _registeredBridge;

  ValueStream<BridgeControlStatus> get statusStream => _status.stream;

  /// Emits every registration announced by the currently supervised helper.
  /// Unlike [status], this is an event stream rather than a replayed snapshot,
  /// so a takeover coordinator can distinguish a fresh helper registration
  /// from the persisted id retained across a disconnect.
  Stream<BridgeRegistrationRecord> get registrationEvents => _registrationEvents.stream;

  BridgeControlStatus get status => _status.value;

  /// The last bridge registration observed by this desktop, including the
  /// account that owns the server-side record. It is retained while offline so
  /// logout can safely decide whether the current account may delete it.
  BridgeRegistrationRecord? get registeredBridge => _registeredBridge;

  /// Loads the last registration and owner before helper lifecycle work begins.
  /// Repeated callers share the same startup read.
  Future<void> initialize() {
    final Future<void>? existing = _initialization;
    if (existing != null) {
      return existing;
    }
    final Future<void> operation = _loadPersistedBridgeId();
    _initialization = operation;
    return operation;
  }

  Future<void> _loadPersistedBridgeId() async {
    try {
      final BridgeRegistrationRecord? registration = await _bridgeIdStorage.read();
      if (registration != null && !_status.isClosed && status.bridgeId == null) {
        _registeredBridge = registration;
        _status.add(status.copyWith(bridgeId: registration.bridgeId));
      }
    } on Object catch (error, stackTrace) {
      logw("Failed to restore the desktop bridge registration id", error, stackTrace);
    }
  }

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
  /// exactly the value worth keeping. The dispatcher supplies the currently
  /// authenticated account so an offline retry handle cannot be reused by a
  /// different account. Writes are serialized so a rapid re-registration
  /// cannot leave an older record on disk after a newer event.
  void handleRegistered({required String bridgeId, required String accountId}) {
    if (_status.isClosed) {
      return;
    }
    final BridgeRegistrationRecord registration = BridgeRegistrationRecord(
      bridgeId: bridgeId,
      accountId: accountId,
    );
    _registeredBridge = registration;
    _status.add(status.copyWith(bridgeId: bridgeId));
    _registrationEvents.add(registration);
    unawaited(
      _queueBridgeIdMutation(
        action: () => _bridgeIdStorage.write(registration: registration),
        reportFailure: true,
      ),
    );
  }

  /// Removes the persisted record after the server confirms deletion. If a
  /// newer registration arrived while the delete was in flight, its record is
  /// left untouched. The caller supplies the full record so an account mismatch
  /// cannot clear another account's retry handle.
  Future<void> clearBridgeId({required BridgeRegistrationRecord registration}) {
    return _queueBridgeIdMutation(
      action: () async {
        if (_status.isClosed || _registeredBridge != registration) {
          return;
        }
        await _bridgeIdStorage.clear();
        if (!_status.isClosed && _registeredBridge == registration) {
          _registeredBridge = null;
          _status.add(status.copyWith(bridgeId: null));
        }
      },
      reportFailure: false,
    );
  }

  Future<void> _queueBridgeIdMutation({
    required Future<void> Function() action,
    required bool reportFailure,
  }) {
    final Future<void> operation = _bridgeIdMutationTail.then((_) => action());
    _bridgeIdMutationTail = _observeBridgeIdMutation(
      operation: operation,
      reportFailure: reportFailure,
    );
    return operation;
  }

  Future<void> _observeBridgeIdMutation({
    required Future<void> operation,
    required bool reportFailure,
  }) async {
    try {
      await operation;
    } on Object catch (error, stackTrace) {
      if (reportFailure) {
        logw("Failed to persist the desktop bridge registration id", error, stackTrace);
      }
    }
  }

  @disposeMethod
  Future<void> dispose() async {
    await _status.close();
    await _registrationEvents.close();
  }
}
