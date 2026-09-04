import "../models/grok_model_catalog.dart";

/// Sole owner of Grok's last successfully observed immutable catalog.
class GrokCatalogTracker() {
  GrokModelCatalog? _catalog;

  GrokModelCatalog? get snapshot => _catalog;

  void replaceCatalog({required GrokModelCatalog catalog}) => _catalog = catalog;
}
