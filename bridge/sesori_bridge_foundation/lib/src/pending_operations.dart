import "dart:async";

/// Tracks in-flight fire-and-forget work so shutdown can wait for it.
///
/// Eleven places in the bridge and its plugins hand-rolled the same three
/// lines — a `Set<Future<void>>`, a `whenComplete` that removes the entry, and
/// a `Future.wait` over a snapshot of the set — each with slightly different
/// naming and error handling. This owns that one invariant instead.
///
/// [drain] deliberately uses `Future.wait`'s default non-eager error handling:
/// it waits for **every** operation captured at call time to settle before
/// completing, then reports the first error. Failing fast would let disposal
/// close a database or stream while a tracked write is still running, which is
/// the situation the hand-rolled copies were guarding against.
///
/// Operations started after [drain] is called are not awaited by that call, so
/// callers that must admit no further work should fence their producer first.
class PendingOperations() {
  final Set<Future<void>> _operations = <Future<void>>{};

  /// Registers [operation] and removes it once it settles.
  ///
  /// Returns the same future so a caller can still `await` or `unawaited` it.
  Future<void> track({required Future<void> operation}) {
    _operations.add(operation);
    unawaited(operation.whenComplete(() => _operations.remove(operation)));
    return operation;
  }

  /// Whether no tracked operation is currently in flight.
  bool get isEmpty => _operations.isEmpty;

  /// How many tracked operations are currently in flight.
  int get length => _operations.length;

  /// Waits for every operation tracked at call time to settle, then rethrows
  /// the first error if any of them failed.
  Future<void> drain() => Future.wait(_operations.toList(growable: false));
}
