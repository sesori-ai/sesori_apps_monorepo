import "dart:async";

import "push_dispatcher.dart";

class MaintenancePushListener {
  final PushDispatcher _dispatcher;
  final Duration _maintenanceInterval;
  Timer? _timer;

  MaintenancePushListener({
    required PushDispatcher dispatcher,
    Duration maintenanceInterval = const Duration(minutes: 10),
  }) : _dispatcher = dispatcher,
       _maintenanceInterval = maintenanceInterval;

  void start() {
    _timer ??= Timer.periodic(_maintenanceInterval, (_) => runNow());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  void runNow() {
    _dispatcher.runMaintenancePass();
  }
}
