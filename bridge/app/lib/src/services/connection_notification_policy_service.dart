import "dart:async";

import "package:sesori_shared/sesori_shared.dart";

import "../foundation/system_power_event_source.dart";

class ConnectionNotificationPolicyService({required final SystemPowerEventSource powerEventSource}) {
  final SystemPowerEventSource _powerEventSource = powerEventSource;
  final StreamController<BridgeConnectionNotificationPolicy> _controller = StreamController.broadcast();
  StreamSubscription<SystemPowerEvent>? _subscription;
  BridgeConnectionNotificationPolicy _policy = BridgeConnectionNotificationPolicy.conservative;
  bool _disposed = false;

  Stream<BridgeConnectionNotificationPolicy> get policies => _controller.stream;

  void start() {
    if (_disposed || _subscription != null) return;
    _subscription = _powerEventSource.events.listen(_handlePowerEvent);
    _powerEventSource.start();
  }

  void _handlePowerEvent(SystemPowerEvent event) {
    final policy = switch (event) {
      SystemPowerEvent.willSleep => BridgeConnectionNotificationPolicy.suppress,
      SystemPowerEvent.fullWake => BridgeConnectionNotificationPolicy.normal,
      SystemPowerEvent.observationFailed => BridgeConnectionNotificationPolicy.conservative,
    };
    if (_policy == policy) return;
    _policy = policy;
    _controller.add(policy);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription?.cancel();
    _subscription = null;
    await _powerEventSource.dispose();
    await _controller.close();
  }
}
