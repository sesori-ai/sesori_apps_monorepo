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
mixin _$CodexAccountKindDto {

@JsonKey(unknownEnumValue: CodexAccountKind.unknown) CodexAccountKind get type;
/// Create a copy of CodexAccountKindDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexAccountKindDtoCopyWith<CodexAccountKindDto> get copyWith => _$CodexAccountKindDtoCopyWithImpl<CodexAccountKindDto>(this as CodexAccountKindDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CodexAccountKindDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexAccountKindDto&&(identical(other.type, _this.type) || other.type == _this.type));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CodexAccountKindDto;
  return Object.hash(runtimeType,_this.type);
}

@override
String toString() {
  final _this = this as CodexAccountKindDto;
  return 'CodexAccountKindDto(type: ${_this.type})';
}


}

/// @nodoc
abstract mixin class $CodexAccountKindDtoCopyWith<$Res>  {
  factory $CodexAccountKindDtoCopyWith(CodexAccountKindDto value, $Res Function(CodexAccountKindDto) _then) = _$CodexAccountKindDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: CodexAccountKind.unknown) CodexAccountKind type
});




}
/// @nodoc
class _$CodexAccountKindDtoCopyWithImpl<$Res>
    implements $CodexAccountKindDtoCopyWith<$Res> {
  _$CodexAccountKindDtoCopyWithImpl(this._self, this._then);

  final CodexAccountKindDto _self;
  final $Res Function(CodexAccountKindDto) _then;

/// Create a copy of CodexAccountKindDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,}) {
  return _then(CodexAccountKindDto(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CodexAccountKind,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexAccountKindDto implements CodexAccountKindDto {
  const _CodexAccountKindDto({@JsonKey(unknownEnumValue: CodexAccountKind.unknown) required this.type});
  factory _CodexAccountKindDto.fromJson(Map<String, dynamic> json) => _$CodexAccountKindDtoFromJson(json);

@override@JsonKey(unknownEnumValue: CodexAccountKind.unknown) final  CodexAccountKind type;

/// Create a copy of CodexAccountKindDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexAccountKindDtoCopyWith<_CodexAccountKindDto> get copyWith => __$CodexAccountKindDtoCopyWithImpl<_CodexAccountKindDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexAccountKindDto&&(identical(other.type, type) || other.type == type));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,type);
}

@override
String toString() {
    return 'CodexAccountKindDto(type: $type)';
}


}

/// @nodoc
abstract mixin class _$CodexAccountKindDtoCopyWith<$Res> implements $CodexAccountKindDtoCopyWith<$Res> {
  factory _$CodexAccountKindDtoCopyWith(_CodexAccountKindDto value, $Res Function(_CodexAccountKindDto) _then) = __$CodexAccountKindDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: CodexAccountKind.unknown) CodexAccountKind type
});




}
/// @nodoc
class __$CodexAccountKindDtoCopyWithImpl<$Res>
    implements _$CodexAccountKindDtoCopyWith<$Res> {
  __$CodexAccountKindDtoCopyWithImpl(this._self, this._then);

  final _CodexAccountKindDto _self;
  final $Res Function(_CodexAccountKindDto) _then;

/// Create a copy of CodexAccountKindDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,}) {
  return _then(_CodexAccountKindDto(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CodexAccountKind,
  ));
}


}


/// @nodoc
mixin _$CodexAccountReadResponseDto {

 CodexAccountKindDto? get account;
/// Create a copy of CodexAccountReadResponseDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexAccountReadResponseDtoCopyWith<CodexAccountReadResponseDto> get copyWith => _$CodexAccountReadResponseDtoCopyWithImpl<CodexAccountReadResponseDto>(this as CodexAccountReadResponseDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CodexAccountReadResponseDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexAccountReadResponseDto&&(identical(other.account, _this.account) || other.account == _this.account));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CodexAccountReadResponseDto;
  return Object.hash(runtimeType,_this.account);
}

@override
String toString() {
  final _this = this as CodexAccountReadResponseDto;
  return 'CodexAccountReadResponseDto(account: ${_this.account})';
}


}

