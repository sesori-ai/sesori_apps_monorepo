import "package:freezed_annotation/freezed_annotation.dart";

import "project_glossary_key.dart";

part "project_glossary_scope.freezed.dart";
part "project_glossary_scope.g.dart";

/// Exact ownership identity for one project voice glossary.
@Freezed(unionKey: "type", fromJson: true, toJson: true)
sealed class ProjectGlossaryScope with _$ProjectGlossaryScope {
  @FreezedUnionValue("repository")
  const factory repository({
    @ProjectGlossaryKeyJsonConverter() required ProjectGlossaryKey projectKey,
  }) = RepositoryProjectGlossaryScope;

  @FreezedUnionValue("bridge_local")
  const factory bridgeLocal({
    @ProjectGlossaryKeyJsonConverter() required ProjectGlossaryKey projectKey,
    required String bridgeId,
  }) = BridgeLocalProjectGlossaryScope;

  factory fromJson(Map<String, dynamic> json) => _$ProjectGlossaryScopeFromJson(json);
}
