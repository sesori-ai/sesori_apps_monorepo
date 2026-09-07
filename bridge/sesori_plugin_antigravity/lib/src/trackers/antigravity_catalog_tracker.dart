import "../models/antigravity_model_catalog.dart";

/// Process-scoped last-good catalog. Only the options service validates and replaces it.
class AntigravityCatalogTracker() {
  ({AntigravityModelCatalog catalog, String? newSessionDefaultModelId})? _state;

  AntigravityModelCatalog? get snapshot => _state?.catalog;
  String? get newSessionDefaultModelId => _state?.newSessionDefaultModelId;

  void storeValidated({required AntigravityModelCatalog catalog, required String? newSessionDefaultModelId}) =>
      _state = (catalog: catalog, newSessionDefaultModelId: newSessionDefaultModelId);

  /// The owning plugin invokes this on connection reset before fresh activation.
  void clear() => _state = null;
}
