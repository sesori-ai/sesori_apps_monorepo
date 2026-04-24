import "package:collection/collection.dart";
import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

@lazySingleton
class AgentVariantOptionsBuilder {
  const AgentVariantOptionsBuilder();

  List<SessionVariant> build({
    required List<AgentInfo> agents,
    required String? agentName,
    required String? providerID,
    required String? modelID,
  }) {
    if (agentName == null) return const [];

    final matchingByName = agents.where((a) => a.name == agentName);
    final hasModel = providerID != null &&
        providerID.isNotEmpty &&
        modelID != null &&
        modelID.isNotEmpty;

    final AgentInfo? agent;
    if (hasModel) {
      agent = matchingByName.firstWhereOrNull(
        (a) =>
            a.model?.providerID == providerID &&
            a.model?.modelID == modelID,
      ) ?? matchingByName.firstOrNull;
    } else {
      agent = matchingByName.firstOrNull;
    }

    final variant = agent?.variant;
    if (variant == null || variant == "none") {
      return const [];
    }
    return [SessionVariant(id: variant)];
  }
}
