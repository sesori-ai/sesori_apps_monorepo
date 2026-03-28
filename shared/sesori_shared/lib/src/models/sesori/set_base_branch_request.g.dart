// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'set_base_branch_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SetBaseBranchRequest _$SetBaseBranchRequestFromJson(Map json) =>
    _SetBaseBranchRequest(
      projectId: json['projectId'] as String,
      baseBranch: json['baseBranch'] as String?,
    );

Map<String, dynamic> _$SetBaseBranchRequestToJson(
  _SetBaseBranchRequest instance,
) => <String, dynamic>{
  'projectId': instance.projectId,
  'baseBranch': instance.baseBranch,
};
