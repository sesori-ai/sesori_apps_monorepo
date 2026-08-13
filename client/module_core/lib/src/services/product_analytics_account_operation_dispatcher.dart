final class ProductAnalyticsAccountOperationDispatcher() {
  ({int generation, Future<void> future})? _active;

  Future<void> run({
    required int generation,
    required bool Function() isCurrent,
    required Future<void> Function() operation,
  }) {
    final active = _active;
    final previous = active != null && active.generation == generation ? active.future : null;
    final future = () async {
      if (previous != null) {
        try {
          await previous;
        } on Object {
          // The prior caller owns its surfaced failure. A later explicit action
          // must still be allowed to recover this account generation.
        }
      }
      if (!isCurrent()) return;
      await operation();
    }();
    _active = (generation: generation, future: future);
    return future.whenComplete(() {
      if (identical(_active?.future, future)) _active = null;
    });
  }

  Future<void> awaitLatest({required int generation}) async {
    while (true) {
      final active = _active;
      if (active == null || active.generation != generation) return;
      try {
        await active.future;
      } on Object {
        // The operation's caller owns its surfaced failure. Logout preparation
        // still needs to inspect any newer disable queued behind that failure.
      }
      if (identical(active.future, _active?.future)) return;
    }
  }

  void reset() => _active = null;
}
