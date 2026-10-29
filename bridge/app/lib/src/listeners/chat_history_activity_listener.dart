import "dart:async";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";

import "../repositories/catalog_import_repository.dart";
import "../services/chat_history_service.dart";

/// Feeds backend activity observed by a catalog import into the history
/// store's staleness marks, so a session advanced through the backend's own
/// CLI is re-read from the backend on next open.
class ChatHistoryActivityListener({
  required final Stream<List<SessionBackendActivity>> _source,
  required final ChatHistoryService _chatHistoryService,
}) {
  StreamSubscription<List<SessionBackendActivity>>? _subscription;
  final PendingOperations _pendingWrites = PendingOperations();
  Future<void>? _disposeFuture;
  bool _disposed = false;

  void start() {
    if (_subscription != null || _disposed) return;
    // The source only ever emits; import failures surface through the
    // import's own consumers, so there is no error path to handle here.
    _subscription = _source.listen(
      (activity) => _track(write: _chatHistoryService.observeBackendActivity(activity: activity)),
    );
  }

  /// Keeps the write observable to [dispose], so shutdown does not close the
  /// database out from under an in-flight staleness update.
  void _track({required Future<void> write}) {
    unawaited(_pendingWrites.track(operation: write));
  }

  /// Memoized so a second caller joins the same drain instead of returning
  /// while writes are still running.
  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    await _subscription?.cancel();
    // observeBackendActivity never throws: each failure is logged and skipped.
    await _pendingWrites.drain();
  }
}
