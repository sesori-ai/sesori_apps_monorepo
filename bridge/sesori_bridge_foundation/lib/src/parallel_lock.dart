import "dart:async" show Completer, FutureOr, unawaited;
import "dart:collection" show Queue;

import "pending_operations.dart";

/// Runs at most [maxParallelOperations] callbacks at once in FIFO order.
final class ParallelLock({required int maxParallelOperations}) {
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();
  int _availablePermits = _validateMaxParallelOperations(maxParallelOperations);
  final PendingOperations _pending = PendingOperations();

  static int _validateMaxParallelOperations(int maxParallelOperations) {
    if (maxParallelOperations < 1) {
      throw ArgumentError.value(maxParallelOperations, "maxParallelOperations", "must be positive");
    }
    return maxParallelOperations;
  }

  /// Completes once every operation accepted before this call has settled,
  /// whether it succeeded or failed. Operations submitted later are not awaited.
  Future<void> get idle => _pending.drain();

  /// Queues [operation] synchronously — before this call returns it is already
  /// covered by [idle] and holds its FIFO position — then runs it once a permit
  /// is free. The lane is released whether [operation] succeeds or throws.
  Future<T> use<T>({required FutureOr<T> Function() operation}) async {
    final completed = Completer<void>();
    unawaited(_pending.track(operation: completed.future));
    await _acquire();
    try {
      return await operation();
    } finally {
      _release();
      completed.complete();
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

/// Runs callbacks with the same key serially while allowing different keys to run independently.
final class KeyedParallelLock<K>() {
  final Map<K, _KeyedLockEntry> _entries = {};

  Future<void> get idle => Future.wait<void>([
    for (final entry in _entries.values) entry.lock.idle,
  ]);

  Future<void> idleFor({required K key}) => _entries[key]?.lock.idle ?? Future<void>.value();

  Future<T> use<T>({required K key, required FutureOr<T> Function() operation}) {
    final entry = _entries.putIfAbsent(key, _KeyedLockEntry.new);
    entry.users++;
    return entry.lock.use(operation: operation).whenComplete(() {
      if (--entry.users == 0) _entries.remove(key);
    });
  }
}

final class _KeyedLockEntry() {
  final ParallelLock lock = ParallelLock(maxParallelOperations: 1);
  int users = 0;
}
