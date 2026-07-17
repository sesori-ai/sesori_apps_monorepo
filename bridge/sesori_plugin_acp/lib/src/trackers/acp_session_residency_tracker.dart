class AcpSessionResidencyTracker {
  final Set<String> _residentSessions = {};
  final Set<String> _suppressedSessions = {};
  final Map<String, int> _suppressedReplayCounts = {};

  bool isResident(String sessionId) => _residentSessions.contains(sessionId);

  void markResident(String sessionId) => _residentSessions.add(sessionId);

  bool isSuppressed(String sessionId) => _suppressedSessions.contains(sessionId);

  void beginReplaySuppression(String sessionId) {
    _suppressedSessions.add(sessionId);
    _suppressedReplayCounts.remove(sessionId);
  }

  void recordSuppressedReplay(String sessionId) {
    _suppressedReplayCounts[sessionId] = (_suppressedReplayCounts[sessionId] ?? 0) + 1;
  }

  int replayCount(String sessionId) => _suppressedReplayCounts[sessionId] ?? 0;

  void endReplaySuppression(String sessionId) {
    _suppressedSessions.remove(sessionId);
    _suppressedReplayCounts.remove(sessionId);
  }

  void forgetSession(String sessionId) {
    _residentSessions.remove(sessionId);
    endReplaySuppression(sessionId);
  }

  void resetConnection() {
    _residentSessions.clear();
    _suppressedSessions.clear();
    _suppressedReplayCounts.clear();
  }
}
