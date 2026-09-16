// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'codex_approval_details_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CodexApprovalDetailsDto {

 String? get command; String? get itemId; CodexNetworkApprovalContextDto? get networkApprovalContext;
/// Create a copy of CodexApprovalDetailsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexApprovalDetailsDtoCopyWith<CodexApprovalDetailsDto> get copyWith => _$CodexApprovalDetailsDtoCopyWithImpl<CodexApprovalDetailsDto>(this as CodexApprovalDetailsDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CodexApprovalDetailsDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexApprovalDetailsDto&&(identical(other.command, _this.command) || other.command == _this.command)&&(identical(other.itemId, _this.itemId) || other.itemId == _this.itemId)&&(identical(other.networkApprovalContext, _this.networkApprovalContext) || other.networkApprovalContext == _this.networkApprovalContext));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CodexApprovalDetailsDto;
  return Object.hash(runtimeType,_this.command,_this.itemId,_this.networkApprovalContext);
}

@override
String toString() {
  final _this = this as CodexApprovalDetailsDto;
  return 'CodexApprovalDetailsDto(command: ${_this.command}, itemId: ${_this.itemId}, networkApprovalContext: ${_this.networkApprovalContext})';
}


}

/// @nodoc
abstract mixin class $CodexApprovalDetailsDtoCopyWith<$Res>  {
  factory $CodexApprovalDetailsDtoCopyWith(CodexApprovalDetailsDto value, $Res Function(CodexApprovalDetailsDto) _then) = _$CodexApprovalDetailsDtoCopyWithImpl;
@useResult
$Res call({
 String? command, String? itemId, CodexNetworkApprovalContextDto? networkApprovalContext
});


$CodexNetworkApprovalContextDtoCopyWith<$Res>? get networkApprovalContext;

}
/// @nodoc
class _$CodexApprovalDetailsDtoCopyWithImpl<$Res>
    implements $CodexApprovalDetailsDtoCopyWith<$Res> {
  _$CodexApprovalDetailsDtoCopyWithImpl(this._self, this._then);

  final CodexApprovalDetailsDto _self;
  final $Res Function(CodexApprovalDetailsDto) _then;

/// Create a copy of CodexApprovalDetailsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? command = freezed,Object? itemId = freezed,Object? networkApprovalContext = freezed,}) {
  return _then(CodexApprovalDetailsDto(
command: freezed == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String?,itemId: freezed == itemId ? _self.itemId : itemId // ignore: cast_nullable_to_non_nullable
as String?,networkApprovalContext: freezed == networkApprovalContext ? _self.networkApprovalContext : networkApprovalContext // ignore: cast_nullable_to_non_nullable
as CodexNetworkApprovalContextDto?,
  ));
}
/// Create a copy of CodexApprovalDetailsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexNetworkApprovalContextDtoCopyWith<$Res>? get networkApprovalContext {
    if (_self.networkApprovalContext == null) {
    return null;
  }

  return $CodexNetworkApprovalContextDtoCopyWith<$Res>(_self.networkApprovalContext!, (value) {
    return _then(_self.copyWith(networkApprovalContext: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexApprovalDetailsDto implements CodexApprovalDetailsDto {
  const _CodexApprovalDetailsDto({required this.command, required this.itemId, required this.networkApprovalContext});
  factory _CodexApprovalDetailsDto.fromJson(Map<String, dynamic> json) => _$CodexApprovalDetailsDtoFromJson(json);

@override final  String? command;
@override final  String? itemId;
@override final  CodexNetworkApprovalContextDto? networkApprovalContext;

/// Create a copy of CodexApprovalDetailsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexApprovalDetailsDtoCopyWith<_CodexApprovalDetailsDto> get copyWith => __$CodexApprovalDetailsDtoCopyWithImpl<_CodexApprovalDetailsDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexApprovalDetailsDto&&(identical(other.command, command) || other.command == command)&&(identical(other.itemId, itemId) || other.itemId == itemId)&&(identical(other.networkApprovalContext, networkApprovalContext) || other.networkApprovalContext == networkApprovalContext));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,command,itemId,networkApprovalContext);
}

@override
String toString() {
    return 'CodexApprovalDetailsDto(command: $command, itemId: $itemId, networkApprovalContext: $networkApprovalContext)';
}


}

/// @nodoc
abstract mixin class _$CodexApprovalDetailsDtoCopyWith<$Res> implements $CodexApprovalDetailsDtoCopyWith<$Res> {
  factory _$CodexApprovalDetailsDtoCopyWith(_CodexApprovalDetailsDto value, $Res Function(_CodexApprovalDetailsDto) _then) = __$CodexApprovalDetailsDtoCopyWithImpl;
@override @useResult
$Res call({
 String? command, String? itemId, CodexNetworkApprovalContextDto? networkApprovalContext
});


@override $CodexNetworkApprovalContextDtoCopyWith<$Res>? get networkApprovalContext;

}
/// @nodoc
class __$CodexApprovalDetailsDtoCopyWithImpl<$Res>
    implements _$CodexApprovalDetailsDtoCopyWith<$Res> {
  __$CodexApprovalDetailsDtoCopyWithImpl(this._self, this._then);

  final _CodexApprovalDetailsDto _self;
  final $Res Function(_CodexApprovalDetailsDto) _then;

/// Create a copy of CodexApprovalDetailsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? command = freezed,Object? itemId = freezed,Object? networkApprovalContext = freezed,}) {
  return _then(_CodexApprovalDetailsDto(
command: freezed == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String?,itemId: freezed == itemId ? _self.itemId : itemId // ignore: cast_nullable_to_non_nullable
as String?,networkApprovalContext: freezed == networkApprovalContext ? _self.networkApprovalContext : networkApprovalContext // ignore: cast_nullable_to_non_nullable
as CodexNetworkApprovalContextDto?,
  ));
}

/// Create a copy of CodexApprovalDetailsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexNetworkApprovalContextDtoCopyWith<$Res>? get networkApprovalContext {
    if (_self.networkApprovalContext == null) {
    return null;
  }

  return $CodexNetworkApprovalContextDtoCopyWith<$Res>(_self.networkApprovalContext!, (value) {
    return _then(_self.copyWith(networkApprovalContext: value));
  });
}
}


/// @nodoc
mixin _$CodexNetworkApprovalContextDto {

 String get host;
/// Create a copy of CodexNetworkApprovalContextDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexNetworkApprovalContextDtoCopyWith<CodexNetworkApprovalContextDto> get copyWith => _$CodexNetworkApprovalContextDtoCopyWithImpl<CodexNetworkApprovalContextDto>(this as CodexNetworkApprovalContextDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CodexNetworkApprovalContextDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexNetworkApprovalContextDto&&(identical(other.host, _this.host) || other.host == _this.host));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CodexNetworkApprovalContextDto;
  return Object.hash(runtimeType,_this.host);
}

@override
String toString() {
  final _this = this as CodexNetworkApprovalContextDto;
  return 'CodexNetworkApprovalContextDto(host: ${_this.host})';
}


}

