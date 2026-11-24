// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_wake_up.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
WakeUpSchedule _$WakeUpScheduleFromJson(
  Map<String, dynamic> json
) {
        switch (json['kind']) {
                  case 'once':
          return WakeUpOnce.fromJson(
            json
          );
                case 'every':
          return WakeUpEvery.fromJson(
            json
          );
                case 'calendar':
          return WakeUpCalendar.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'kind',
  'WakeUpSchedule',
  'Invalid union type "${json['kind']}"!'
);
        }
      
}

/// @nodoc
mixin _$WakeUpSchedule {



  /// Serializes this WakeUpSchedule to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is WakeUpSchedule);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'WakeUpSchedule()';
}


}





/// @nodoc
@JsonSerializable()

class WakeUpOnce implements WakeUpSchedule {
  const WakeUpOnce({ String? $type}): $type = $type ?? 'once';
  factory WakeUpOnce.fromJson(Map<String, dynamic> json) => _$WakeUpOnceFromJson(json);



@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$WakeUpOnceToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is WakeUpOnce);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'WakeUpSchedule.once()';
}


}




/// @nodoc
@JsonSerializable()

class WakeUpEvery implements WakeUpSchedule {
  const WakeUpEvery({required this.minutes,  String? $type}): $type = $type ?? 'every';
  factory WakeUpEvery.fromJson(Map<String, dynamic> json) => _$WakeUpEveryFromJson(json);

 final  int minutes;

@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$WakeUpEveryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is WakeUpEvery&&(identical(other.minutes, minutes) || other.minutes == minutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,minutes);
}

@override
String toString() {
    return 'WakeUpSchedule.every(minutes: $minutes)';
}


}




/// @nodoc
@JsonSerializable()

class WakeUpCalendar implements WakeUpSchedule {
  const WakeUpCalendar({required this.schedule, required this.timeZone,  String? $type}): $type = $type ?? 'calendar';
  factory WakeUpCalendar.fromJson(Map<String, dynamic> json) => _$WakeUpCalendarFromJson(json);

 final  TaskSchedule schedule;
 final  String timeZone;

@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$WakeUpCalendarToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is WakeUpCalendar&&(identical(other.schedule, schedule) || other.schedule == schedule)&&(identical(other.timeZone, timeZone) || other.timeZone == timeZone));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,schedule,timeZone);
}

@override
String toString() {
    return 'WakeUpSchedule.calendar(schedule: $schedule, timeZone: $timeZone)';
}


}




// dart format on
