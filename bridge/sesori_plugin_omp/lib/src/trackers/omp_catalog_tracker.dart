import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;

import "../models/omp_catalog_models.dart";

/// Owns OMP's last coherent catalog independently for each project.
class OmpCatalogTracker() {
  final Map<String, OmpProjectCatalog> _catalogs = {};

  OmpProjectCatalog? snapshotFor({required String projectId}) =>
      _catalogs[normalizeProjectDirectory(directory: projectId)];

  void replace({required String projectId, required OmpProjectCatalog catalog}) {
    _catalogs[normalizeProjectDirectory(directory: projectId)] = catalog;
  }
}
