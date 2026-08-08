import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../bridge/repositories/session_repository.dart";
import "../bridge/services/chat_history_service.dart";

/// Feeds backend activity observed by catalog import into the history store's
/// staleness marks, so a session advanced through the backend's own CLI is
/// re-read from the backend on next open.
class ChatHistoryActivityListener {
  final Stream<List<SessionBackendActivity>> _source;
  final ChatHistoryService _chatHistoryService;
  StreamSubscription<List<SessionBackendActivity>>? _subscription;
  bool _disposed = false;

  ChatHistoryActivityListener({
    required Stream<List<SessionBackendActivity>> source,
    required ChatHistoryService chatHistoryService,
  }) : _source = source,
       _chatHistoryService = chatHistoryService;

  void start() {
    if (_subscription != null || _disposed) return;
    _subscription = _source.listen(
      (activity) => unawaited(_record(activity: activity)),
      // Import failures are surfaced by the import's own consumers; there is
      // simply no activity to record for a failed observation.
      onError: (Object _) {},
    );
  }

  Future<void> _record({required List<SessionBackendActivity> activity}) async {
    for (final observed in activity) {
      try {
        await _chatHistoryService.observeBackendActivity(
          sessionId: observed.sessionId,
          activityAt: observed.activityAt,
        );
      } on Object catch (error, stackTrace) {
        // A missed observation only costs a redundant plugin fetch later.
        Log.w(
          "Failed to record backend activity for session ${observed.sessionId}",
          error,
          stackTrace,
        );
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription?.cancel();
  }
}
