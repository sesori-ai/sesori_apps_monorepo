import "dart:async";

/// In-memory, connection-scoped record of which session each phone connection
/// is currently viewing (the session detail screen). The viewer set is GLOBAL
/// (per-user): if ANY connection views a session, it is considered actively
/// watched and must not bold for anyone.
///
/// Owned as a single shared instance at the composition root: the orchestrator
/// writes to it (setViewing / releaseConnection on RelaySessionView and
/// disconnect), and [SessionUnseenService] reads it ([isViewed]) and listens to
/// [viewStarts] to mark sessions seen on open.
class SessionViewTracker {
  // connID -> the session that connection is currently viewing.
  final Map<int, String> _viewedByConnection = {};
  // sessionId -> count of connections currently viewing it.
  final Map<String, int> _viewerCountBySession = {};

  final StreamController<String> _viewStarts = StreamController<String>.broadcast();

  /// Emits a sessionId each time a connection starts viewing it (so the unseen
  /// service can stamp it seen).
  Stream<String> get viewStarts => _viewStarts.stream;

  /// Declares that [connID] is now viewing [sessionId] (or nothing when null).
  /// Idempotent full-state declaration: replacing one viewed session with
  /// another updates both counts.
  void setViewing({required int connID, required String? sessionId}) {
    final previous = _viewedByConnection[connID];
    if (previous == sessionId) return;

    if (previous != null) {
      _decrement(previous);
    }

    if (sessionId == null) {
      _viewedByConnection.remove(connID);
      return;
    }

    _viewedByConnection[connID] = sessionId;
    _viewerCountBySession[sessionId] = (_viewerCountBySession[sessionId] ?? 0) + 1;
    _viewStarts.add(sessionId);
  }

  /// Releases any session [connID] was viewing (phone disconnected / relay drop).
  void releaseConnection({required int connID}) {
    final previous = _viewedByConnection.remove(connID);
    if (previous != null) {
      _decrement(previous);
    }
  }

  /// Releases ALL viewers (e.g. the relay connection dropped). Phones re-assert
  /// their current view on reconnect.
  void clearAll() {
    _viewedByConnection.clear();
    _viewerCountBySession.clear();
  }

  /// Whether [sessionId] is currently being viewed by at least one connection.
  bool isViewed({required String sessionId}) => (_viewerCountBySession[sessionId] ?? 0) > 0;

  void _decrement(String sessionId) {
    final next = (_viewerCountBySession[sessionId] ?? 0) - 1;
    if (next <= 0) {
      _viewerCountBySession.remove(sessionId);
    } else {
      _viewerCountBySession[sessionId] = next;
    }
  }

  Future<void> dispose() async {
    await _viewStarts.close();
  }
}