/// @nodoc
abstract mixin class $CodexNetworkApprovalContextDtoCopyWith<$Res>  {
  factory $CodexNetworkApprovalContextDtoCopyWith(CodexNetworkApprovalContextDto value, $Res Function(CodexNetworkApprovalContextDto) _then) = _$CodexNetworkApprovalContextDtoCopyWithImpl;
@useResult
$Res call({
 String host
});




}
/// @nodoc
class _$CodexNetworkApprovalContextDtoCopyWithImpl<$Res>
    implements $CodexNetworkApprovalContextDtoCopyWith<$Res> {
  _$CodexNetworkApprovalContextDtoCopyWithImpl(this._self, this._then);

  final CodexNetworkApprovalContextDto _self;
  final $Res Function(CodexNetworkApprovalContextDto) _then;

/// Create a copy of CodexNetworkApprovalContextDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? host = null,}) {
  return _then(CodexNetworkApprovalContextDto(
host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexNetworkApprovalContextDto implements CodexNetworkApprovalContextDto {
  const _CodexNetworkApprovalContextDto({required this.host});
  factory _CodexNetworkApprovalContextDto.fromJson(Map<String, dynamic> json) => _$CodexNetworkApprovalContextDtoFromJson(json);

@override final  String host;

/// Create a copy of CodexNetworkApprovalContextDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexNetworkApprovalContextDtoCopyWith<_CodexNetworkApprovalContextDto> get copyWith => __$CodexNetworkApprovalContextDtoCopyWithImpl<_CodexNetworkApprovalContextDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexNetworkApprovalContextDto&&(identical(other.host, host) || other.host == host));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,host);
}

@override
String toString() {
    return 'CodexNetworkApprovalContextDto(host: $host)';
}


}

/// @nodoc
abstract mixin class _$CodexNetworkApprovalContextDtoCopyWith<$Res> implements $CodexNetworkApprovalContextDtoCopyWith<$Res> {
  factory _$CodexNetworkApprovalContextDtoCopyWith(_CodexNetworkApprovalContextDto value, $Res Function(_CodexNetworkApprovalContextDto) _then) = __$CodexNetworkApprovalContextDtoCopyWithImpl;
@override @useResult
$Res call({
 String host
});




}
/// @nodoc
class __$CodexNetworkApprovalContextDtoCopyWithImpl<$Res>
    implements _$CodexNetworkApprovalContextDtoCopyWith<$Res> {
  __$CodexNetworkApprovalContextDtoCopyWithImpl(this._self, this._then);

  final _CodexNetworkApprovalContextDto _self;
  final $Res Function(_CodexNetworkApprovalContextDto) _then;

/// Create a copy of CodexNetworkApprovalContextDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? host = null,}) {
  return _then(_CodexNetworkApprovalContextDto(
host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
