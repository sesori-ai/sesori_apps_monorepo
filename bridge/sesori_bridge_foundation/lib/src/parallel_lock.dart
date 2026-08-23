import "dart:async" show Completer, FutureOr;
import "dart:collection" show Queue;

/// Runs at most [maxParallelOperations] callbacks at once in FIFO order.
final class ParallelLock({required int maxParallelOperations}) {
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();
  int _availablePermits = _validateMaxParallelOperations(maxParallelOperations);
  final Set<Future<void>> _pending = {};

  static int _validateMaxParallelOperations(int maxParallelOperations) {
    if (maxParallelOperations < 1) {
      throw ArgumentError.value(maxParallelOperations, "maxParallelOperations", "must be positive");
    }
    return maxParallelOperations;
  }

  Future<void> get idle => Future.wait<void>(_pending);

  Future<T> use<T>({required FutureOr<T> Function() operation}) {
    final completed = Completer<void>();
    _pending.add(completed.future);
    return _run(operation: operation, completed: completed);
  }

  Future<T> _run<T>({required FutureOr<T> Function() operation, required Completer<void> completed}) async {
    await _acquire();
    try {
      return await operation();
    } finally {
      _release();
      _pending.remove(completed.future);
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

  Future<T> use<T>({required K key, required Future<T> Function() operation}) {
    final entry = _entries.putIfAbsent(key, _KeyedLockEntry.new);
    entry.users++;
    return entry.lock.use(operation: operation).whenComplete(() {
      entry.users--;
      if (entry.users == 0 && identical(_entries[key], entry)) _entries.remove(key);
    });
  }
}

final class _KeyedLockEntry() {
  final ParallelLock lock = ParallelLock(maxParallelOperations: 1);
  int users = 0;
}
