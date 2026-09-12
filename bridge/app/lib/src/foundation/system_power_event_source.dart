import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "macos_system_power_observer_api.dart";

enum SystemPowerEvent() {
  willSleep,
  fullWake,
  observationFailed,
}

sealed class SystemPowerEventSource() {
  factory forPlatform({
    required String operatingSystem,
    required MacosSystemPowerObserverApi macosApi,
  }) => operatingSystem == "macos"
      ? _MacosSystemPowerEventSource(api: macosApi)
      : _UnsupportedSystemPowerEventSource(operatingSystem: operatingSystem);

  Stream<SystemPowerEvent> get events;
  void start();
  Future<void> dispose();
}

final class _UnsupportedSystemPowerEventSource({required final String operatingSystem})
    implements SystemPowerEventSource {
  final String _operatingSystem = operatingSystem;

  @override
  Stream<SystemPowerEvent> get events => const Stream.empty();

  @override
  void start() {
    Log.d("System power detection unsupported on $_operatingSystem");
  }

  @override
  Future<void> dispose() async {}
}

final class _MacosSystemPowerEventSource({required final MacosSystemPowerObserverApi api})
    implements SystemPowerEventSource {
  final MacosSystemPowerObserverApi _api = api;
  final StreamController<SystemPowerEvent> _controller = StreamController.broadcast();
  bool _started = false;
  bool _disposed = false;

  @override
  Stream<SystemPowerEvent> get events => _controller.stream;

  @override
  void start() {
    if (_disposed || _started) return;
    try {
      _api.start(callback: _handleNativeEvent);
      _started = true;
    } on Object catch (error, stackTrace) {
      Log.w("macOS system power detection failed to start", error, stackTrace);
      _controller.add(SystemPowerEvent.observationFailed);
    }
  }

  void _handleNativeEvent(int event, int errorCode) {
    if (_disposed) return;
    switch (event) {
      case 0:
        Log.d("macOS system power detection active");
      case 1:
        _controller.add(SystemPowerEvent.willSleep);
      case 2:
        _controller.add(SystemPowerEvent.fullWake);
      case 3:
        Log.w("macOS system power detection failed (code=$errorCode)");
        _controller.add(SystemPowerEvent.observationFailed);
    }
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
