/// Exact account-advertised model identity; neither IDs nor labels are normalized.
class const AntigravityModelOption({required final String id, required final String name});

class AntigravityModelCatalog({
  required final String configId,
  required final String currentModelId,
  required List<AntigravityModelOption> models,
}) {
  final List<AntigravityModelOption> models = List.unmodifiable(models);
}

/// Only a fresh session response establishes the backend's new-session default.
enum AntigravityCatalogSource() {
  newSession,
  existingSession,
}

/// The only permission mode Sesori may select. Other agent modes are never exposed.
enum AntigravitySessionMode({required final String id}) {
  defaultMode(id: "default"),
}
