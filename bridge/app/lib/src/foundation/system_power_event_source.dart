import "dart:async";
import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "macos_system_power_observer_api.dart";

sealed class SystemPowerEventSource() {
  factory forPlatform({
    required String operatingSystem,
    required MacosSystemPowerObserverApi macosApi,
  }) => operatingSystem == "macos" ? _MacosSystemPowerEventSource(api: macosApi) : _UnsupportedSystemPowerEventSource();

  Stream<BridgeConnectionNotificationPolicy> get policies;
  void start();
  Future<void> dispose();
}

final class _UnsupportedSystemPowerEventSource() implements SystemPowerEventSource {
  @override
  Stream<BridgeConnectionNotificationPolicy> get policies => const Stream.empty();

  @override
  void start() {
    Log.d("System power detection unsupported on ${Platform.operatingSystem}; using conservative notifications");
  }

  @override
  Future<void> dispose() async {}
}

final class _MacosSystemPowerEventSource({required final MacosSystemPowerObserverApi api})
    implements SystemPowerEventSource {
  final MacosSystemPowerObserverApi _api = api;
  final StreamController<BridgeConnectionNotificationPolicy> _controller = StreamController.broadcast();
  bool _started = false;
  BridgeConnectionNotificationPolicy _policy = BridgeConnectionNotificationPolicy.conservative;
  bool _disposed = false;

  @override
  Stream<BridgeConnectionNotificationPolicy> get policies => _controller.stream;

  @override
  void start() {
    if (_disposed || _started) return;
    try {
      _api.start(callback: _handleNativeEvent);
      _started = true;
    } on Object catch (error, stackTrace) {
      Log.w("macOS system power detection failed to start; using conservative notifications", error, stackTrace);
    }
  }

  void _handleNativeEvent(int event, int errorCode) {
    if (_disposed) return;
    switch (event) {
      case 0:
        Log.d("macOS system power detection active");
      case 1:
        _publish(BridgeConnectionNotificationPolicy.suppress);
      case 2:
        _publish(BridgeConnectionNotificationPolicy.normal);
      case 3:
        Log.w("macOS system power detection failed; using conservative notifications (code=$errorCode)");
        _publish(BridgeConnectionNotificationPolicy.conservative);
    }
  }

  void _publish(BridgeConnectionNotificationPolicy policy) {
    if (_policy == policy) return;
    _policy = policy;
    _controller.add(policy);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (_started) {
      _started = false;
      try {
        _api.stop();
      } on Object catch (error, stackTrace) {
        Log.w("Failed to stop macOS system power detector", error, stackTrace);
      }
    }
    await _controller.close();
  }
}
