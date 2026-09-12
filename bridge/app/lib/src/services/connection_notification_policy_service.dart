import "dart:async";

import "package:rxdart/rxdart.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/system_power_event_repository.dart";

class ConnectionNotificationPolicyService({required final SystemPowerEventRepository powerEventRepository}) {
  final SystemPowerEventRepository _powerEventRepository = powerEventRepository;
  // Composition can subscribe after native observation has already started.
  final BehaviorSubject<BridgeConnectionNotificationPolicy> _controller = BehaviorSubject.seeded(
    BridgeConnectionNotificationPolicy.conservative,
  );
  StreamSubscription<SystemPowerEvent>? _subscription;
  bool _disposed = false;

  Stream<BridgeConnectionNotificationPolicy> get policies => _controller.stream;

  void start() {
    if (_disposed || _subscription != null) return;
    _subscription = _powerEventRepository.events.listen(_handlePowerEvent);
    _powerEventRepository.start();
  }

  void _handlePowerEvent(SystemPowerEvent event) {
    final policy = switch (event) {
      SystemPowerEvent.willSleep => BridgeConnectionNotificationPolicy.suppress,
      SystemPowerEvent.fullWake => BridgeConnectionNotificationPolicy.normal,
      SystemPowerEvent.observationFailed => BridgeConnectionNotificationPolicy.conservative,
    };
    if (_controller.value == policy) return;
    _controller.add(policy);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription?.cancel();
    _subscription = null;
    await _powerEventRepository.dispose();
    await _controller.close();
  }
}
