import "package:drift/drift.dart";
import "package:sesori_shared/sesori_shared.dart";

class const AgentModelConverter() extends TypeConverter<AgentModel, String> {
  @override
  AgentModel fromSql(String fromDb) {
    final parts = fromDb.split("|");
    return AgentModel(
      providerID: parts[0],
      modelID: parts[1],
      variant: parts.length > 2 ? parts[2] : null,
    );
  }

  @override
  String toSql(AgentModel value) {
    final variant = value.variant;
    return "${value.providerID}|${value.modelID}${variant != null ? "|$variant" : ""}";
  }
}
