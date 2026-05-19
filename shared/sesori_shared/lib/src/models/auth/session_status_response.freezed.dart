// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_status_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
AuthSessionStatusResponse _$AuthSessionStatusResponseFromJson(
  Map<String, dynamic> json
) {
        switch (json['status']) {
                  case 'pending':
          return AuthSessionStatusResponsePending.fromJson(
            json
          );
                case 'complete':
          return AuthSessionStatusResponseComplete.fromJson(
            json
          );
                case 'denied':
          return AuthSessionStatusResponseDenied.fromJson(
            json
          );
                case 'expired':
          return AuthSessionStatusResponseExpired.fromJson(
            json
          );
                case 'error':
          return AuthSessionStatusResponseError.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'status',
  'AuthSessionStatusResponse',
  'Invalid union type "${json['status']}"!'
);
        }
      
}

/// @nodoc
mixin _$AuthSessionStatusResponse {



  /// Serializes this AuthSessionStatusResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthSessionStatusResponse);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AuthSessionStatusResponse()';
}


}

/// @nodoc
class $AuthSessionStatusResponseCopyWith<$Res>  {
$AuthSessionStatusResponseCopyWith(AuthSessionStatusResponse _, $Res Function(AuthSessionStatusResponse) __);
}



/// @nodoc
@JsonSerializable()

class AuthSessionStatusResponsePending implements AuthSessionStatusResponse {
  const AuthSessionStatusResponsePending({final  String? $type}): $type = $type ?? 'pending';
  factory AuthSessionStatusResponsePending.fromJson(Map<String, dynamic> json) => _$AuthSessionStatusResponsePendingFromJson(json);



@JsonKey(name: 'status')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$AuthSessionStatusResponsePendingToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthSessionStatusResponsePending);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AuthSessionStatusResponse.pending()';
}


}




/// @nodoc
@JsonSerializable()

class AuthSessionStatusResponseComplete implements AuthSessionStatusResponse {
  const AuthSessionStatusResponseComplete({required this.accessToken, required this.refreshToken, required this.user, final  String? $type}): $type = $type ?? 'complete';
  factory AuthSessionStatusResponseComplete.fromJson(Map<String, dynamic> json) => _$AuthSessionStatusResponseCompleteFromJson(json);

 final  String accessToken;
 final  String refreshToken;
 final  AuthUser user;

@JsonKey(name: 'status')
final String $type;


/// Create a copy of AuthSessionStatusResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthSessionStatusResponseCompleteCopyWith<AuthSessionStatusResponseComplete> get copyWith => _$AuthSessionStatusResponseCompleteCopyWithImpl<AuthSessionStatusResponseComplete>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AuthSessionStatusResponseCompleteToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthSessionStatusResponseComplete&&(identical(other.accessToken, accessToken) || other.accessToken == accessToken)&&(identical(other.refreshToken, refreshToken) || other.refreshToken == refreshToken)&&(identical(other.user, user) || other.user == user));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accessToken,refreshToken,user);

@override
String toString() {
  return 'AuthSessionStatusResponse.complete(accessToken: $accessToken, refreshToken: $refreshToken, user: $user)';
}


}

/// @nodoc
abstract mixin class $AuthSessionStatusResponseCompleteCopyWith<$Res> implements $AuthSessionStatusResponseCopyWith<$Res> {
  factory $AuthSessionStatusResponseCompleteCopyWith(AuthSessionStatusResponseComplete value, $Res Function(AuthSessionStatusResponseComplete) _then) = _$AuthSessionStatusResponseCompleteCopyWithImpl;
@useResult
$Res call({
 String accessToken, String refreshToken, AuthUser user
});


$AuthUserCopyWith<$Res> get user;

}
/// @nodoc
class _$AuthSessionStatusResponseCompleteCopyWithImpl<$Res>
    implements $AuthSessionStatusResponseCompleteCopyWith<$Res> {
  _$AuthSessionStatusResponseCompleteCopyWithImpl(this._self, this._then);

  final AuthSessionStatusResponseComplete _self;
  final $Res Function(AuthSessionStatusResponseComplete) _then;

/// Create a copy of AuthSessionStatusResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? accessToken = null,Object? refreshToken = null,Object? user = null,}) {
  return _then(AuthSessionStatusResponseComplete(
accessToken: null == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String,refreshToken: null == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as AuthUser,
  ));
}

/// Create a copy of AuthSessionStatusResponse
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
@JsonSerializable()

class AuthSessionStatusResponseDenied implements AuthSessionStatusResponse {
  const AuthSessionStatusResponseDenied({final  String? $type}): $type = $type ?? 'denied';
  factory AuthSessionStatusResponseDenied.fromJson(Map<String, dynamic> json) => _$AuthSessionStatusResponseDeniedFromJson(json);



@JsonKey(name: 'status')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$AuthSessionStatusResponseDeniedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthSessionStatusResponseDenied);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AuthSessionStatusResponse.denied()';
}


}




/// @nodoc
@JsonSerializable()

class AuthSessionStatusResponseExpired implements AuthSessionStatusResponse {
  const AuthSessionStatusResponseExpired({final  String? $type}): $type = $type ?? 'expired';
  factory AuthSessionStatusResponseExpired.fromJson(Map<String, dynamic> json) => _$AuthSessionStatusResponseExpiredFromJson(json);



@JsonKey(name: 'status')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$AuthSessionStatusResponseExpiredToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthSessionStatusResponseExpired);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AuthSessionStatusResponse.expired()';
}


}




/// @nodoc
@JsonSerializable()

class AuthSessionStatusResponseError implements AuthSessionStatusResponse {
  const AuthSessionStatusResponseError({required this.message, final  String? $type}): $type = $type ?? 'error';
  factory AuthSessionStatusResponseError.fromJson(Map<String, dynamic> json) => _$AuthSessionStatusResponseErrorFromJson(json);

 final  String message;

@JsonKey(name: 'status')
final String $type;


/// Create a copy of AuthSessionStatusResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthSessionStatusResponseErrorCopyWith<AuthSessionStatusResponseError> get copyWith => _$AuthSessionStatusResponseErrorCopyWithImpl<AuthSessionStatusResponseError>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AuthSessionStatusResponseErrorToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthSessionStatusResponseError&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'AuthSessionStatusResponse.error(message: $message)';
}


}

/// @nodoc
abstract mixin class $AuthSessionStatusResponseErrorCopyWith<$Res> implements $AuthSessionStatusResponseCopyWith<$Res> {
  factory $AuthSessionStatusResponseErrorCopyWith(AuthSessionStatusResponseError value, $Res Function(AuthSessionStatusResponseError) _then) = _$AuthSessionStatusResponseErrorCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$AuthSessionStatusResponseErrorCopyWithImpl<$Res>
    implements $AuthSessionStatusResponseErrorCopyWith<$Res> {
  _$AuthSessionStatusResponseErrorCopyWithImpl(this._self, this._then);

  final AuthSessionStatusResponseError _self;
  final $Res Function(AuthSessionStatusResponseError) _then;

/// Create a copy of AuthSessionStatusResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(AuthSessionStatusResponseError(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
