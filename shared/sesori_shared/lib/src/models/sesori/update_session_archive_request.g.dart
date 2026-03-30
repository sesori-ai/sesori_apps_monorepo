// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_session_archive_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UpdateSessionArchiveRequest _$UpdateSessionArchiveRequestFromJson(Map json) =>
    _UpdateSessionArchiveRequest(
      archived: json['archived'] as bool,
      deleteWorktree: json['deleteWorktree'] as bool,
      deleteBranch: json['deleteBranch'] as bool,
      force: json['force'] as bool,
    );

Map<String, dynamic> _$UpdateSessionArchiveRequestToJson(
  _UpdateSessionArchiveRequest instance,
) => <String, dynamic>{
  'archived': instance.archived,
  'deleteWorktree': instance.deleteWorktree,
  'deleteBranch': instance.deleteBranch,
  'force': instance.force,
};
