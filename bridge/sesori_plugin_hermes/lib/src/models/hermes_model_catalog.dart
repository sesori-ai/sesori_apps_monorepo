class const HermesCatalogModel({
  required final String value,
  required final String providerId,
  required final String providerName,
  required final String modelId,
  required final String name,
});

class HermesModelCatalog({
  required List<HermesCatalogModel> models,
  required final String? currentModelValue,
}) {
  final List<HermesCatalogModel> models = List.unmodifiable(models);

  HermesCatalogModel? get currentModel {
    final current = currentModelValue;
    if (current == null) return null;
    for (final model in models) {
      if (model.value == current) return model;
    }
    return null;
  }
}

sealed class const HermesCatalogDiscoveryResult();

final class const HermesCatalogObserved({required final HermesModelCatalog catalog})
    extends HermesCatalogDiscoveryResult;

final class const HermesCatalogDiscoveryFailed() extends HermesCatalogDiscoveryResult;
