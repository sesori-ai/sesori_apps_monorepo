// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_wake_up.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WakeUpOnce _$WakeUpOnceFromJson(Map json) => WakeUpOnce($type: json['kind'] as String?);

Map<String, dynamic> _$WakeUpOnceToJson(WakeUpOnce instance) => <String, dynamic>{'kind': instance.$type};

WakeUpEvery _$WakeUpEveryFromJson(Map json) => WakeUpEvery(
  minutes: (json['minutes'] as num).toInt(),
  $type: json['kind'] as String?,
);

Map<String, dynamic> _$WakeUpEveryToJson(WakeUpEvery instance) => <String, dynamic>{
  'minutes': instance.minutes,
  'kind': instance.$type,
};

WakeUpCalendar _$WakeUpCalendarFromJson(Map json) => WakeUpCalendar(
  schedule: TaskSchedule.fromJson(
    Map<String, dynamic>.from(json['schedule'] as Map),
  ),
  timeZone: json['timeZone'] as String,
  $type: json['kind'] as String?,
);

Map<String, dynamic> _$WakeUpCalendarToJson(WakeUpCalendar instance) => <String, dynamic>{
  'schedule': instance.schedule.toJson(),
  'timeZone': instance.timeZone,
  'kind': instance.$type,
};
