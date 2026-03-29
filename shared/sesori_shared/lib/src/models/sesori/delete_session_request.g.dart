// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delete_session_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DeleteSessionRequest _$DeleteSessionRequestFromJson(Map json) =>
    _DeleteSessionRequest(
      deleteWorktree: json['deleteWorktree'] as bool,
      deleteBranch: json['deleteBranch'] as bool,
      force: json['force'] as bool,
    );

Map<String, dynamic> _$DeleteSessionRequestToJson(
  _DeleteSessionRequest instance,
) => <String, dynamic>{
  'deleteWorktree': instance.deleteWorktree,
  'deleteBranch': instance.deleteBranch,
  'force': instance.force,
};
