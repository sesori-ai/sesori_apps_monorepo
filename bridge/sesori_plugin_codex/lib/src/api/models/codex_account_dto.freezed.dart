// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'codex_account_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CodexDeviceLoginStartParamsDto {

 CodexAccountLoginType get type;
/// Create a copy of CodexDeviceLoginStartParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexDeviceLoginStartParamsDtoCopyWith<CodexDeviceLoginStartParamsDto> get copyWith => _$CodexDeviceLoginStartParamsDtoCopyWithImpl<CodexDeviceLoginStartParamsDto>(this as CodexDeviceLoginStartParamsDto, _$identity);

  /// Serializes this CodexDeviceLoginStartParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexDeviceLoginStartParamsDto&&(identical(other.type, type) || other.type == type));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type);

@override
String toString() {
  return 'CodexDeviceLoginStartParamsDto(type: $type)';
}


}

/// @nodoc
abstract mixin class $CodexDeviceLoginStartParamsDtoCopyWith<$Res>  {
  factory $CodexDeviceLoginStartParamsDtoCopyWith(CodexDeviceLoginStartParamsDto value, $Res Function(CodexDeviceLoginStartParamsDto) _then) = _$CodexDeviceLoginStartParamsDtoCopyWithImpl;
@useResult
$Res call({
 CodexAccountLoginType type
});




}
/// @nodoc
class _$CodexDeviceLoginStartParamsDtoCopyWithImpl<$Res>
    implements $CodexDeviceLoginStartParamsDtoCopyWith<$Res> {
  _$CodexDeviceLoginStartParamsDtoCopyWithImpl(this._self, this._then);

  final CodexDeviceLoginStartParamsDto _self;
  final $Res Function(CodexDeviceLoginStartParamsDto) _then;

/// Create a copy of CodexDeviceLoginStartParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,}) {
  return _then(CodexDeviceLoginStartParamsDto(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CodexAccountLoginType,
  ));
}

}



/// @nodoc
@JsonSerializable(createFactory: false)

class _CodexDeviceLoginStartParamsDto implements CodexDeviceLoginStartParamsDto {
  const _CodexDeviceLoginStartParamsDto({required this.type});
  

@override final  CodexAccountLoginType type;

/// Create a copy of CodexDeviceLoginStartParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexDeviceLoginStartParamsDtoCopyWith<_CodexDeviceLoginStartParamsDto> get copyWith => __$CodexDeviceLoginStartParamsDtoCopyWithImpl<_CodexDeviceLoginStartParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexDeviceLoginStartParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexDeviceLoginStartParamsDto&&(identical(other.type, type) || other.type == type));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type);

@override
String toString() {
  return 'CodexDeviceLoginStartParamsDto(type: $type)';
}


}

/// @nodoc
abstract mixin class _$CodexDeviceLoginStartParamsDtoCopyWith<$Res> implements $CodexDeviceLoginStartParamsDtoCopyWith<$Res> {
  factory _$CodexDeviceLoginStartParamsDtoCopyWith(_CodexDeviceLoginStartParamsDto value, $Res Function(_CodexDeviceLoginStartParamsDto) _then) = __$CodexDeviceLoginStartParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 CodexAccountLoginType type
});




}
/// @nodoc
class __$CodexDeviceLoginStartParamsDtoCopyWithImpl<$Res>
    implements _$CodexDeviceLoginStartParamsDtoCopyWith<$Res> {
  __$CodexDeviceLoginStartParamsDtoCopyWithImpl(this._self, this._then);

  final _CodexDeviceLoginStartParamsDto _self;
  final $Res Function(_CodexDeviceLoginStartParamsDto) _then;

/// Create a copy of CodexDeviceLoginStartParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,}) {
  return _then(_CodexDeviceLoginStartParamsDto(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CodexAccountLoginType,
  ));
}


}


