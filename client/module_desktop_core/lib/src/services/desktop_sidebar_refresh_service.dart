import "package:sesori_dart_core/sesori_dart_core.dart";

abstract interface class DesktopSidebarRefreshOperation() {
  Future<DesktopSidebarRefreshResult> refresh();
}

/// Coordinates the two independent inventories behind one sidebar refresh.
final class DesktopSidebarRefreshService._create({
  required final ProjectInventoryRefreshOperation _projectInventory,
  required final SessionInventoryRefreshOperation _sessionInventory,
}) implements DesktopSidebarRefreshOperation {
  new({
    required ProjectInventoryRefreshOperation projectInventory,
    required SessionInventoryRefreshOperation sessionInventory,
  }) : this._create(projectInventory: projectInventory, sessionInventory: sessionInventory);

  @override
  Future<DesktopSidebarRefreshResult> refresh() async {
    try {
      final projects = await _projectInventory.refreshProjectInventory();
      final sessionsSucceeded = await _sessionInventory.refreshProjects(projectIds: projects.projectIds);
      return projects.succeeded && sessionsSucceeded
          ? DesktopSidebarRefreshResult.succeeded
          : DesktopSidebarRefreshResult.failed;
    } on Object catch (error, stackTrace) {
      logw("Failed to refresh the desktop sidebar", error, stackTrace);
      return DesktopSidebarRefreshResult.failed;
    }
  }
}

enum DesktopSidebarRefreshResult() {
  succeeded,
  failed,
}
