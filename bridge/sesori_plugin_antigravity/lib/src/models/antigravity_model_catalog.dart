/// Public thinking variants evidenced by the pinned Antigravity runtime.
enum AntigravityModelVariantKind({
  required final String id,
  required final String labelSuffix,
}) {
  high(id: "high", labelSuffix: "High"),
  medium(id: "medium", labelSuffix: "Medium"),
  low(id: "low", labelSuffix: "Low"),
}

/// One public variant mapped back to its exact account-advertised native model ID.
class const AntigravityModelVariant({
  required final AntigravityModelVariantKind kind,
  required final String nativeModelId,
});

class const AntigravityModelSelection({
  required final String modelId,
  required final String? variantId,
  required final String nativeModelId,
});

sealed class AntigravityModelOption({
  required final String id,
  required final String name,
}) {
  List<AntigravityModelVariant> get variants;
}

/// Model whose native identity is also its public identity.
final class AntigravityStandaloneModel({
  required super.id,
  required super.name,
}) extends AntigravityModelOption {
  @override
  List<AntigravityModelVariant> get variants => const [];
}

/// Public model family whose variants each dispatch one exact native model ID.
final class AntigravityVariantModel({
  required super.id,
  required super.name,
  required List<AntigravityModelVariant> variants,
}) extends AntigravityModelOption {
  this : assert(variants.isNotEmpty);

  @override
  final List<AntigravityModelVariant> variants = List.unmodifiable(variants);
}

class AntigravityModelCatalog({
  required final String configId,
  required final String currentNativeModelId,
  required final AntigravityModelSelection currentSelection,
  required List<AntigravityModelOption> models,
}) {
  final List<AntigravityModelOption> models = List.unmodifiable(models);
}

typedef AntigravityCatalogSession = ({String sessionId, AntigravityModelCatalog catalog});

/// Only a fresh session response establishes the backend's new-session default.
enum AntigravityCatalogSource() {
  newSession,
  existingSession,
}

/// The only permission mode Sesori may select. Other agent modes are never exposed.
enum AntigravitySessionMode({required final String id}) {
  defaultMode(id: "default"),
}
