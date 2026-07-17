/// Tracks which threads the current app-server process has loaded in memory.
class CodexThreadResidencyTracker {
  final Set<String> _loadedThreadIds = {};

  bool isLoaded({required String threadId}) => _loadedThreadIds.contains(threadId);

  void recordLoaded({required String threadId}) {
    _loadedThreadIds.add(threadId);
  }

  void recordUnloaded({required String threadId}) {
    _loadedThreadIds.remove(threadId);
  }
}
