import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

@lazySingleton
class AgentVariantOptionsBuilder {
  const AgentVariantOptionsBuilder();

  List<SessionVariant> build({
    required List<AgentInfo> agents,
    required String? selectedAgentName,
  }) {
    if (selectedAgentName == null) {
      return const [];
    }

    final variants = <SessionVariant>[];
    final ids = <String>{};
    for (final agent in agents) {
      final variant = agent.variant;
      if (agent.name != selectedAgentName || variant == null || variant == "none") {
        continue;
      }
      if (ids.add(variant)) {
        variants.add(SessionVariant(id: variant));
      }
    }
    return variants;
  }
}
