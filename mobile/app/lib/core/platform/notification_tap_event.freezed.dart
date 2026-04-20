// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_tap_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NotificationTapEvent {

 String? get sessionId; String? get projectId; String? get sessionTitle;
/// Create a copy of NotificationTapEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationTapEventCopyWith<NotificationTapEvent> get copyWith => _$NotificationTapEventCopyWithImpl<NotificationTapEvent>(this as NotificationTapEvent, _$identity);

  /// Serializes this NotificationTapEvent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationTapEvent&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.sessionTitle, sessionTitle) || other.sessionTitle == sessionTitle));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,projectId,sessionTitle);

@override
String toString() {
  return 'NotificationTapEvent(sessionId: $sessionId, projectId: $projectId, sessionTitle: $sessionTitle)';
}


}

/// @nodoc
abstract mixin class $NotificationTapEventCopyWith<$Res>  {
  factory $NotificationTapEventCopyWith(NotificationTapEvent value, $Res Function(NotificationTapEvent) _then) = _$NotificationTapEventCopyWithImpl;
@useResult
$Res call({
 String? sessionId, String? projectId, String? sessionTitle
});




}
/// @nodoc
class _$NotificationTapEventCopyWithImpl<$Res>
    implements $NotificationTapEventCopyWith<$Res> {
  _$NotificationTapEventCopyWithImpl(this._self, this._then);

  final NotificationTapEvent _self;
  final $Res Function(NotificationTapEvent) _then;

/// Create a copy of NotificationTapEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = freezed,Object? projectId = freezed,Object? sessionTitle = freezed,}) {
  return _then(_self.copyWith(
sessionId: freezed == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String?,projectId: freezed == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String?,sessionTitle: freezed == sessionTitle ? _self.sessionTitle : sessionTitle // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _NotificationTapEvent implements NotificationTapEvent {
  const _NotificationTapEvent({required this.sessionId, required this.projectId, required this.sessionTitle});
  factory _NotificationTapEvent.fromJson(Map<String, dynamic> json) => _$NotificationTapEventFromJson(json);

@override final  String? sessionId;
@override final  String? projectId;
@override final  String? sessionTitle;

/// Create a copy of NotificationTapEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationTapEventCopyWith<_NotificationTapEvent> get copyWith => __$NotificationTapEventCopyWithImpl<_NotificationTapEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NotificationTapEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationTapEvent&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.sessionTitle, sessionTitle) || other.sessionTitle == sessionTitle));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,projectId,sessionTitle);

@override
String toString() {
  return 'NotificationTapEvent(sessionId: $sessionId, projectId: $projectId, sessionTitle: $sessionTitle)';
}


}

/// @nodoc
abstract mixin class _$NotificationTapEventCopyWith<$Res> implements $NotificationTapEventCopyWith<$Res> {
  factory _$NotificationTapEventCopyWith(_NotificationTapEvent value, $Res Function(_NotificationTapEvent) _then) = __$NotificationTapEventCopyWithImpl;
@override @useResult
$Res call({
 String? sessionId, String? projectId, String? sessionTitle
});




}
/// @nodoc
class __$NotificationTapEventCopyWithImpl<$Res>
    implements _$NotificationTapEventCopyWith<$Res> {
  __$NotificationTapEventCopyWithImpl(this._self, this._then);

  final _NotificationTapEvent _self;
  final $Res Function(_NotificationTapEvent) _then;

/// Create a copy of NotificationTapEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = freezed,Object? projectId = freezed,Object? sessionTitle = freezed,}) {
  return _then(_NotificationTapEvent(
sessionId: freezed == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String?,projectId: freezed == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String?,sessionTitle: freezed == sessionTitle ? _self.sessionTitle : sessionTitle // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
