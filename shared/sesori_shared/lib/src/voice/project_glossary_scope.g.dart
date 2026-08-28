// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_glossary_scope.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RepositoryProjectGlossaryScope _$RepositoryProjectGlossaryScopeFromJson(
  Map json,
) => RepositoryProjectGlossaryScope(
  projectKey: const ProjectGlossaryKeyJsonConverter().fromJson(
    json['projectKey'] as String,
  ),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$RepositoryProjectGlossaryScopeToJson(
  RepositoryProjectGlossaryScope instance,
) => <String, dynamic>{
  'projectKey': const ProjectGlossaryKeyJsonConverter().toJson(
    instance.projectKey,
  ),
  'type': instance.$type,
};

BridgeLocalProjectGlossaryScope _$BridgeLocalProjectGlossaryScopeFromJson(
  Map json,
) => BridgeLocalProjectGlossaryScope(
  projectKey: const ProjectGlossaryKeyJsonConverter().fromJson(
    json['projectKey'] as String,
  ),
  bridgeId: json['bridgeId'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$BridgeLocalProjectGlossaryScopeToJson(
  BridgeLocalProjectGlossaryScope instance,
) => <String, dynamic>{
  'projectKey': const ProjectGlossaryKeyJsonConverter().toJson(
    instance.projectKey,
  ),
  'bridgeId': instance.bridgeId,
  'type': instance.$type,
};
