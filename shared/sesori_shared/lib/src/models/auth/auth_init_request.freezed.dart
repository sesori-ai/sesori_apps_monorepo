// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_init_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AuthInitRequest {

 String get clientType;
/// Create a copy of AuthInitRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthInitRequestCopyWith<AuthInitRequest> get copyWith => _$AuthInitRequestCopyWithImpl<AuthInitRequest>(this as AuthInitRequest, _$identity);

  /// Serializes this AuthInitRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthInitRequest&&(identical(other.clientType, clientType) || other.clientType == clientType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,clientType);

@override
String toString() {
  return 'AuthInitRequest(clientType: $clientType)';
}


}

/// @nodoc
abstract mixin class $AuthInitRequestCopyWith<$Res>  {
  factory $AuthInitRequestCopyWith(AuthInitRequest value, $Res Function(AuthInitRequest) _then) = _$AuthInitRequestCopyWithImpl;
@useResult
$Res call({
 String clientType
});




}
/// @nodoc
class _$AuthInitRequestCopyWithImpl<$Res>
    implements $AuthInitRequestCopyWith<$Res> {
  _$AuthInitRequestCopyWithImpl(this._self, this._then);

  final AuthInitRequest _self;
  final $Res Function(AuthInitRequest) _then;

/// Create a copy of AuthInitRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? clientType = null,}) {
  return _then(_self.copyWith(
clientType: null == clientType ? _self.clientType : clientType // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _AuthInitRequest implements AuthInitRequest {
  const _AuthInitRequest({required this.clientType});
  factory _AuthInitRequest.fromJson(Map<String, dynamic> json) => _$AuthInitRequestFromJson(json);

@override final  String clientType;

/// Create a copy of AuthInitRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AuthInitRequestCopyWith<_AuthInitRequest> get copyWith => __$AuthInitRequestCopyWithImpl<_AuthInitRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AuthInitRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AuthInitRequest&&(identical(other.clientType, clientType) || other.clientType == clientType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,clientType);

@override
String toString() {
  return 'AuthInitRequest(clientType: $clientType)';
}


}

/// @nodoc
abstract mixin class _$AuthInitRequestCopyWith<$Res> implements $AuthInitRequestCopyWith<$Res> {
  factory _$AuthInitRequestCopyWith(_AuthInitRequest value, $Res Function(_AuthInitRequest) _then) = __$AuthInitRequestCopyWithImpl;
@override @useResult
$Res call({
 String clientType
});




}
/// @nodoc
class __$AuthInitRequestCopyWithImpl<$Res>
    implements _$AuthInitRequestCopyWith<$Res> {
  __$AuthInitRequestCopyWithImpl(this._self, this._then);

  final _AuthInitRequest _self;
  final $Res Function(_AuthInitRequest) _then;

/// Create a copy of AuthInitRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? clientType = null,}) {
  return _then(_AuthInitRequest(
clientType: null == clientType ? _self.clientType : clientType // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
