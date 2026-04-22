// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_error.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SessionError {

 String get name; String get message;
/// Create a copy of SessionError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionErrorCopyWith<SessionError> get copyWith => _$SessionErrorCopyWithImpl<SessionError>(this as SessionError, _$identity);

  /// Serializes this SessionError to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionError&&(identical(other.name, name) || other.name == name)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,message);

@override
String toString() {
  return 'SessionError(name: $name, message: $message)';
}


}

/// @nodoc
abstract mixin class $SessionErrorCopyWith<$Res>  {
  factory $SessionErrorCopyWith(SessionError value, $Res Function(SessionError) _then) = _$SessionErrorCopyWithImpl;
@useResult
$Res call({
 String name, String message
});




}
/// @nodoc
class _$SessionErrorCopyWithImpl<$Res>
    implements $SessionErrorCopyWith<$Res> {
  _$SessionErrorCopyWithImpl(this._self, this._then);

  final SessionError _self;
  final $Res Function(SessionError) _then;

/// Create a copy of SessionError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? message = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SessionError implements SessionError {
  const _SessionError({required this.name, required this.message});
  factory _SessionError.fromJson(Map<String, dynamic> json) => _$SessionErrorFromJson(json);

@override final  String name;
@override final  String message;

/// Create a copy of SessionError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionErrorCopyWith<_SessionError> get copyWith => __$SessionErrorCopyWithImpl<_SessionError>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionErrorToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionError&&(identical(other.name, name) || other.name == name)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,message);

@override
String toString() {
  return 'SessionError(name: $name, message: $message)';
}


}

/// @nodoc
abstract mixin class _$SessionErrorCopyWith<$Res> implements $SessionErrorCopyWith<$Res> {
  factory _$SessionErrorCopyWith(_SessionError value, $Res Function(_SessionError) _then) = __$SessionErrorCopyWithImpl;
@override @useResult
$Res call({
 String name, String message
});




}
/// @nodoc
class __$SessionErrorCopyWithImpl<$Res>
    implements _$SessionErrorCopyWith<$Res> {
  __$SessionErrorCopyWithImpl(this._self, this._then);

  final _SessionError _self;
  final $Res Function(_SessionError) _then;

/// Create a copy of SessionError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? message = null,}) {
  return _then(_SessionError(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
