// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_login_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AuthLoginResponse {

 String get accessToken; String get refreshToken; AuthUser get user;@JsonKey(unknownEnumValue: AccountStatus.unknown) AccountStatus get accountStatus;
/// Create a copy of AuthLoginResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthLoginResponseCopyWith<AuthLoginResponse> get copyWith => _$AuthLoginResponseCopyWithImpl<AuthLoginResponse>(this as AuthLoginResponse, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthLoginResponse&&(identical(other.accessToken, accessToken) || other.accessToken == accessToken)&&(identical(other.refreshToken, refreshToken) || other.refreshToken == refreshToken)&&(identical(other.user, user) || other.user == user)&&(identical(other.accountStatus, accountStatus) || other.accountStatus == accountStatus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accessToken,refreshToken,user,accountStatus);

@override
String toString() {
  return 'AuthLoginResponse(accessToken: $accessToken, refreshToken: $refreshToken, user: $user, accountStatus: $accountStatus)';
}


}

/// @nodoc
abstract mixin class $AuthLoginResponseCopyWith<$Res>  {
  factory $AuthLoginResponseCopyWith(AuthLoginResponse value, $Res Function(AuthLoginResponse) _then) = _$AuthLoginResponseCopyWithImpl;
@useResult
$Res call({
 String accessToken, String refreshToken, AuthUser user,@JsonKey(unknownEnumValue: AccountStatus.unknown) AccountStatus accountStatus
});


$AuthUserCopyWith<$Res> get user;

}
/// @nodoc
class _$AuthLoginResponseCopyWithImpl<$Res>
    implements $AuthLoginResponseCopyWith<$Res> {
  _$AuthLoginResponseCopyWithImpl(this._self, this._then);

  final AuthLoginResponse _self;
  final $Res Function(AuthLoginResponse) _then;

/// Create a copy of AuthLoginResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? accessToken = null,Object? refreshToken = null,Object? user = null,Object? accountStatus = null,}) {
  return _then(AuthLoginResponse(
accessToken: null == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String,refreshToken: null == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as AuthUser,accountStatus: null == accountStatus ? _self.accountStatus : accountStatus // ignore: cast_nullable_to_non_nullable
as AccountStatus,
  ));
}
/// Create a copy of AuthLoginResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AuthUserCopyWith<$Res> get user {
  
  return $AuthUserCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _AuthLoginResponse implements AuthLoginResponse {
  const _AuthLoginResponse({required this.accessToken, required this.refreshToken, required this.user, @JsonKey(unknownEnumValue: AccountStatus.unknown) required this.accountStatus});
  factory _AuthLoginResponse.fromJson(Map<String, dynamic> json) => _$AuthLoginResponseFromJson(json);

@override final  String accessToken;
@override final  String refreshToken;
@override final  AuthUser user;
@override@JsonKey(unknownEnumValue: AccountStatus.unknown) final  AccountStatus accountStatus;

/// Create a copy of AuthLoginResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AuthLoginResponseCopyWith<_AuthLoginResponse> get copyWith => __$AuthLoginResponseCopyWithImpl<_AuthLoginResponse>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AuthLoginResponse&&(identical(other.accessToken, accessToken) || other.accessToken == accessToken)&&(identical(other.refreshToken, refreshToken) || other.refreshToken == refreshToken)&&(identical(other.user, user) || other.user == user)&&(identical(other.accountStatus, accountStatus) || other.accountStatus == accountStatus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accessToken,refreshToken,user,accountStatus);

@override
String toString() {
  return 'AuthLoginResponse(accessToken: $accessToken, refreshToken: $refreshToken, user: $user, accountStatus: $accountStatus)';
}


}

/// @nodoc
abstract mixin class _$AuthLoginResponseCopyWith<$Res> implements $AuthLoginResponseCopyWith<$Res> {
  factory _$AuthLoginResponseCopyWith(_AuthLoginResponse value, $Res Function(_AuthLoginResponse) _then) = __$AuthLoginResponseCopyWithImpl;
@override @useResult
$Res call({
 String accessToken, String refreshToken, AuthUser user,@JsonKey(unknownEnumValue: AccountStatus.unknown) AccountStatus accountStatus
});


@override $AuthUserCopyWith<$Res> get user;

}
/// @nodoc
class __$AuthLoginResponseCopyWithImpl<$Res>
    implements _$AuthLoginResponseCopyWith<$Res> {
  __$AuthLoginResponseCopyWithImpl(this._self, this._then);

  final _AuthLoginResponse _self;
  final $Res Function(_AuthLoginResponse) _then;

/// Create a copy of AuthLoginResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? accessToken = null,Object? refreshToken = null,Object? user = null,Object? accountStatus = null,}) {
  return _then(_AuthLoginResponse(
accessToken: null == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String,refreshToken: null == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as AuthUser,accountStatus: null == accountStatus ? _self.accountStatus : accountStatus // ignore: cast_nullable_to_non_nullable
as AccountStatus,
  ));
}

/// Create a copy of AuthLoginResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AuthUserCopyWith<$Res> get user {
  
  return $AuthUserCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}

// dart format on
