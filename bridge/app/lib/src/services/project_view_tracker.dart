import "dart:async";

/// An immutable aggregate change to the projects currently viewed by phones.
final class ProjectViewChange({
    required Set<String> activeProjectIds,
    required Set<String> newlyAddedProjectIds,
  }) {
  final Set<String> activeProjectIds;
  final Set<String> newlyAddedProjectIds;

  this : activeProjectIds = Set<String>.unmodifiable(activeProjectIds),
       newlyAddedProjectIds = Set<String>.unmodifiable(newlyAddedProjectIds);
}

/// Tracks one full-state project-view declaration per relay connection and
/// publishes only changes to their aggregate union.
class ProjectViewTracker() {
  final Map<int, String> _viewedByConnection = <int, String>{};
  final Map<String, int> _viewerCountByProject = <String, int>{};
  final StreamController<ProjectViewChange> _changes = StreamController<ProjectViewChange>.broadcast(sync: true);

  Future<void>? _disposeFuture;
  bool _disposed = false;

  Set<String> get activeProjectIds => Set<String>.unmodifiable(_viewerCountByProject.keys);
  Stream<ProjectViewChange> get changes => _changes.stream;

  /// Declares the complete project-view state for [connID]. Null and empty
  /// external identifiers both mean that the connection has no project claim.
  void setViewing({required int connID, required String? projectId}) {
    if (_disposed) return;

    final normalizedProjectId = projectId == null || projectId.isEmpty ? null : projectId;
    final previousProjectId = _viewedByConnection[connID];
    if (previousProjectId == normalizedProjectId) return;

    final previousActiveProjectIds = _viewerCountByProject.keys.toSet();
    if (previousProjectId != null) {
      _decrementViewerCount(projectId: previousProjectId);
    }

    if (normalizedProjectId == null) {
      _viewedByConnection.remove(connID);
    } else {
      _viewedByConnection[connID] = normalizedProjectId;
      _viewerCountByProject[normalizedProjectId] = (_viewerCountByProject[normalizedProjectId] ?? 0) + 1;
    }
    _emitAggregateChange(previousActiveProjectIds: previousActiveProjectIds);
  }

  void releaseConnection({required int connID}) {
    if (_disposed) return;

    final previousProjectId = _viewedByConnection.remove(connID);
    if (previousProjectId == null) return;

    final previousActiveProjectIds = _viewerCountByProject.keys.toSet();
    _decrementViewerCount(projectId: previousProjectId);
    _emitAggregateChange(previousActiveProjectIds: previousActiveProjectIds);
  }

  void clearAll() {
    if (_disposed || _viewerCountByProject.isEmpty) return;

    final previousActiveProjectIds = _viewerCountByProject.keys.toSet();
    _viewedByConnection.clear();
    _viewerCountByProject.clear();
    _emitAggregateChange(previousActiveProjectIds: previousActiveProjectIds);
  }

  void _decrementViewerCount({required String projectId}) {
    final nextViewerCount = (_viewerCountByProject[projectId] ?? 0) - 1;
    if (nextViewerCount <= 0) {
      _viewerCountByProject.remove(projectId);
    } else {
      _viewerCountByProject[projectId] = nextViewerCount;
    }
  }

  void _emitAggregateChange({required Set<String> previousActiveProjectIds}) {
    final activeProjectIds = _viewerCountByProject.keys.toSet();
    if (activeProjectIds.length == previousActiveProjectIds.length &&
        activeProjectIds.containsAll(previousActiveProjectIds)) {
      return;
    }

    _changes.add(
      ProjectViewChange(
        activeProjectIds: activeProjectIds,
        newlyAddedProjectIds: activeProjectIds.difference(previousActiveProjectIds),
      ),
    );
  }

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    _viewedByConnection.clear();
    _viewerCountByProject.clear();
    await _changes.close();
  }
}
