import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

abstract interface class DesktopSidebarRefreshOperation() {
  Future<DesktopSidebarRefreshResult> refresh();
}

/// Coordinates the two independent inventories behind one sidebar refresh.
@lazySingleton
class DesktopSidebarRefreshService({
  required final InventoryRefreshService inventoryRefreshService,
}) implements DesktopSidebarRefreshOperation {
  final InventoryRefreshService _inventoryRefreshService = inventoryRefreshService;

  @override
  Future<DesktopSidebarRefreshResult> refresh() async {
    try {
      final projects = await _inventoryRefreshService.refreshProjectInventory();
      final sessionsSucceeded = await _inventoryRefreshService.refreshSessionInventories(
        projectIds: projects.projectIds,
      );
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
