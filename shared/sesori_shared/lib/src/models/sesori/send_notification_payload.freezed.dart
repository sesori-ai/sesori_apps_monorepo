// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'send_notification_payload.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SendNotificationPayload {

 NotificationCategory get category; String get title; String get body; String? get collapseKey; Map<String, String>? get data;
/// Create a copy of SendNotificationPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SendNotificationPayloadCopyWith<SendNotificationPayload> get copyWith => _$SendNotificationPayloadCopyWithImpl<SendNotificationPayload>(this as SendNotificationPayload, _$identity);

  /// Serializes this SendNotificationPayload to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SendNotificationPayload&&(identical(other.category, category) || other.category == category)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&(identical(other.collapseKey, collapseKey) || other.collapseKey == collapseKey)&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,category,title,body,collapseKey,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'SendNotificationPayload(category: $category, title: $title, body: $body, collapseKey: $collapseKey, data: $data)';
}


}

/// @nodoc
abstract mixin class $SendNotificationPayloadCopyWith<$Res>  {
  factory $SendNotificationPayloadCopyWith(SendNotificationPayload value, $Res Function(SendNotificationPayload) _then) = _$SendNotificationPayloadCopyWithImpl;
@useResult
$Res call({
 NotificationCategory category, String title, String body, String? collapseKey, Map<String, String>? data
});




}
/// @nodoc
class _$SendNotificationPayloadCopyWithImpl<$Res>
    implements $SendNotificationPayloadCopyWith<$Res> {
  _$SendNotificationPayloadCopyWithImpl(this._self, this._then);

  final SendNotificationPayload _self;
  final $Res Function(SendNotificationPayload) _then;

/// Create a copy of SendNotificationPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? category = null,Object? title = null,Object? body = null,Object? collapseKey = freezed,Object? data = freezed,}) {
  return _then(_self.copyWith(
category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as NotificationCategory,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,collapseKey: freezed == collapseKey ? _self.collapseKey : collapseKey // ignore: cast_nullable_to_non_nullable
as String?,data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SendNotificationPayload implements SendNotificationPayload {
  const _SendNotificationPayload({required this.category, required this.title, required this.body, this.collapseKey, final  Map<String, String>? data}): _data = data;
  factory _SendNotificationPayload.fromJson(Map<String, dynamic> json) => _$SendNotificationPayloadFromJson(json);

@override final  NotificationCategory category;
@override final  String title;
@override final  String body;
@override final  String? collapseKey;
 final  Map<String, String>? _data;
@override Map<String, String>? get data {
  final value = _data;
  if (value == null) return null;
  if (_data is EqualUnmodifiableMapView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


/// Create a copy of SendNotificationPayload
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SendNotificationPayloadCopyWith<_SendNotificationPayload> get copyWith => __$SendNotificationPayloadCopyWithImpl<_SendNotificationPayload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SendNotificationPayloadToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SendNotificationPayload&&(identical(other.category, category) || other.category == category)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&(identical(other.collapseKey, collapseKey) || other.collapseKey == collapseKey)&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,category,title,body,collapseKey,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'SendNotificationPayload(category: $category, title: $title, body: $body, collapseKey: $collapseKey, data: $data)';
}


}

/// @nodoc
abstract mixin class _$SendNotificationPayloadCopyWith<$Res> implements $SendNotificationPayloadCopyWith<$Res> {
  factory _$SendNotificationPayloadCopyWith(_SendNotificationPayload value, $Res Function(_SendNotificationPayload) _then) = __$SendNotificationPayloadCopyWithImpl;
@override @useResult
$Res call({
 NotificationCategory category, String title, String body, String? collapseKey, Map<String, String>? data
});




}
/// @nodoc
class __$SendNotificationPayloadCopyWithImpl<$Res>
    implements _$SendNotificationPayloadCopyWith<$Res> {
  __$SendNotificationPayloadCopyWithImpl(this._self, this._then);

  final _SendNotificationPayload _self;
  final $Res Function(_SendNotificationPayload) _then;

/// Create a copy of SendNotificationPayload
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? category = null,Object? title = null,Object? body = null,Object? collapseKey = freezed,Object? data = freezed,}) {
  return _then(_SendNotificationPayload(
category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as NotificationCategory,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,collapseKey: freezed == collapseKey ? _self.collapseKey : collapseKey // ignore: cast_nullable_to_non_nullable
as String?,data: freezed == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,
  ));
}


}

// dart format on
