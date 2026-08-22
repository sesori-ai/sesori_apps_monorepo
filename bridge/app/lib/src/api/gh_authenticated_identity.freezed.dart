// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gh_authenticated_identity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$GhAuthenticatedIdentity {

 String get rawLogin;
/// Create a copy of GhAuthenticatedIdentity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhAuthenticatedIdentityCopyWith<GhAuthenticatedIdentity> get copyWith => _$GhAuthenticatedIdentityCopyWithImpl<GhAuthenticatedIdentity>(this as GhAuthenticatedIdentity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GhAuthenticatedIdentity&&(identical(other.rawLogin, rawLogin) || other.rawLogin == rawLogin));
}


@override
int get hashCode => Object.hash(runtimeType,rawLogin);

@override
String toString() {
  return 'GhAuthenticatedIdentity(rawLogin: $rawLogin)';
}


}

/// @nodoc
abstract mixin class $GhAuthenticatedIdentityCopyWith<$Res>  {
  factory $GhAuthenticatedIdentityCopyWith(GhAuthenticatedIdentity value, $Res Function(GhAuthenticatedIdentity) _then) = _$GhAuthenticatedIdentityCopyWithImpl;
@useResult
$Res call({
 String rawLogin
});




}
/// @nodoc
class _$GhAuthenticatedIdentityCopyWithImpl<$Res>
    implements $GhAuthenticatedIdentityCopyWith<$Res> {
  _$GhAuthenticatedIdentityCopyWithImpl(this._self, this._then);

  final GhAuthenticatedIdentity _self;
  final $Res Function(GhAuthenticatedIdentity) _then;

/// Create a copy of GhAuthenticatedIdentity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rawLogin = null,}) {
  return _then(GhAuthenticatedIdentity(
rawLogin: null == rawLogin ? _self.rawLogin : rawLogin // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc


class _GhAuthenticatedIdentity implements GhAuthenticatedIdentity {
  const _GhAuthenticatedIdentity({required this.rawLogin});
  

@override final  String rawLogin;

/// Create a copy of GhAuthenticatedIdentity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GhAuthenticatedIdentityCopyWith<_GhAuthenticatedIdentity> get copyWith => __$GhAuthenticatedIdentityCopyWithImpl<_GhAuthenticatedIdentity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GhAuthenticatedIdentity&&(identical(other.rawLogin, rawLogin) || other.rawLogin == rawLogin));
}


@override
int get hashCode => Object.hash(runtimeType,rawLogin);

@override
String toString() {
  return 'GhAuthenticatedIdentity(rawLogin: $rawLogin)';
}


}

/// @nodoc
abstract mixin class _$GhAuthenticatedIdentityCopyWith<$Res> implements $GhAuthenticatedIdentityCopyWith<$Res> {
  factory _$GhAuthenticatedIdentityCopyWith(_GhAuthenticatedIdentity value, $Res Function(_GhAuthenticatedIdentity) _then) = __$GhAuthenticatedIdentityCopyWithImpl;
@override @useResult
$Res call({
 String rawLogin
});




}
/// @nodoc
class __$GhAuthenticatedIdentityCopyWithImpl<$Res>
    implements _$GhAuthenticatedIdentityCopyWith<$Res> {
  __$GhAuthenticatedIdentityCopyWithImpl(this._self, this._then);

  final _GhAuthenticatedIdentity _self;
  final $Res Function(_GhAuthenticatedIdentity) _then;

/// Create a copy of GhAuthenticatedIdentity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? rawLogin = null,}) {
  return _then(_GhAuthenticatedIdentity(
rawLogin: null == rawLogin ? _self.rawLogin : rawLogin // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
