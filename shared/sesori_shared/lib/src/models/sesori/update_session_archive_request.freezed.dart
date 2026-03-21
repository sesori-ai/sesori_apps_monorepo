// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'update_session_archive_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UpdateSessionArchiveRequest {

@JsonKey(required: true) UpdateSessionArchiveTime get time;
/// Create a copy of UpdateSessionArchiveRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UpdateSessionArchiveRequestCopyWith<UpdateSessionArchiveRequest> get copyWith => _$UpdateSessionArchiveRequestCopyWithImpl<UpdateSessionArchiveRequest>(this as UpdateSessionArchiveRequest, _$identity);

  /// Serializes this UpdateSessionArchiveRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UpdateSessionArchiveRequest&&(identical(other.time, time) || other.time == time));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,time);

@override
String toString() {
  return 'UpdateSessionArchiveRequest(time: $time)';
}


}

/// @nodoc
abstract mixin class $UpdateSessionArchiveRequestCopyWith<$Res>  {
  factory $UpdateSessionArchiveRequestCopyWith(UpdateSessionArchiveRequest value, $Res Function(UpdateSessionArchiveRequest) _then) = _$UpdateSessionArchiveRequestCopyWithImpl;
@useResult
$Res call({
@JsonKey(required: true) UpdateSessionArchiveTime time
});


$UpdateSessionArchiveTimeCopyWith<$Res> get time;

}
/// @nodoc
class _$UpdateSessionArchiveRequestCopyWithImpl<$Res>
    implements $UpdateSessionArchiveRequestCopyWith<$Res> {
  _$UpdateSessionArchiveRequestCopyWithImpl(this._self, this._then);

  final UpdateSessionArchiveRequest _self;
  final $Res Function(UpdateSessionArchiveRequest) _then;

/// Create a copy of UpdateSessionArchiveRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? time = null,}) {
  return _then(_self.copyWith(
time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as UpdateSessionArchiveTime,
  ));
}
/// Create a copy of UpdateSessionArchiveRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UpdateSessionArchiveTimeCopyWith<$Res> get time {
  
  return $UpdateSessionArchiveTimeCopyWith<$Res>(_self.time, (value) {
    return _then(_self.copyWith(time: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _UpdateSessionArchiveRequest implements UpdateSessionArchiveRequest {
  const _UpdateSessionArchiveRequest({@JsonKey(required: true) required this.time});
  factory _UpdateSessionArchiveRequest.fromJson(Map<String, dynamic> json) => _$UpdateSessionArchiveRequestFromJson(json);

@override@JsonKey(required: true) final  UpdateSessionArchiveTime time;

/// Create a copy of UpdateSessionArchiveRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UpdateSessionArchiveRequestCopyWith<_UpdateSessionArchiveRequest> get copyWith => __$UpdateSessionArchiveRequestCopyWithImpl<_UpdateSessionArchiveRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UpdateSessionArchiveRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UpdateSessionArchiveRequest&&(identical(other.time, time) || other.time == time));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,time);

@override
String toString() {
  return 'UpdateSessionArchiveRequest(time: $time)';
}


}

/// @nodoc
abstract mixin class _$UpdateSessionArchiveRequestCopyWith<$Res> implements $UpdateSessionArchiveRequestCopyWith<$Res> {
  factory _$UpdateSessionArchiveRequestCopyWith(_UpdateSessionArchiveRequest value, $Res Function(_UpdateSessionArchiveRequest) _then) = __$UpdateSessionArchiveRequestCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(required: true) UpdateSessionArchiveTime time
});


@override $UpdateSessionArchiveTimeCopyWith<$Res> get time;

}
/// @nodoc
class __$UpdateSessionArchiveRequestCopyWithImpl<$Res>
    implements _$UpdateSessionArchiveRequestCopyWith<$Res> {
  __$UpdateSessionArchiveRequestCopyWithImpl(this._self, this._then);

  final _UpdateSessionArchiveRequest _self;
  final $Res Function(_UpdateSessionArchiveRequest) _then;

/// Create a copy of UpdateSessionArchiveRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? time = null,}) {
  return _then(_UpdateSessionArchiveRequest(
time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as UpdateSessionArchiveTime,
  ));
}

/// Create a copy of UpdateSessionArchiveRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UpdateSessionArchiveTimeCopyWith<$Res> get time {
  
  return $UpdateSessionArchiveTimeCopyWith<$Res>(_self.time, (value) {
    return _then(_self.copyWith(time: value));
  });
}
}


