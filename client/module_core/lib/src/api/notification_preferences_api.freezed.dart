// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_preferences_api.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NotificationPreferencesApiRecord {

 String get deviceId; NotificationPreferencesApiNotifications get notifications; DateTime? get updatedAt;
/// Create a copy of NotificationPreferencesApiRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationPreferencesApiRecordCopyWith<NotificationPreferencesApiRecord> get copyWith => _$NotificationPreferencesApiRecordCopyWithImpl<NotificationPreferencesApiRecord>(this as NotificationPreferencesApiRecord, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationPreferencesApiRecord&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.notifications, notifications) || other.notifications == notifications)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,deviceId,notifications,updatedAt);

@override
String toString() {
  return 'NotificationPreferencesApiRecord(deviceId: $deviceId, notifications: $notifications, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $NotificationPreferencesApiRecordCopyWith<$Res>  {
  factory $NotificationPreferencesApiRecordCopyWith(NotificationPreferencesApiRecord value, $Res Function(NotificationPreferencesApiRecord) _then) = _$NotificationPreferencesApiRecordCopyWithImpl;
@useResult
$Res call({
 String deviceId, NotificationPreferencesApiNotifications notifications, DateTime? updatedAt
});


$NotificationPreferencesApiNotificationsCopyWith<$Res> get notifications;

}
/// @nodoc
class _$NotificationPreferencesApiRecordCopyWithImpl<$Res>
    implements $NotificationPreferencesApiRecordCopyWith<$Res> {
  _$NotificationPreferencesApiRecordCopyWithImpl(this._self, this._then);

  final NotificationPreferencesApiRecord _self;
  final $Res Function(NotificationPreferencesApiRecord) _then;

/// Create a copy of NotificationPreferencesApiRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? deviceId = null,Object? notifications = null,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,notifications: null == notifications ? _self.notifications : notifications // ignore: cast_nullable_to_non_nullable
as NotificationPreferencesApiNotifications,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of NotificationPreferencesApiRecord
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NotificationPreferencesApiNotificationsCopyWith<$Res> get notifications {
  
  return $NotificationPreferencesApiNotificationsCopyWith<$Res>(_self.notifications, (value) {
    return _then(_self.copyWith(notifications: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _NotificationPreferencesApiRecord implements NotificationPreferencesApiRecord {
  const _NotificationPreferencesApiRecord({required this.deviceId, required this.notifications, required this.updatedAt});
  factory _NotificationPreferencesApiRecord.fromJson(Map<String, dynamic> json) => _$NotificationPreferencesApiRecordFromJson(json);

@override final  String deviceId;
@override final  NotificationPreferencesApiNotifications notifications;
@override final  DateTime? updatedAt;

/// Create a copy of NotificationPreferencesApiRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationPreferencesApiRecordCopyWith<_NotificationPreferencesApiRecord> get copyWith => __$NotificationPreferencesApiRecordCopyWithImpl<_NotificationPreferencesApiRecord>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationPreferencesApiRecord&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.notifications, notifications) || other.notifications == notifications)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,deviceId,notifications,updatedAt);

@override
String toString() {
  return 'NotificationPreferencesApiRecord(deviceId: $deviceId, notifications: $notifications, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$NotificationPreferencesApiRecordCopyWith<$Res> implements $NotificationPreferencesApiRecordCopyWith<$Res> {
  factory _$NotificationPreferencesApiRecordCopyWith(_NotificationPreferencesApiRecord value, $Res Function(_NotificationPreferencesApiRecord) _then) = __$NotificationPreferencesApiRecordCopyWithImpl;
@override @useResult
$Res call({
 String deviceId, NotificationPreferencesApiNotifications notifications, DateTime? updatedAt
});


@override $NotificationPreferencesApiNotificationsCopyWith<$Res> get notifications;

}
/// @nodoc
class __$NotificationPreferencesApiRecordCopyWithImpl<$Res>
    implements _$NotificationPreferencesApiRecordCopyWith<$Res> {
  __$NotificationPreferencesApiRecordCopyWithImpl(this._self, this._then);

  final _NotificationPreferencesApiRecord _self;
  final $Res Function(_NotificationPreferencesApiRecord) _then;

/// Create a copy of NotificationPreferencesApiRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? deviceId = null,Object? notifications = null,Object? updatedAt = freezed,}) {
  return _then(_NotificationPreferencesApiRecord(
deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,notifications: null == notifications ? _self.notifications : notifications // ignore: cast_nullable_to_non_nullable
as NotificationPreferencesApiNotifications,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of NotificationPreferencesApiRecord
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NotificationPreferencesApiNotificationsCopyWith<$Res> get notifications {
  
  return $NotificationPreferencesApiNotificationsCopyWith<$Res>(_self.notifications, (value) {
    return _then(_self.copyWith(notifications: value));
  });
}
}


/// @nodoc
mixin _$NotificationPreferencesApiNotifications {

 bool get aiInteraction; bool get sessionMessage; bool get connectionStatus; bool get systemUpdate;
/// Create a copy of NotificationPreferencesApiNotifications
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationPreferencesApiNotificationsCopyWith<NotificationPreferencesApiNotifications> get copyWith => _$NotificationPreferencesApiNotificationsCopyWithImpl<NotificationPreferencesApiNotifications>(this as NotificationPreferencesApiNotifications, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationPreferencesApiNotifications&&(identical(other.aiInteraction, aiInteraction) || other.aiInteraction == aiInteraction)&&(identical(other.sessionMessage, sessionMessage) || other.sessionMessage == sessionMessage)&&(identical(other.connectionStatus, connectionStatus) || other.connectionStatus == connectionStatus)&&(identical(other.systemUpdate, systemUpdate) || other.systemUpdate == systemUpdate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,aiInteraction,sessionMessage,connectionStatus,systemUpdate);

@override
String toString() {
  return 'NotificationPreferencesApiNotifications(aiInteraction: $aiInteraction, sessionMessage: $sessionMessage, connectionStatus: $connectionStatus, systemUpdate: $systemUpdate)';
}


}

/// @nodoc
abstract mixin class $NotificationPreferencesApiNotificationsCopyWith<$Res>  {
  factory $NotificationPreferencesApiNotificationsCopyWith(NotificationPreferencesApiNotifications value, $Res Function(NotificationPreferencesApiNotifications) _then) = _$NotificationPreferencesApiNotificationsCopyWithImpl;
@useResult
$Res call({
 bool aiInteraction, bool sessionMessage, bool connectionStatus, bool systemUpdate
});




}
/// @nodoc
class _$NotificationPreferencesApiNotificationsCopyWithImpl<$Res>
    implements $NotificationPreferencesApiNotificationsCopyWith<$Res> {
  _$NotificationPreferencesApiNotificationsCopyWithImpl(this._self, this._then);

  final NotificationPreferencesApiNotifications _self;
  final $Res Function(NotificationPreferencesApiNotifications) _then;

/// Create a copy of NotificationPreferencesApiNotifications
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? aiInteraction = null,Object? sessionMessage = null,Object? connectionStatus = null,Object? systemUpdate = null,}) {
  return _then(_self.copyWith(
aiInteraction: null == aiInteraction ? _self.aiInteraction : aiInteraction // ignore: cast_nullable_to_non_nullable
as bool,sessionMessage: null == sessionMessage ? _self.sessionMessage : sessionMessage // ignore: cast_nullable_to_non_nullable
as bool,connectionStatus: null == connectionStatus ? _self.connectionStatus : connectionStatus // ignore: cast_nullable_to_non_nullable
as bool,systemUpdate: null == systemUpdate ? _self.systemUpdate : systemUpdate // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _NotificationPreferencesApiNotifications implements NotificationPreferencesApiNotifications {
  const _NotificationPreferencesApiNotifications({required this.aiInteraction, required this.sessionMessage, required this.connectionStatus, required this.systemUpdate});
  factory _NotificationPreferencesApiNotifications.fromJson(Map<String, dynamic> json) => _$NotificationPreferencesApiNotificationsFromJson(json);

@override final  bool aiInteraction;
@override final  bool sessionMessage;
@override final  bool connectionStatus;
@override final  bool systemUpdate;

/// Create a copy of NotificationPreferencesApiNotifications
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationPreferencesApiNotificationsCopyWith<_NotificationPreferencesApiNotifications> get copyWith => __$NotificationPreferencesApiNotificationsCopyWithImpl<_NotificationPreferencesApiNotifications>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationPreferencesApiNotifications&&(identical(other.aiInteraction, aiInteraction) || other.aiInteraction == aiInteraction)&&(identical(other.sessionMessage, sessionMessage) || other.sessionMessage == sessionMessage)&&(identical(other.connectionStatus, connectionStatus) || other.connectionStatus == connectionStatus)&&(identical(other.systemUpdate, systemUpdate) || other.systemUpdate == systemUpdate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,aiInteraction,sessionMessage,connectionStatus,systemUpdate);

@override
String toString() {
  return 'NotificationPreferencesApiNotifications(aiInteraction: $aiInteraction, sessionMessage: $sessionMessage, connectionStatus: $connectionStatus, systemUpdate: $systemUpdate)';
}


}

/// @nodoc
abstract mixin class _$NotificationPreferencesApiNotificationsCopyWith<$Res> implements $NotificationPreferencesApiNotificationsCopyWith<$Res> {
  factory _$NotificationPreferencesApiNotificationsCopyWith(_NotificationPreferencesApiNotifications value, $Res Function(_NotificationPreferencesApiNotifications) _then) = __$NotificationPreferencesApiNotificationsCopyWithImpl;
@override @useResult
$Res call({
 bool aiInteraction, bool sessionMessage, bool connectionStatus, bool systemUpdate
});




}
/// @nodoc
class __$NotificationPreferencesApiNotificationsCopyWithImpl<$Res>
    implements _$NotificationPreferencesApiNotificationsCopyWith<$Res> {
  __$NotificationPreferencesApiNotificationsCopyWithImpl(this._self, this._then);

  final _NotificationPreferencesApiNotifications _self;
  final $Res Function(_NotificationPreferencesApiNotifications) _then;

/// Create a copy of NotificationPreferencesApiNotifications
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? aiInteraction = null,Object? sessionMessage = null,Object? connectionStatus = null,Object? systemUpdate = null,}) {
  return _then(_NotificationPreferencesApiNotifications(
aiInteraction: null == aiInteraction ? _self.aiInteraction : aiInteraction // ignore: cast_nullable_to_non_nullable
as bool,sessionMessage: null == sessionMessage ? _self.sessionMessage : sessionMessage // ignore: cast_nullable_to_non_nullable
as bool,connectionStatus: null == connectionStatus ? _self.connectionStatus : connectionStatus // ignore: cast_nullable_to_non_nullable
as bool,systemUpdate: null == systemUpdate ? _self.systemUpdate : systemUpdate // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$NotificationPreferencePatchApiRequest {

 bool get enabled;
/// Create a copy of NotificationPreferencePatchApiRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationPreferencePatchApiRequestCopyWith<NotificationPreferencePatchApiRequest> get copyWith => _$NotificationPreferencePatchApiRequestCopyWithImpl<NotificationPreferencePatchApiRequest>(this as NotificationPreferencePatchApiRequest, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationPreferencePatchApiRequest&&(identical(other.enabled, enabled) || other.enabled == enabled));
}


@override
int get hashCode => Object.hash(runtimeType,enabled);

@override
String toString() {
  return 'NotificationPreferencePatchApiRequest(enabled: $enabled)';
}


}

/// @nodoc
abstract mixin class $NotificationPreferencePatchApiRequestCopyWith<$Res>  {
  factory $NotificationPreferencePatchApiRequestCopyWith(NotificationPreferencePatchApiRequest value, $Res Function(NotificationPreferencePatchApiRequest) _then) = _$NotificationPreferencePatchApiRequestCopyWithImpl;
@useResult
$Res call({
 bool enabled
});




}
/// @nodoc
class _$NotificationPreferencePatchApiRequestCopyWithImpl<$Res>
    implements $NotificationPreferencePatchApiRequestCopyWith<$Res> {
  _$NotificationPreferencePatchApiRequestCopyWithImpl(this._self, this._then);

  final NotificationPreferencePatchApiRequest _self;
  final $Res Function(NotificationPreferencePatchApiRequest) _then;

/// Create a copy of NotificationPreferencePatchApiRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enabled = null,}) {
  return _then(_self.copyWith(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



/// @nodoc


class NotificationPreferencePatchAiInteraction extends NotificationPreferencePatchApiRequest {
  const NotificationPreferencePatchAiInteraction({required this.enabled}): super._();
  

@override final  bool enabled;

/// Create a copy of NotificationPreferencePatchApiRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationPreferencePatchAiInteractionCopyWith<NotificationPreferencePatchAiInteraction> get copyWith => _$NotificationPreferencePatchAiInteractionCopyWithImpl<NotificationPreferencePatchAiInteraction>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationPreferencePatchAiInteraction&&(identical(other.enabled, enabled) || other.enabled == enabled));
}


@override
int get hashCode => Object.hash(runtimeType,enabled);

@override
String toString() {
  return 'NotificationPreferencePatchApiRequest.aiInteraction(enabled: $enabled)';
}


}

/// @nodoc
abstract mixin class $NotificationPreferencePatchAiInteractionCopyWith<$Res> implements $NotificationPreferencePatchApiRequestCopyWith<$Res> {
  factory $NotificationPreferencePatchAiInteractionCopyWith(NotificationPreferencePatchAiInteraction value, $Res Function(NotificationPreferencePatchAiInteraction) _then) = _$NotificationPreferencePatchAiInteractionCopyWithImpl;
@override @useResult
$Res call({
 bool enabled
});




}
/// @nodoc
class _$NotificationPreferencePatchAiInteractionCopyWithImpl<$Res>
    implements $NotificationPreferencePatchAiInteractionCopyWith<$Res> {
  _$NotificationPreferencePatchAiInteractionCopyWithImpl(this._self, this._then);

  final NotificationPreferencePatchAiInteraction _self;
  final $Res Function(NotificationPreferencePatchAiInteraction) _then;

/// Create a copy of NotificationPreferencePatchApiRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enabled = null,}) {
  return _then(NotificationPreferencePatchAiInteraction(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class NotificationPreferencePatchSessionMessage extends NotificationPreferencePatchApiRequest {
  const NotificationPreferencePatchSessionMessage({required this.enabled}): super._();
  

@override final  bool enabled;

/// Create a copy of NotificationPreferencePatchApiRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationPreferencePatchSessionMessageCopyWith<NotificationPreferencePatchSessionMessage> get copyWith => _$NotificationPreferencePatchSessionMessageCopyWithImpl<NotificationPreferencePatchSessionMessage>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationPreferencePatchSessionMessage&&(identical(other.enabled, enabled) || other.enabled == enabled));
}


@override
int get hashCode => Object.hash(runtimeType,enabled);

@override
String toString() {
  return 'NotificationPreferencePatchApiRequest.sessionMessage(enabled: $enabled)';
}


}

/// @nodoc
abstract mixin class $NotificationPreferencePatchSessionMessageCopyWith<$Res> implements $NotificationPreferencePatchApiRequestCopyWith<$Res> {
  factory $NotificationPreferencePatchSessionMessageCopyWith(NotificationPreferencePatchSessionMessage value, $Res Function(NotificationPreferencePatchSessionMessage) _then) = _$NotificationPreferencePatchSessionMessageCopyWithImpl;
@override @useResult
$Res call({
 bool enabled
});




}
/// @nodoc
class _$NotificationPreferencePatchSessionMessageCopyWithImpl<$Res>
    implements $NotificationPreferencePatchSessionMessageCopyWith<$Res> {
  _$NotificationPreferencePatchSessionMessageCopyWithImpl(this._self, this._then);

  final NotificationPreferencePatchSessionMessage _self;
  final $Res Function(NotificationPreferencePatchSessionMessage) _then;

/// Create a copy of NotificationPreferencePatchApiRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enabled = null,}) {
  return _then(NotificationPreferencePatchSessionMessage(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class NotificationPreferencePatchConnectionStatus extends NotificationPreferencePatchApiRequest {
  const NotificationPreferencePatchConnectionStatus({required this.enabled}): super._();
  

@override final  bool enabled;

/// Create a copy of NotificationPreferencePatchApiRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationPreferencePatchConnectionStatusCopyWith<NotificationPreferencePatchConnectionStatus> get copyWith => _$NotificationPreferencePatchConnectionStatusCopyWithImpl<NotificationPreferencePatchConnectionStatus>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationPreferencePatchConnectionStatus&&(identical(other.enabled, enabled) || other.enabled == enabled));
}


@override
int get hashCode => Object.hash(runtimeType,enabled);

@override
String toString() {
  return 'NotificationPreferencePatchApiRequest.connectionStatus(enabled: $enabled)';
}


}

/// @nodoc
abstract mixin class $NotificationPreferencePatchConnectionStatusCopyWith<$Res> implements $NotificationPreferencePatchApiRequestCopyWith<$Res> {
  factory $NotificationPreferencePatchConnectionStatusCopyWith(NotificationPreferencePatchConnectionStatus value, $Res Function(NotificationPreferencePatchConnectionStatus) _then) = _$NotificationPreferencePatchConnectionStatusCopyWithImpl;
@override @useResult
$Res call({
 bool enabled
});




}
/// @nodoc
class _$NotificationPreferencePatchConnectionStatusCopyWithImpl<$Res>
    implements $NotificationPreferencePatchConnectionStatusCopyWith<$Res> {
  _$NotificationPreferencePatchConnectionStatusCopyWithImpl(this._self, this._then);

  final NotificationPreferencePatchConnectionStatus _self;
  final $Res Function(NotificationPreferencePatchConnectionStatus) _then;

/// Create a copy of NotificationPreferencePatchApiRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enabled = null,}) {
  return _then(NotificationPreferencePatchConnectionStatus(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class NotificationPreferencePatchSystemUpdate extends NotificationPreferencePatchApiRequest {
  const NotificationPreferencePatchSystemUpdate({required this.enabled}): super._();
  

@override final  bool enabled;

/// Create a copy of NotificationPreferencePatchApiRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationPreferencePatchSystemUpdateCopyWith<NotificationPreferencePatchSystemUpdate> get copyWith => _$NotificationPreferencePatchSystemUpdateCopyWithImpl<NotificationPreferencePatchSystemUpdate>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationPreferencePatchSystemUpdate&&(identical(other.enabled, enabled) || other.enabled == enabled));
}


@override
int get hashCode => Object.hash(runtimeType,enabled);

@override
String toString() {
  return 'NotificationPreferencePatchApiRequest.systemUpdate(enabled: $enabled)';
}


}

/// @nodoc
abstract mixin class $NotificationPreferencePatchSystemUpdateCopyWith<$Res> implements $NotificationPreferencePatchApiRequestCopyWith<$Res> {
  factory $NotificationPreferencePatchSystemUpdateCopyWith(NotificationPreferencePatchSystemUpdate value, $Res Function(NotificationPreferencePatchSystemUpdate) _then) = _$NotificationPreferencePatchSystemUpdateCopyWithImpl;
@override @useResult
$Res call({
 bool enabled
});




}
/// @nodoc
class _$NotificationPreferencePatchSystemUpdateCopyWithImpl<$Res>
    implements $NotificationPreferencePatchSystemUpdateCopyWith<$Res> {
  _$NotificationPreferencePatchSystemUpdateCopyWithImpl(this._self, this._then);

  final NotificationPreferencePatchSystemUpdate _self;
  final $Res Function(NotificationPreferencePatchSystemUpdate) _then;

/// Create a copy of NotificationPreferencePatchApiRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enabled = null,}) {
  return _then(NotificationPreferencePatchSystemUpdate(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
