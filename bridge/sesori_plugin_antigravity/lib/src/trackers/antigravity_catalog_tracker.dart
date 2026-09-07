import "../models/antigravity_model_catalog.dart";

/// Process-scoped last-good catalog. Only the options service validates and replaces it.
class AntigravityCatalogTracker() {
  AntigravityModelCatalog? _snapshot;

  AntigravityModelCatalog? get snapshot => _snapshot;

  void storeValidated({required AntigravityModelCatalog catalog}) => _snapshot = catalog;
}
