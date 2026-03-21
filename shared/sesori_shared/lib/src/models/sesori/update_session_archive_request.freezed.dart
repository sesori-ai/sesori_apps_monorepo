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

 bool get archived;
/// Create a copy of UpdateSessionArchiveRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UpdateSessionArchiveRequestCopyWith<UpdateSessionArchiveRequest> get copyWith => _$UpdateSessionArchiveRequestCopyWithImpl<UpdateSessionArchiveRequest>(this as UpdateSessionArchiveRequest, _$identity);

  /// Serializes this UpdateSessionArchiveRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UpdateSessionArchiveRequest&&(identical(other.archived, archived) || other.archived == archived));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,archived);

@override
String toString() {
  return 'UpdateSessionArchiveRequest(archived: $archived)';
}


}

/// @nodoc
abstract mixin class $UpdateSessionArchiveRequestCopyWith<$Res>  {
  factory $UpdateSessionArchiveRequestCopyWith(UpdateSessionArchiveRequest value, $Res Function(UpdateSessionArchiveRequest) _then) = _$UpdateSessionArchiveRequestCopyWithImpl;
@useResult
$Res call({
 bool archived
});




}
/// @nodoc
class _$UpdateSessionArchiveRequestCopyWithImpl<$Res>
    implements $UpdateSessionArchiveRequestCopyWith<$Res> {
  _$UpdateSessionArchiveRequestCopyWithImpl(this._self, this._then);

  final UpdateSessionArchiveRequest _self;
  final $Res Function(UpdateSessionArchiveRequest) _then;

/// Create a copy of UpdateSessionArchiveRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? archived = null,}) {
  return _then(_self.copyWith(
archived: null == archived ? _self.archived : archived // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _UpdateSessionArchiveRequest implements UpdateSessionArchiveRequest {
  const _UpdateSessionArchiveRequest({required this.archived});
  factory _UpdateSessionArchiveRequest.fromJson(Map<String, dynamic> json) => _$UpdateSessionArchiveRequestFromJson(json);

@override final  bool archived;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UpdateSessionArchiveRequest&&(identical(other.archived, archived) || other.archived == archived));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,archived);

@override
String toString() {
  return 'UpdateSessionArchiveRequest(archived: $archived)';
}


}

/// @nodoc
abstract mixin class _$UpdateSessionArchiveRequestCopyWith<$Res> implements $UpdateSessionArchiveRequestCopyWith<$Res> {
  factory _$UpdateSessionArchiveRequestCopyWith(_UpdateSessionArchiveRequest value, $Res Function(_UpdateSessionArchiveRequest) _then) = __$UpdateSessionArchiveRequestCopyWithImpl;
@override @useResult
$Res call({
 bool archived
});




}
/// @nodoc
class __$UpdateSessionArchiveRequestCopyWithImpl<$Res>
    implements _$UpdateSessionArchiveRequestCopyWith<$Res> {
  __$UpdateSessionArchiveRequestCopyWithImpl(this._self, this._then);

  final _UpdateSessionArchiveRequest _self;
  final $Res Function(_UpdateSessionArchiveRequest) _then;

/// Create a copy of UpdateSessionArchiveRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? archived = null,}) {
  return _then(_UpdateSessionArchiveRequest(
archived: null == archived ? _self.archived : archived // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