/// @nodoc
mixin _$CodexDeviceLoginStartResponseDto {

 CodexAccountLoginType get type; String get loginId; String get verificationUrl; String get userCode;
/// Create a copy of CodexDeviceLoginStartResponseDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexDeviceLoginStartResponseDtoCopyWith<CodexDeviceLoginStartResponseDto> get copyWith => _$CodexDeviceLoginStartResponseDtoCopyWithImpl<CodexDeviceLoginStartResponseDto>(this as CodexDeviceLoginStartResponseDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexDeviceLoginStartResponseDto&&(identical(other.type, type) || other.type == type)&&(identical(other.loginId, loginId) || other.loginId == loginId)&&(identical(other.verificationUrl, verificationUrl) || other.verificationUrl == verificationUrl)&&(identical(other.userCode, userCode) || other.userCode == userCode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,loginId,verificationUrl,userCode);

@override
String toString() {
  return 'CodexDeviceLoginStartResponseDto(type: $type, loginId: $loginId, verificationUrl: $verificationUrl, userCode: $userCode)';
}


}

/// @nodoc
abstract mixin class $CodexDeviceLoginStartResponseDtoCopyWith<$Res>  {
  factory $CodexDeviceLoginStartResponseDtoCopyWith(CodexDeviceLoginStartResponseDto value, $Res Function(CodexDeviceLoginStartResponseDto) _then) = _$CodexDeviceLoginStartResponseDtoCopyWithImpl;
@useResult
$Res call({
 CodexAccountLoginType type, String loginId, String verificationUrl, String userCode
});




}
/// @nodoc
class _$CodexDeviceLoginStartResponseDtoCopyWithImpl<$Res>
    implements $CodexDeviceLoginStartResponseDtoCopyWith<$Res> {
  _$CodexDeviceLoginStartResponseDtoCopyWithImpl(this._self, this._then);

  final CodexDeviceLoginStartResponseDto _self;
  final $Res Function(CodexDeviceLoginStartResponseDto) _then;

/// Create a copy of CodexDeviceLoginStartResponseDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? loginId = null,Object? verificationUrl = null,Object? userCode = null,}) {
  return _then(CodexDeviceLoginStartResponseDto(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CodexAccountLoginType,loginId: null == loginId ? _self.loginId : loginId // ignore: cast_nullable_to_non_nullable
as String,verificationUrl: null == verificationUrl ? _self.verificationUrl : verificationUrl // ignore: cast_nullable_to_non_nullable
as String,userCode: null == userCode ? _self.userCode : userCode // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexDeviceLoginStartResponseDto implements CodexDeviceLoginStartResponseDto {
  const _CodexDeviceLoginStartResponseDto({required this.type, required this.loginId, required this.verificationUrl, required this.userCode});
  factory _CodexDeviceLoginStartResponseDto.fromJson(Map<String, dynamic> json) => _$CodexDeviceLoginStartResponseDtoFromJson(json);

@override final  CodexAccountLoginType type;
@override final  String loginId;
@override final  String verificationUrl;
@override final  String userCode;

/// Create a copy of CodexDeviceLoginStartResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexDeviceLoginStartResponseDtoCopyWith<_CodexDeviceLoginStartResponseDto> get copyWith => __$CodexDeviceLoginStartResponseDtoCopyWithImpl<_CodexDeviceLoginStartResponseDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexDeviceLoginStartResponseDto&&(identical(other.type, type) || other.type == type)&&(identical(other.loginId, loginId) || other.loginId == loginId)&&(identical(other.verificationUrl, verificationUrl) || other.verificationUrl == verificationUrl)&&(identical(other.userCode, userCode) || other.userCode == userCode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,loginId,verificationUrl,userCode);

@override
String toString() {
  return 'CodexDeviceLoginStartResponseDto(type: $type, loginId: $loginId, verificationUrl: $verificationUrl, userCode: $userCode)';
}


}

/// @nodoc
abstract mixin class _$CodexDeviceLoginStartResponseDtoCopyWith<$Res> implements $CodexDeviceLoginStartResponseDtoCopyWith<$Res> {
  factory _$CodexDeviceLoginStartResponseDtoCopyWith(_CodexDeviceLoginStartResponseDto value, $Res Function(_CodexDeviceLoginStartResponseDto) _then) = __$CodexDeviceLoginStartResponseDtoCopyWithImpl;
@override @useResult
$Res call({
 CodexAccountLoginType type, String loginId, String verificationUrl, String userCode
});




}
/// @nodoc
class __$CodexDeviceLoginStartResponseDtoCopyWithImpl<$Res>
    implements _$CodexDeviceLoginStartResponseDtoCopyWith<$Res> {
  __$CodexDeviceLoginStartResponseDtoCopyWithImpl(this._self, this._then);

  final _CodexDeviceLoginStartResponseDto _self;
  final $Res Function(_CodexDeviceLoginStartResponseDto) _then;

/// Create a copy of CodexDeviceLoginStartResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? loginId = null,Object? verificationUrl = null,Object? userCode = null,}) {
  return _then(_CodexDeviceLoginStartResponseDto(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CodexAccountLoginType,loginId: null == loginId ? _self.loginId : loginId // ignore: cast_nullable_to_non_nullable
as String,verificationUrl: null == verificationUrl ? _self.verificationUrl : verificationUrl // ignore: cast_nullable_to_non_nullable
as String,userCode: null == userCode ? _self.userCode : userCode // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$CodexAccountLoginCancelParamsDto {

 String get loginId;
/// Create a copy of CodexAccountLoginCancelParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexAccountLoginCancelParamsDtoCopyWith<CodexAccountLoginCancelParamsDto> get copyWith => _$CodexAccountLoginCancelParamsDtoCopyWithImpl<CodexAccountLoginCancelParamsDto>(this as CodexAccountLoginCancelParamsDto, _$identity);

  /// Serializes this CodexAccountLoginCancelParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexAccountLoginCancelParamsDto&&(identical(other.loginId, loginId) || other.loginId == loginId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,loginId);

@override
String toString() {
  return 'CodexAccountLoginCancelParamsDto(loginId: $loginId)';
}


}

/// @nodoc
abstract mixin class $CodexAccountLoginCancelParamsDtoCopyWith<$Res>  {
  factory $CodexAccountLoginCancelParamsDtoCopyWith(CodexAccountLoginCancelParamsDto value, $Res Function(CodexAccountLoginCancelParamsDto) _then) = _$CodexAccountLoginCancelParamsDtoCopyWithImpl;
@useResult
$Res call({
 String loginId
});




}
/// @nodoc
class _$CodexAccountLoginCancelParamsDtoCopyWithImpl<$Res>
    implements $CodexAccountLoginCancelParamsDtoCopyWith<$Res> {
  _$CodexAccountLoginCancelParamsDtoCopyWithImpl(this._self, this._then);

  final CodexAccountLoginCancelParamsDto _self;
  final $Res Function(CodexAccountLoginCancelParamsDto) _then;

/// Create a copy of CodexAccountLoginCancelParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? loginId = null,}) {
  return _then(CodexAccountLoginCancelParamsDto(
loginId: null == loginId ? _self.loginId : loginId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable(createFactory: false)

class _CodexAccountLoginCancelParamsDto implements CodexAccountLoginCancelParamsDto {
  const _CodexAccountLoginCancelParamsDto({required this.loginId});
  

@override final  String loginId;

/// Create a copy of CodexAccountLoginCancelParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexAccountLoginCancelParamsDtoCopyWith<_CodexAccountLoginCancelParamsDto> get copyWith => __$CodexAccountLoginCancelParamsDtoCopyWithImpl<_CodexAccountLoginCancelParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexAccountLoginCancelParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexAccountLoginCancelParamsDto&&(identical(other.loginId, loginId) || other.loginId == loginId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,loginId);

@override
String toString() {
  return 'CodexAccountLoginCancelParamsDto(loginId: $loginId)';
}


}

/// @nodoc
abstract mixin class _$CodexAccountLoginCancelParamsDtoCopyWith<$Res> implements $CodexAccountLoginCancelParamsDtoCopyWith<$Res> {
  factory _$CodexAccountLoginCancelParamsDtoCopyWith(_CodexAccountLoginCancelParamsDto value, $Res Function(_CodexAccountLoginCancelParamsDto) _then) = __$CodexAccountLoginCancelParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String loginId
});




}
/// @nodoc
class __$CodexAccountLoginCancelParamsDtoCopyWithImpl<$Res>
    implements _$CodexAccountLoginCancelParamsDtoCopyWith<$Res> {
  __$CodexAccountLoginCancelParamsDtoCopyWithImpl(this._self, this._then);

  final _CodexAccountLoginCancelParamsDto _self;
  final $Res Function(_CodexAccountLoginCancelParamsDto) _then;

/// Create a copy of CodexAccountLoginCancelParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? loginId = null,}) {
  return _then(_CodexAccountLoginCancelParamsDto(
loginId: null == loginId ? _self.loginId : loginId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$CodexAccountLoginCancelResponseDto {

@JsonKey(unknownEnumValue: CodexAccountLoginCancelStatus.unknown) CodexAccountLoginCancelStatus get status;
/// Create a copy of CodexAccountLoginCancelResponseDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexAccountLoginCancelResponseDtoCopyWith<CodexAccountLoginCancelResponseDto> get copyWith => _$CodexAccountLoginCancelResponseDtoCopyWithImpl<CodexAccountLoginCancelResponseDto>(this as CodexAccountLoginCancelResponseDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexAccountLoginCancelResponseDto&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status);

@override
String toString() {
  return 'CodexAccountLoginCancelResponseDto(status: $status)';
}


}

/// @nodoc
abstract mixin class $CodexAccountLoginCancelResponseDtoCopyWith<$Res>  {
  factory $CodexAccountLoginCancelResponseDtoCopyWith(CodexAccountLoginCancelResponseDto value, $Res Function(CodexAccountLoginCancelResponseDto) _then) = _$CodexAccountLoginCancelResponseDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: CodexAccountLoginCancelStatus.unknown) CodexAccountLoginCancelStatus status
});




}
/// @nodoc
class _$CodexAccountLoginCancelResponseDtoCopyWithImpl<$Res>
    implements $CodexAccountLoginCancelResponseDtoCopyWith<$Res> {
  _$CodexAccountLoginCancelResponseDtoCopyWithImpl(this._self, this._then);

  final CodexAccountLoginCancelResponseDto _self;
  final $Res Function(CodexAccountLoginCancelResponseDto) _then;

/// Create a copy of CodexAccountLoginCancelResponseDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,}) {
  return _then(CodexAccountLoginCancelResponseDto(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CodexAccountLoginCancelStatus,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexAccountLoginCancelResponseDto implements CodexAccountLoginCancelResponseDto {
  const _CodexAccountLoginCancelResponseDto({@JsonKey(unknownEnumValue: CodexAccountLoginCancelStatus.unknown) required this.status});
  factory _CodexAccountLoginCancelResponseDto.fromJson(Map<String, dynamic> json) => _$CodexAccountLoginCancelResponseDtoFromJson(json);

@override@JsonKey(unknownEnumValue: CodexAccountLoginCancelStatus.unknown) final  CodexAccountLoginCancelStatus status;

/// Create a copy of CodexAccountLoginCancelResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexAccountLoginCancelResponseDtoCopyWith<_CodexAccountLoginCancelResponseDto> get copyWith => __$CodexAccountLoginCancelResponseDtoCopyWithImpl<_CodexAccountLoginCancelResponseDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexAccountLoginCancelResponseDto&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status);

@override
String toString() {
  return 'CodexAccountLoginCancelResponseDto(status: $status)';
}


}

/// @nodoc
abstract mixin class _$CodexAccountLoginCancelResponseDtoCopyWith<$Res> implements $CodexAccountLoginCancelResponseDtoCopyWith<$Res> {
  factory _$CodexAccountLoginCancelResponseDtoCopyWith(_CodexAccountLoginCancelResponseDto value, $Res Function(_CodexAccountLoginCancelResponseDto) _then) = __$CodexAccountLoginCancelResponseDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: CodexAccountLoginCancelStatus.unknown) CodexAccountLoginCancelStatus status
});




}
/// @nodoc
class __$CodexAccountLoginCancelResponseDtoCopyWithImpl<$Res>
    implements _$CodexAccountLoginCancelResponseDtoCopyWith<$Res> {
  __$CodexAccountLoginCancelResponseDtoCopyWithImpl(this._self, this._then);

  final _CodexAccountLoginCancelResponseDto _self;
  final $Res Function(_CodexAccountLoginCancelResponseDto) _then;

/// Create a copy of CodexAccountLoginCancelResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,}) {
  return _then(_CodexAccountLoginCancelResponseDto(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CodexAccountLoginCancelStatus,
  ));
}


}


/// @nodoc
mixin _$CodexAccountLoginCompletedNotificationDto {

 String? get loginId; bool get success; String? get error;
/// Create a copy of CodexAccountLoginCompletedNotificationDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexAccountLoginCompletedNotificationDtoCopyWith<CodexAccountLoginCompletedNotificationDto> get copyWith => _$CodexAccountLoginCompletedNotificationDtoCopyWithImpl<CodexAccountLoginCompletedNotificationDto>(this as CodexAccountLoginCompletedNotificationDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexAccountLoginCompletedNotificationDto&&(identical(other.loginId, loginId) || other.loginId == loginId)&&(identical(other.success, success) || other.success == success)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,loginId,success,error);

@override
String toString() {
  return 'CodexAccountLoginCompletedNotificationDto(loginId: $loginId, success: $success, error: $error)';
}


}

/// @nodoc
abstract mixin class $CodexAccountLoginCompletedNotificationDtoCopyWith<$Res>  {
  factory $CodexAccountLoginCompletedNotificationDtoCopyWith(CodexAccountLoginCompletedNotificationDto value, $Res Function(CodexAccountLoginCompletedNotificationDto) _then) = _$CodexAccountLoginCompletedNotificationDtoCopyWithImpl;
@useResult
$Res call({
 String? loginId, bool success, String? error
});




}
/// @nodoc
class _$CodexAccountLoginCompletedNotificationDtoCopyWithImpl<$Res>
    implements $CodexAccountLoginCompletedNotificationDtoCopyWith<$Res> {
  _$CodexAccountLoginCompletedNotificationDtoCopyWithImpl(this._self, this._then);

  final CodexAccountLoginCompletedNotificationDto _self;
  final $Res Function(CodexAccountLoginCompletedNotificationDto) _then;

/// Create a copy of CodexAccountLoginCompletedNotificationDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? loginId = freezed,Object? success = null,Object? error = freezed,}) {
  return _then(CodexAccountLoginCompletedNotificationDto(
loginId: freezed == loginId ? _self.loginId : loginId // ignore: cast_nullable_to_non_nullable
as String?,success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexAccountLoginCompletedNotificationDto implements CodexAccountLoginCompletedNotificationDto {
  const _CodexAccountLoginCompletedNotificationDto({required this.loginId, required this.success, required this.error});
  factory _CodexAccountLoginCompletedNotificationDto.fromJson(Map<String, dynamic> json) => _$CodexAccountLoginCompletedNotificationDtoFromJson(json);

@override final  String? loginId;
@override final  bool success;
@override final  String? error;

/// Create a copy of CodexAccountLoginCompletedNotificationDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexAccountLoginCompletedNotificationDtoCopyWith<_CodexAccountLoginCompletedNotificationDto> get copyWith => __$CodexAccountLoginCompletedNotificationDtoCopyWithImpl<_CodexAccountLoginCompletedNotificationDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexAccountLoginCompletedNotificationDto&&(identical(other.loginId, loginId) || other.loginId == loginId)&&(identical(other.success, success) || other.success == success)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,loginId,success,error);

@override
String toString() {
  return 'CodexAccountLoginCompletedNotificationDto(loginId: $loginId, success: $success, error: $error)';
}


}

/// @nodoc
abstract mixin class _$CodexAccountLoginCompletedNotificationDtoCopyWith<$Res> implements $CodexAccountLoginCompletedNotificationDtoCopyWith<$Res> {
  factory _$CodexAccountLoginCompletedNotificationDtoCopyWith(_CodexAccountLoginCompletedNotificationDto value, $Res Function(_CodexAccountLoginCompletedNotificationDto) _then) = __$CodexAccountLoginCompletedNotificationDtoCopyWithImpl;
@override @useResult
$Res call({
 String? loginId, bool success, String? error
});




}
/// @nodoc
class __$CodexAccountLoginCompletedNotificationDtoCopyWithImpl<$Res>
    implements _$CodexAccountLoginCompletedNotificationDtoCopyWith<$Res> {
  __$CodexAccountLoginCompletedNotificationDtoCopyWithImpl(this._self, this._then);

  final _CodexAccountLoginCompletedNotificationDto _self;
  final $Res Function(_CodexAccountLoginCompletedNotificationDto) _then;

/// Create a copy of CodexAccountLoginCompletedNotificationDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? loginId = freezed,Object? success = null,Object? error = freezed,}) {
  return _then(_CodexAccountLoginCompletedNotificationDto(
loginId: freezed == loginId ? _self.loginId : loginId // ignore: cast_nullable_to_non_nullable
as String?,success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
