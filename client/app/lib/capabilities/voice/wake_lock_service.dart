import "package:flutter/foundation.dart" show visibleForTesting;
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/logging.dart";
import "package:wakelock_plus/wakelock_plus.dart";

@lazySingleton
class WakeLockService({
  @ignoreParam @visibleForTesting final Future<void> Function() _enable = WakelockPlus.enable,
  @ignoreParam @visibleForTesting final Future<void> Function() _disable = WakelockPlus.disable,
}) {
  Future<void> _operationQueue = Future<void>.value();
  int _activeLeaseCount = 0;

  WakeLockLease acquire() {
    _activeLeaseCount++;
    if (_activeLeaseCount == 1) _enqueue(_enableSafely);
    return WakeLockLease._(owner: this);
  }

  Future<void> _release({required WakeLockLease lease}) {
    if (lease._released) return Future<void>.value();
    lease._released = true;
    _activeLeaseCount--;
    if (_activeLeaseCount == 0) return _enqueue(_disableSafely);
    return Future<void>.value();
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _operationQueue.then((_) => operation());
    _operationQueue = next;
    return next;
  }

  Future<void> _enableSafely() async {
    try {
      await _enable();
    } catch (error, stackTrace) {
      logw("Failed to enable wake lock", error, stackTrace);
    }
  }

  Future<void> _disableSafely() async {
    try {
      await _disable();
    } catch (error, stackTrace) {
      logw("Failed to disable wake lock", error, stackTrace);
    }
  }
}

class WakeLockLease._({required final WakeLockService _owner}) {
  bool _released = false;

  Future<void> release() => _owner._release(lease: this);
}
