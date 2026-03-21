// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_session_archive_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UpdateSessionArchiveRequest _$UpdateSessionArchiveRequestFromJson(Map json) {
  $checkKeys(json, requiredKeys: const ['time']);
  return _UpdateSessionArchiveRequest(
    time: UpdateSessionArchiveTime.fromJson(
      Map<String, dynamic>.from(json['time'] as Map),
    ),
  );
}

Map<String, dynamic> _$UpdateSessionArchiveRequestToJson(
  _UpdateSessionArchiveRequest instance,
) => <String, dynamic>{'time': instance.time.toJson()};

_UpdateSessionArchiveTime _$UpdateSessionArchiveTimeFromJson(Map json) {
  $checkKeys(json, requiredKeys: const ['archived']);
  return _UpdateSessionArchiveTime(
    archived: (json['archived'] as num?)?.toInt(),
  );
}

Map<String, dynamic> _$UpdateSessionArchiveTimeToJson(
  _UpdateSessionArchiveTime instance,
) => <String, dynamic>{'archived': instance.archived};
