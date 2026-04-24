import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

@lazySingleton
class AgentVariantOptionsBuilder {
  const AgentVariantOptionsBuilder();

  List<SessionVariant> build({required AgentModel? agentModel}) {
    final variant = agentModel?.variant;
    if (variant == null || variant == "none") {
      return const [];
    }
    return [SessionVariant(id: variant)];
  }
}
