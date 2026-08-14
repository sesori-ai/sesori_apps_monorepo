import "dart:async" show Completer, FutureOr;
import "dart:collection" show Queue;

/// Runs at most [maxParallelOperations] callbacks at once in FIFO order.
final class ParallelLock({required int maxParallelOperations}) {
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();
  int _availablePermits = _validateMaxParallelOperations(maxParallelOperations);

  static int _validateMaxParallelOperations(int maxParallelOperations) {
    if (maxParallelOperations < 1) {
      throw ArgumentError.value(maxParallelOperations, "maxParallelOperations", "must be positive");
    }
    return maxParallelOperations;
  }

  Future<T> use<T>({required FutureOr<T> Function() operation}) async {
    await _acquire();
    try {
      return await operation();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() async {
    if (_availablePermits > 0) {
      _availablePermits--;
      return;
    }

    final waiter = Completer<void>();
    _waiters.addLast(waiter);
    await waiter.future;
  }

  void _release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
      return;
    }
    _availablePermits++;
  }
}
