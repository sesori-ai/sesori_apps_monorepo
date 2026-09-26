import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;

import "../models/pi_catalog_snapshot.dart";

class PiCatalogTracker() {
  final Map<String, PiCatalogSnapshot> _snapshots = {};

  PiCatalogSnapshot? snapshotFor({required String projectId}) =>
      _snapshots[normalizeProjectDirectory(directory: projectId)];

  void replace({required String projectId, required PiCatalogSnapshot snapshot}) {
    _snapshots[normalizeProjectDirectory(directory: projectId)] = snapshot;
  }
}
