import "dart:async";
import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

class BridgeShutdownCoordinator {
  final List<FutureOr<void> Function()> _disposables = <FutureOr<void> Function()>[];
  Future<void>? _activeShutdown;

  void add({required FutureOr<void> Function() disposable}) {
    _disposables.add(disposable);
  }

  Future<void> shutdown() {
    return _activeShutdown ??= _shutdownInternal();
  }

  Future<void> _shutdownInternal() async {
    final safetyTimer = Timer(const Duration(seconds: 10), () {
      Log.e("Failed to finish gracefully");
      exit(0);
    });

    try {
      await Future.wait(
        _disposables.map((disposable) => Future.value(disposable())),
      ).timeout(const Duration(seconds: 15));
    } finally {
      safetyTimer.cancel();
    }
  }
}
