import "package:collection/collection.dart";
import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

@lazySingleton
class AgentVariantOptionsBuilder {
  const AgentVariantOptionsBuilder();

  List<SessionVariant> build({
    required List<AgentInfo> agents,
    required String? providerID,
    required String? modelID,
  }) {
    final hasModel = providerID != null &&
        providerID.isNotEmpty &&
        modelID != null &&
        modelID.isNotEmpty;
    if (!hasModel) return const [];

    final agent = agents.firstWhereOrNull(
      (a) =>
          a.model?.providerID == providerID &&
          a.model?.modelID == modelID,
    );

    final variant = agent?.variant;
    if (variant == null || variant == "none") {
      return const [];
    }
    return [SessionVariant(id: variant)];
  }
}