/// @nodoc
mixin _$UpdateSessionArchiveTime {

@JsonKey(required: true) int? get archived;
/// Create a copy of UpdateSessionArchiveTime
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UpdateSessionArchiveTimeCopyWith<UpdateSessionArchiveTime> get copyWith => _$UpdateSessionArchiveTimeCopyWithImpl<UpdateSessionArchiveTime>(this as UpdateSessionArchiveTime, _$identity);

  /// Serializes this UpdateSessionArchiveTime to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UpdateSessionArchiveTime&&(identical(other.archived, archived) || other.archived == archived));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,archived);

@override
String toString() {
  return 'UpdateSessionArchiveTime(archived: $archived)';
}


}

/// @nodoc
abstract mixin class $UpdateSessionArchiveTimeCopyWith<$Res>  {
  factory $UpdateSessionArchiveTimeCopyWith(UpdateSessionArchiveTime value, $Res Function(UpdateSessionArchiveTime) _then) = _$UpdateSessionArchiveTimeCopyWithImpl;
@useResult
$Res call({
@JsonKey(required: true) int? archived
});




}
/// @nodoc
class _$UpdateSessionArchiveTimeCopyWithImpl<$Res>
    implements $UpdateSessionArchiveTimeCopyWith<$Res> {
  _$UpdateSessionArchiveTimeCopyWithImpl(this._self, this._then);

  final UpdateSessionArchiveTime _self;
  final $Res Function(UpdateSessionArchiveTime) _then;

/// Create a copy of UpdateSessionArchiveTime
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? archived = freezed,}) {
  return _then(_self.copyWith(
archived: freezed == archived ? _self.archived : archived // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _UpdateSessionArchiveTime implements UpdateSessionArchiveTime {
  const _UpdateSessionArchiveTime({@JsonKey(required: true) required this.archived});
  factory _UpdateSessionArchiveTime.fromJson(Map<String, dynamic> json) => _$UpdateSessionArchiveTimeFromJson(json);

@override@JsonKey(required: true) final  int? archived;

/// Create a copy of UpdateSessionArchiveTime
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UpdateSessionArchiveTimeCopyWith<_UpdateSessionArchiveTime> get copyWith => __$UpdateSessionArchiveTimeCopyWithImpl<_UpdateSessionArchiveTime>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UpdateSessionArchiveTimeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UpdateSessionArchiveTime&&(identical(other.archived, archived) || other.archived == archived));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,archived);

@override
String toString() {
  return 'UpdateSessionArchiveTime(archived: $archived)';
}


}

/// @nodoc
abstract mixin class _$UpdateSessionArchiveTimeCopyWith<$Res> implements $UpdateSessionArchiveTimeCopyWith<$Res> {
  factory _$UpdateSessionArchiveTimeCopyWith(_UpdateSessionArchiveTime value, $Res Function(_UpdateSessionArchiveTime) _then) = __$UpdateSessionArchiveTimeCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(required: true) int? archived
});




}
/// @nodoc
class __$UpdateSessionArchiveTimeCopyWithImpl<$Res>
    implements _$UpdateSessionArchiveTimeCopyWith<$Res> {
  __$UpdateSessionArchiveTimeCopyWithImpl(this._self, this._then);

  final _UpdateSessionArchiveTime _self;
  final $Res Function(_UpdateSessionArchiveTime) _then;

/// Create a copy of UpdateSessionArchiveTime
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? archived = freezed,}) {
  return _then(_UpdateSessionArchiveTime(
archived: freezed == archived ? _self.archived : archived // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
