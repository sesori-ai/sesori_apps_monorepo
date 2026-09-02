// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'local_notification_payload.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LocalNotificationPayload {

 String? get sessionId; String? get projectId; String? get sessionTitle; String? get accountId;
/// Create a copy of LocalNotificationPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LocalNotificationPayloadCopyWith<LocalNotificationPayload> get copyWith => _$LocalNotificationPayloadCopyWithImpl<LocalNotificationPayload>(this as LocalNotificationPayload, _$identity);

  /// Serializes this LocalNotificationPayload to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LocalNotificationPayload&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.sessionTitle, sessionTitle) || other.sessionTitle == sessionTitle)&&(identical(other.accountId, accountId) || other.accountId == accountId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,projectId,sessionTitle,accountId);

@override
String toString() {
  return 'LocalNotificationPayload(sessionId: $sessionId, projectId: $projectId, sessionTitle: $sessionTitle, accountId: $accountId)';
}


}

/// @nodoc
abstract mixin class $LocalNotificationPayloadCopyWith<$Res>  {
  factory $LocalNotificationPayloadCopyWith(LocalNotificationPayload value, $Res Function(LocalNotificationPayload) _then) = _$LocalNotificationPayloadCopyWithImpl;
@useResult
$Res call({
 String? sessionId, String? projectId, String? sessionTitle, String? accountId
});




}
/// @nodoc
class _$LocalNotificationPayloadCopyWithImpl<$Res>
    implements $LocalNotificationPayloadCopyWith<$Res> {
  _$LocalNotificationPayloadCopyWithImpl(this._self, this._then);

  final LocalNotificationPayload _self;
  final $Res Function(LocalNotificationPayload) _then;

/// Create a copy of LocalNotificationPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = freezed,Object? projectId = freezed,Object? sessionTitle = freezed,Object? accountId = freezed,}) {
  return _then(LocalNotificationPayload(
sessionId: freezed == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String?,projectId: freezed == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String?,sessionTitle: freezed == sessionTitle ? _self.sessionTitle : sessionTitle // ignore: cast_nullable_to_non_nullable
as String?,accountId: freezed == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _LocalNotificationPayload implements LocalNotificationPayload {
  const _LocalNotificationPayload({required this.sessionId, required this.projectId, required this.sessionTitle, required this.accountId});
  factory _LocalNotificationPayload.fromJson(Map<String, dynamic> json) => _$LocalNotificationPayloadFromJson(json);

@override final  String? sessionId;
@override final  String? projectId;
@override final  String? sessionTitle;
@override final  String? accountId;

/// Create a copy of LocalNotificationPayload
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LocalNotificationPayloadCopyWith<_LocalNotificationPayload> get copyWith => __$LocalNotificationPayloadCopyWithImpl<_LocalNotificationPayload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LocalNotificationPayloadToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LocalNotificationPayload&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.sessionTitle, sessionTitle) || other.sessionTitle == sessionTitle)&&(identical(other.accountId, accountId) || other.accountId == accountId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,projectId,sessionTitle,accountId);

@override
String toString() {
  return 'LocalNotificationPayload(sessionId: $sessionId, projectId: $projectId, sessionTitle: $sessionTitle, accountId: $accountId)';
}


}

/// @nodoc
abstract mixin class _$LocalNotificationPayloadCopyWith<$Res> implements $LocalNotificationPayloadCopyWith<$Res> {
  factory _$LocalNotificationPayloadCopyWith(_LocalNotificationPayload value, $Res Function(_LocalNotificationPayload) _then) = __$LocalNotificationPayloadCopyWithImpl;
@override @useResult
$Res call({
 String? sessionId, String? projectId, String? sessionTitle, String? accountId
});




}
/// @nodoc
class __$LocalNotificationPayloadCopyWithImpl<$Res>
    implements _$LocalNotificationPayloadCopyWith<$Res> {
  __$LocalNotificationPayloadCopyWithImpl(this._self, this._then);

  final _LocalNotificationPayload _self;
  final $Res Function(_LocalNotificationPayload) _then;

/// Create a copy of LocalNotificationPayload
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = freezed,Object? projectId = freezed,Object? sessionTitle = freezed,Object? accountId = freezed,}) {
  return _then(_LocalNotificationPayload(
sessionId: freezed == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String?,projectId: freezed == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String?,sessionTitle: freezed == sessionTitle ? _self.sessionTitle : sessionTitle // ignore: cast_nullable_to_non_nullable
as String?,accountId: freezed == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
