// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'branch_list_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BranchListResponse _$BranchListResponseFromJson(Map json) =>
    _BranchListResponse(
      branches: (json['branches'] as List<dynamic>)
          .map((e) => BranchInfo.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      currentBranch: json['currentBranch'] as String?,
    );

Map<String, dynamic> _$BranchListResponseToJson(_BranchListResponse instance) =>
    <String, dynamic>{
      'branches': instance.branches.map((e) => e.toJson()).toList(),
      'currentBranch': instance.currentBranch,
    };