/// @nodoc
abstract mixin class $CodexAccountReadResponseDtoCopyWith<$Res>  {
  factory $CodexAccountReadResponseDtoCopyWith(CodexAccountReadResponseDto value, $Res Function(CodexAccountReadResponseDto) _then) = _$CodexAccountReadResponseDtoCopyWithImpl;
@useResult
$Res call({
 CodexAccountKindDto? account
});


$CodexAccountKindDtoCopyWith<$Res>? get account;

}
/// @nodoc
class _$CodexAccountReadResponseDtoCopyWithImpl<$Res>
    implements $CodexAccountReadResponseDtoCopyWith<$Res> {
  _$CodexAccountReadResponseDtoCopyWithImpl(this._self, this._then);

  final CodexAccountReadResponseDto _self;
  final $Res Function(CodexAccountReadResponseDto) _then;

/// Create a copy of CodexAccountReadResponseDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? account = freezed,}) {
  return _then(CodexAccountReadResponseDto(
account: freezed == account ? _self.account : account // ignore: cast_nullable_to_non_nullable
as CodexAccountKindDto?,
  ));
}
/// Create a copy of CodexAccountReadResponseDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexAccountKindDtoCopyWith<$Res>? get account {
    if (_self.account == null) {
    return null;
  }

  return $CodexAccountKindDtoCopyWith<$Res>(_self.account!, (value) {
    return _then(_self.copyWith(account: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexAccountReadResponseDto implements CodexAccountReadResponseDto {
  const _CodexAccountReadResponseDto({required this.account});
  factory _CodexAccountReadResponseDto.fromJson(Map<String, dynamic> json) => _$CodexAccountReadResponseDtoFromJson(json);

@override final  CodexAccountKindDto? account;

/// Create a copy of CodexAccountReadResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexAccountReadResponseDtoCopyWith<_CodexAccountReadResponseDto> get copyWith => __$CodexAccountReadResponseDtoCopyWithImpl<_CodexAccountReadResponseDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexAccountReadResponseDto&&(identical(other.account, account) || other.account == account));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,account);
}

@override
String toString() {
    return 'CodexAccountReadResponseDto(account: $account)';
}


}

/// @nodoc
abstract mixin class _$CodexAccountReadResponseDtoCopyWith<$Res> implements $CodexAccountReadResponseDtoCopyWith<$Res> {
  factory _$CodexAccountReadResponseDtoCopyWith(_CodexAccountReadResponseDto value, $Res Function(_CodexAccountReadResponseDto) _then) = __$CodexAccountReadResponseDtoCopyWithImpl;
@override @useResult
$Res call({
 CodexAccountKindDto? account
});


@override $CodexAccountKindDtoCopyWith<$Res>? get account;

}
/// @nodoc
class __$CodexAccountReadResponseDtoCopyWithImpl<$Res>
    implements _$CodexAccountReadResponseDtoCopyWith<$Res> {
  __$CodexAccountReadResponseDtoCopyWithImpl(this._self, this._then);

  final _CodexAccountReadResponseDto _self;
  final $Res Function(_CodexAccountReadResponseDto) _then;

/// Create a copy of CodexAccountReadResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? account = freezed,}) {
  return _then(_CodexAccountReadResponseDto(
account: freezed == account ? _self.account : account // ignore: cast_nullable_to_non_nullable
as CodexAccountKindDto?,
  ));
}

/// Create a copy of CodexAccountReadResponseDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexAccountKindDtoCopyWith<$Res>? get account {
    if (_self.account == null) {
    return null;
  }

  return $CodexAccountKindDtoCopyWith<$Res>(_self.account!, (value) {
    return _then(_self.copyWith(account: value));
  });
}
}

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
  final _this = this as CodexDeviceLoginStartParamsDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexDeviceLoginStartParamsDto&&(identical(other.type, _this.type) || other.type == _this.type));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CodexDeviceLoginStartParamsDto;
  return Object.hash(runtimeType,_this.type);
}

@override
String toString() {
  final _this = this as CodexDeviceLoginStartParamsDto;
  return 'CodexDeviceLoginStartParamsDto(type: ${_this.type})';
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
int get hashCode {
    return Object.hash(runtimeType,type);
}

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
  final _this = this as CodexDeviceLoginStartResponseDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexDeviceLoginStartResponseDto&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.loginId, _this.loginId) || other.loginId == _this.loginId)&&(identical(other.verificationUrl, _this.verificationUrl) || other.verificationUrl == _this.verificationUrl)&&(identical(other.userCode, _this.userCode) || other.userCode == _this.userCode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CodexDeviceLoginStartResponseDto;
  return Object.hash(runtimeType,_this.type,_this.loginId,_this.verificationUrl,_this.userCode);
}

@override
String toString() {
  final _this = this as CodexDeviceLoginStartResponseDto;
  return 'CodexDeviceLoginStartResponseDto(type: ${_this.type}, loginId: ${_this.loginId}, verificationUrl: ${_this.verificationUrl}, userCode: ${_this.userCode})';
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
int get hashCode {
    return Object.hash(runtimeType,type,loginId,verificationUrl,userCode);
}

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
  final _this = this as CodexAccountLoginCancelParamsDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexAccountLoginCancelParamsDto&&(identical(other.loginId, _this.loginId) || other.loginId == _this.loginId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CodexAccountLoginCancelParamsDto;
  return Object.hash(runtimeType,_this.loginId);
}

@override
String toString() {
  final _this = this as CodexAccountLoginCancelParamsDto;
  return 'CodexAccountLoginCancelParamsDto(loginId: ${_this.loginId})';
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
int get hashCode {
    return Object.hash(runtimeType,loginId);
}

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
  final _this = this as CodexAccountLoginCancelResponseDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexAccountLoginCancelResponseDto&&(identical(other.status, _this.status) || other.status == _this.status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CodexAccountLoginCancelResponseDto;
  return Object.hash(runtimeType,_this.status);
}

@override
String toString() {
  final _this = this as CodexAccountLoginCancelResponseDto;
  return 'CodexAccountLoginCancelResponseDto(status: ${_this.status})';
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
int get hashCode {
    return Object.hash(runtimeType,status);
}

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
  final _this = this as CodexAccountLoginCompletedNotificationDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexAccountLoginCompletedNotificationDto&&(identical(other.loginId, _this.loginId) || other.loginId == _this.loginId)&&(identical(other.success, _this.success) || other.success == _this.success)&&(identical(other.error, _this.error) || other.error == _this.error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CodexAccountLoginCompletedNotificationDto;
  return Object.hash(runtimeType,_this.loginId,_this.success,_this.error);
}

@override
String toString() {
  final _this = this as CodexAccountLoginCompletedNotificationDto;
  return 'CodexAccountLoginCompletedNotificationDto(loginId: ${_this.loginId}, success: ${_this.success}, error: ${_this.error})';
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
int get hashCode {
    return Object.hash(runtimeType,loginId,success,error);
}

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
