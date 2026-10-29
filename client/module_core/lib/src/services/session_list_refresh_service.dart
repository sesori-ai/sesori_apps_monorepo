import "dart:async";

import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";

import "../logging/logging.dart";
import "catalog_rescan_service.dart";
import "models/catalog_rescan_state.dart";
import "project_inventory_service.dart";
import "session_window_service.dart";

/// A session list's manual refresh: reloads the scope's projects and the
/// list's sessions window, and imports from every harness.
///
/// Only a manual refresh imports. Automatic reloads go straight to the
/// inventory and the window and never reach this.
@injectable
class SessionListRefreshService({
  @factoryParam required final ProjectInventoryService _projectInventory,
  @factoryParam required final SessionWindowService _window,
  required final CatalogRescanService _catalogRescanService,
}) {
  /// The import a refresh starts, for the scan row.
  ValueStream<CatalogRescanState> get scan => _catalogRescanService.state;

  /// Whether the reload succeeded. The import reports through [scan] instead,
  /// because it outlives the reload.
  Future<bool> refresh() async {
    unawaited(_catalogRescanService.startAll());
    try {
      final projectsUpdated = await _projectInventory.refreshProjects();
      // Ordinary API failure still permits the sessions; unexpected throws abort.
      final sessionsUpdated = await _window.reload();
      return projectsUpdated && sessionsUpdated;
    } on Object catch (error, stackTrace) {
      loge("Explicit session list refresh failed unexpectedly", error, stackTrace);
      return false;
    }
  }
}
