// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NotificationData {

@JsonKey(unknownEnumValue: NotificationCategory.unknown) NotificationCategory get category;@JsonKey(unknownEnumValue: NotificationEventType.unknown) NotificationEventType? get eventType; String? get sessionId; String? get projectId;
/// Create a copy of NotificationData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationDataCopyWith<NotificationData> get copyWith => _$NotificationDataCopyWithImpl<NotificationData>(this as NotificationData, _$identity);

  /// Serializes this NotificationData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationData&&(identical(other.category, category) || other.category == category)&&(identical(other.eventType, eventType) || other.eventType == eventType)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.projectId, projectId) || other.projectId == projectId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,category,eventType,sessionId,projectId);

@override
String toString() {
  return 'NotificationData(category: $category, eventType: $eventType, sessionId: $sessionId, projectId: $projectId)';
}


}

/// @nodoc
abstract mixin class $NotificationDataCopyWith<$Res>  {
  factory $NotificationDataCopyWith(NotificationData value, $Res Function(NotificationData) _then) = _$NotificationDataCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: NotificationCategory.unknown) NotificationCategory category,@JsonKey(unknownEnumValue: NotificationEventType.unknown) NotificationEventType? eventType, String? sessionId, String? projectId
});




}
/// @nodoc
class _$NotificationDataCopyWithImpl<$Res>
    implements $NotificationDataCopyWith<$Res> {
  _$NotificationDataCopyWithImpl(this._self, this._then);

  final NotificationData _self;
  final $Res Function(NotificationData) _then;

/// Create a copy of NotificationData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? category = null,Object? eventType = freezed,Object? sessionId = freezed,Object? projectId = freezed,}) {
  return _then(_self.copyWith(
category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as NotificationCategory,eventType: freezed == eventType ? _self.eventType : eventType // ignore: cast_nullable_to_non_nullable
as NotificationEventType?,sessionId: freezed == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String?,projectId: freezed == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _NotificationData implements NotificationData {
  const _NotificationData({@JsonKey(unknownEnumValue: NotificationCategory.unknown) required this.category, @JsonKey(unknownEnumValue: NotificationEventType.unknown) required this.eventType, required this.sessionId, required this.projectId});
  factory _NotificationData.fromJson(Map<String, dynamic> json) => _$NotificationDataFromJson(json);

@override@JsonKey(unknownEnumValue: NotificationCategory.unknown) final  NotificationCategory category;
@override@JsonKey(unknownEnumValue: NotificationEventType.unknown) final  NotificationEventType? eventType;
@override final  String? sessionId;
@override final  String? projectId;

/// Create a copy of NotificationData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationDataCopyWith<_NotificationData> get copyWith => __$NotificationDataCopyWithImpl<_NotificationData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NotificationDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationData&&(identical(other.category, category) || other.category == category)&&(identical(other.eventType, eventType) || other.eventType == eventType)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.projectId, projectId) || other.projectId == projectId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,category,eventType,sessionId,projectId);

@override
String toString() {
  return 'NotificationData(category: $category, eventType: $eventType, sessionId: $sessionId, projectId: $projectId)';
}


}

/// @nodoc
abstract mixin class _$NotificationDataCopyWith<$Res> implements $NotificationDataCopyWith<$Res> {
  factory _$NotificationDataCopyWith(_NotificationData value, $Res Function(_NotificationData) _then) = __$NotificationDataCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: NotificationCategory.unknown) NotificationCategory category,@JsonKey(unknownEnumValue: NotificationEventType.unknown) NotificationEventType? eventType, String? sessionId, String? projectId
});




}
/// @nodoc
class __$NotificationDataCopyWithImpl<$Res>
    implements _$NotificationDataCopyWith<$Res> {
  __$NotificationDataCopyWithImpl(this._self, this._then);

  final _NotificationData _self;
  final $Res Function(_NotificationData) _then;

/// Create a copy of NotificationData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? category = null,Object? eventType = freezed,Object? sessionId = freezed,Object? projectId = freezed,}) {
  return _then(_NotificationData(
category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as NotificationCategory,eventType: freezed == eventType ? _self.eventType : eventType // ignore: cast_nullable_to_non_nullable
as NotificationEventType?,sessionId: freezed == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String?,projectId: freezed == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
