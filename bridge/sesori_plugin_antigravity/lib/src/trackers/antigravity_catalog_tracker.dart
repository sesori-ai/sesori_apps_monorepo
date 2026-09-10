import "../models/antigravity_model_catalog.dart";

/// Process-scoped last-good catalog. Only the options service validates and replaces it.
class AntigravityCatalogTracker() {
  ({AntigravityModelCatalog catalog, AntigravityModelSelection? newSessionDefault})? _state;

  AntigravityModelCatalog? get snapshot => _state?.catalog;
  AntigravityModelSelection? get newSessionDefault => _state?.newSessionDefault;
  String? get newSessionDefaultModelId => _state?.newSessionDefault?.modelId;

  void storeValidated({
    required AntigravityModelCatalog catalog,
    required AntigravityModelSelection? newSessionDefault,
  }) => _state = (catalog: catalog, newSessionDefault: newSessionDefault);

  /// The owning service invokes this on connection reset before fresh activation.
  void clear() => _state = null;
}
