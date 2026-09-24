import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

enum DesktopSidebarRefreshOutcome() {
  succeeded,
  failed,
}

/// Explicit sidebar refresh over the cockpit's existing scoped inventories.
@injectable
class DesktopSidebarRefreshService({
  @factoryParam required final ProjectInventoryService _projectInventory,
  @factoryParam required final RecentSessionInventoryService _recentInventory,
}) {
  Future<DesktopSidebarRefreshOutcome> refresh() async {
    try {
      final projectsUpdated = await _projectInventory.refreshProjects();
      // Ordinary API failure still permits recent work; unexpected throws abort.
      final sessionsUpdated = await _recentInventory.refresh();
      return projectsUpdated && sessionsUpdated
          ? DesktopSidebarRefreshOutcome.succeeded
          : DesktopSidebarRefreshOutcome.failed;
    } on Object catch (error, stackTrace) {
      loge("Explicit desktop sidebar refresh failed unexpectedly", error, stackTrace);
      return DesktopSidebarRefreshOutcome.failed;
    }
  }
}
