abstract interface class ProjectInventoryRefreshOperation() {
  Future<ProjectInventoryRefreshResult> refreshProjectInventory();
}

final class const ProjectInventoryRefreshResult({
  required final bool succeeded,
  required final List<String> projectIds,
});

abstract interface class SessionInventoryRefreshOperation() {
  Future<bool> refreshProjects({required Iterable<String> projectIds});
}
