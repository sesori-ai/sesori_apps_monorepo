// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'grok_session_store_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GrokSessionSummaryDto {

 GrokSessionSummaryInfoDto? get info;@JsonKey(name: "session_kind", unknownEnumValue: GrokSessionKind.unknown) GrokSessionKind? get sessionKind;@JsonKey(name: "agent_name") String? get agentName;@JsonKey(name: "generated_title") String? get generatedTitle;@JsonKey(name: "created_at") String? get createdAt;@JsonKey(name: "updated_at") String? get updatedAt;
/// Create a copy of GrokSessionSummaryDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GrokSessionSummaryDtoCopyWith<GrokSessionSummaryDto> get copyWith => _$GrokSessionSummaryDtoCopyWithImpl<GrokSessionSummaryDto>(this as GrokSessionSummaryDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GrokSessionSummaryDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokSessionSummaryDto&&(identical(other.info, _this.info) || other.info == _this.info)&&(identical(other.sessionKind, _this.sessionKind) || other.sessionKind == _this.sessionKind)&&(identical(other.agentName, _this.agentName) || other.agentName == _this.agentName)&&(identical(other.generatedTitle, _this.generatedTitle) || other.generatedTitle == _this.generatedTitle)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GrokSessionSummaryDto;
  return Object.hash(runtimeType,_this.info,_this.sessionKind,_this.agentName,_this.generatedTitle,_this.createdAt,_this.updatedAt);
}

@override
String toString() {
  final _this = this as GrokSessionSummaryDto;
  return 'GrokSessionSummaryDto(info: ${_this.info}, sessionKind: ${_this.sessionKind}, agentName: ${_this.agentName}, generatedTitle: ${_this.generatedTitle}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $GrokSessionSummaryDtoCopyWith<$Res>  {
  factory $GrokSessionSummaryDtoCopyWith(GrokSessionSummaryDto value, $Res Function(GrokSessionSummaryDto) _then) = _$GrokSessionSummaryDtoCopyWithImpl;
@useResult
$Res call({
 GrokSessionSummaryInfoDto? info,@JsonKey(name: "session_kind", unknownEnumValue: GrokSessionKind.unknown) GrokSessionKind? sessionKind,@JsonKey(name: "agent_name") String? agentName,@JsonKey(name: "generated_title") String? generatedTitle,@JsonKey(name: "created_at") String? createdAt,@JsonKey(name: "updated_at") String? updatedAt
});


$GrokSessionSummaryInfoDtoCopyWith<$Res>? get info;

}
/// @nodoc
class _$GrokSessionSummaryDtoCopyWithImpl<$Res>
    implements $GrokSessionSummaryDtoCopyWith<$Res> {
  _$GrokSessionSummaryDtoCopyWithImpl(this._self, this._then);

  final GrokSessionSummaryDto _self;
  final $Res Function(GrokSessionSummaryDto) _then;

/// Create a copy of GrokSessionSummaryDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? info = freezed,Object? sessionKind = freezed,Object? agentName = freezed,Object? generatedTitle = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(GrokSessionSummaryDto(
info: freezed == info ? _self.info : info // ignore: cast_nullable_to_non_nullable
as GrokSessionSummaryInfoDto?,sessionKind: freezed == sessionKind ? _self.sessionKind : sessionKind // ignore: cast_nullable_to_non_nullable
as GrokSessionKind?,agentName: freezed == agentName ? _self.agentName : agentName // ignore: cast_nullable_to_non_nullable
as String?,generatedTitle: freezed == generatedTitle ? _self.generatedTitle : generatedTitle // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of GrokSessionSummaryDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GrokSessionSummaryInfoDtoCopyWith<$Res>? get info {
    if (_self.info == null) {
    return null;
  }

  return $GrokSessionSummaryInfoDtoCopyWith<$Res>(_self.info!, (value) {
    return _then(_self.copyWith(info: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GrokSessionSummaryDto implements GrokSessionSummaryDto {
  const _GrokSessionSummaryDto({required this.info, @JsonKey(name: "session_kind", unknownEnumValue: GrokSessionKind.unknown) required this.sessionKind, @JsonKey(name: "agent_name") required this.agentName, @JsonKey(name: "generated_title") required this.generatedTitle, @JsonKey(name: "created_at") required this.createdAt, @JsonKey(name: "updated_at") required this.updatedAt});
  factory _GrokSessionSummaryDto.fromJson(Map<String, dynamic> json) => _$GrokSessionSummaryDtoFromJson(json);

@override final  GrokSessionSummaryInfoDto? info;
@override@JsonKey(name: "session_kind", unknownEnumValue: GrokSessionKind.unknown) final  GrokSessionKind? sessionKind;
@override@JsonKey(name: "agent_name") final  String? agentName;
@override@JsonKey(name: "generated_title") final  String? generatedTitle;
@override@JsonKey(name: "created_at") final  String? createdAt;
@override@JsonKey(name: "updated_at") final  String? updatedAt;

/// Create a copy of GrokSessionSummaryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GrokSessionSummaryDtoCopyWith<_GrokSessionSummaryDto> get copyWith => __$GrokSessionSummaryDtoCopyWithImpl<_GrokSessionSummaryDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GrokSessionSummaryDto&&(identical(other.info, info) || other.info == info)&&(identical(other.sessionKind, sessionKind) || other.sessionKind == sessionKind)&&(identical(other.agentName, agentName) || other.agentName == agentName)&&(identical(other.generatedTitle, generatedTitle) || other.generatedTitle == generatedTitle)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,info,sessionKind,agentName,generatedTitle,createdAt,updatedAt);
}

@override
String toString() {
    return 'GrokSessionSummaryDto(info: $info, sessionKind: $sessionKind, agentName: $agentName, generatedTitle: $generatedTitle, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$GrokSessionSummaryDtoCopyWith<$Res> implements $GrokSessionSummaryDtoCopyWith<$Res> {
  factory _$GrokSessionSummaryDtoCopyWith(_GrokSessionSummaryDto value, $Res Function(_GrokSessionSummaryDto) _then) = __$GrokSessionSummaryDtoCopyWithImpl;
@override @useResult
$Res call({
 GrokSessionSummaryInfoDto? info,@JsonKey(name: "session_kind", unknownEnumValue: GrokSessionKind.unknown) GrokSessionKind? sessionKind,@JsonKey(name: "agent_name") String? agentName,@JsonKey(name: "generated_title") String? generatedTitle,@JsonKey(name: "created_at") String? createdAt,@JsonKey(name: "updated_at") String? updatedAt
});


@override $GrokSessionSummaryInfoDtoCopyWith<$Res>? get info;

}
/// @nodoc
class __$GrokSessionSummaryDtoCopyWithImpl<$Res>
    implements _$GrokSessionSummaryDtoCopyWith<$Res> {
  __$GrokSessionSummaryDtoCopyWithImpl(this._self, this._then);

  final _GrokSessionSummaryDto _self;
  final $Res Function(_GrokSessionSummaryDto) _then;

/// Create a copy of GrokSessionSummaryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? info = freezed,Object? sessionKind = freezed,Object? agentName = freezed,Object? generatedTitle = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_GrokSessionSummaryDto(
info: freezed == info ? _self.info : info // ignore: cast_nullable_to_non_nullable
as GrokSessionSummaryInfoDto?,sessionKind: freezed == sessionKind ? _self.sessionKind : sessionKind // ignore: cast_nullable_to_non_nullable
as GrokSessionKind?,agentName: freezed == agentName ? _self.agentName : agentName // ignore: cast_nullable_to_non_nullable
as String?,generatedTitle: freezed == generatedTitle ? _self.generatedTitle : generatedTitle // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of GrokSessionSummaryDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GrokSessionSummaryInfoDtoCopyWith<$Res>? get info {
    if (_self.info == null) {
    return null;
  }

  return $GrokSessionSummaryInfoDtoCopyWith<$Res>(_self.info!, (value) {
    return _then(_self.copyWith(info: value));
  });
}
}


/// @nodoc
mixin _$GrokSessionSummaryInfoDto {

 String? get id; String? get cwd;
/// Create a copy of GrokSessionSummaryInfoDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GrokSessionSummaryInfoDtoCopyWith<GrokSessionSummaryInfoDto> get copyWith => _$GrokSessionSummaryInfoDtoCopyWithImpl<GrokSessionSummaryInfoDto>(this as GrokSessionSummaryInfoDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GrokSessionSummaryInfoDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokSessionSummaryInfoDto&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.cwd, _this.cwd) || other.cwd == _this.cwd));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GrokSessionSummaryInfoDto;
  return Object.hash(runtimeType,_this.id,_this.cwd);
}

@override
String toString() {
  final _this = this as GrokSessionSummaryInfoDto;
  return 'GrokSessionSummaryInfoDto(id: ${_this.id}, cwd: ${_this.cwd})';
}


}

/// @nodoc
abstract mixin class $GrokSessionSummaryInfoDtoCopyWith<$Res>  {
  factory $GrokSessionSummaryInfoDtoCopyWith(GrokSessionSummaryInfoDto value, $Res Function(GrokSessionSummaryInfoDto) _then) = _$GrokSessionSummaryInfoDtoCopyWithImpl;
@useResult
$Res call({
 String? id, String? cwd
});




}
/// @nodoc
class _$GrokSessionSummaryInfoDtoCopyWithImpl<$Res>
    implements $GrokSessionSummaryInfoDtoCopyWith<$Res> {
  _$GrokSessionSummaryInfoDtoCopyWithImpl(this._self, this._then);

  final GrokSessionSummaryInfoDto _self;
  final $Res Function(GrokSessionSummaryInfoDto) _then;

/// Create a copy of GrokSessionSummaryInfoDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? cwd = freezed,}) {
  return _then(GrokSessionSummaryInfoDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GrokSessionSummaryInfoDto implements GrokSessionSummaryInfoDto {
  const _GrokSessionSummaryInfoDto({required this.id, required this.cwd});
  factory _GrokSessionSummaryInfoDto.fromJson(Map<String, dynamic> json) => _$GrokSessionSummaryInfoDtoFromJson(json);

@override final  String? id;
@override final  String? cwd;

/// Create a copy of GrokSessionSummaryInfoDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GrokSessionSummaryInfoDtoCopyWith<_GrokSessionSummaryInfoDto> get copyWith => __$GrokSessionSummaryInfoDtoCopyWithImpl<_GrokSessionSummaryInfoDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GrokSessionSummaryInfoDto&&(identical(other.id, id) || other.id == id)&&(identical(other.cwd, cwd) || other.cwd == cwd));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,cwd);
}

@override
String toString() {
    return 'GrokSessionSummaryInfoDto(id: $id, cwd: $cwd)';
}


}

/// @nodoc
abstract mixin class _$GrokSessionSummaryInfoDtoCopyWith<$Res> implements $GrokSessionSummaryInfoDtoCopyWith<$Res> {
  factory _$GrokSessionSummaryInfoDtoCopyWith(_GrokSessionSummaryInfoDto value, $Res Function(_GrokSessionSummaryInfoDto) _then) = __$GrokSessionSummaryInfoDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id, String? cwd
});




}
/// @nodoc
class __$GrokSessionSummaryInfoDtoCopyWithImpl<$Res>
    implements _$GrokSessionSummaryInfoDtoCopyWith<$Res> {
  __$GrokSessionSummaryInfoDtoCopyWithImpl(this._self, this._then);

  final _GrokSessionSummaryInfoDto _self;
  final $Res Function(_GrokSessionSummaryInfoDto) _then;

/// Create a copy of GrokSessionSummaryInfoDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? cwd = freezed,}) {
  return _then(_GrokSessionSummaryInfoDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

GrokPersistedUpdateDto _$GrokPersistedUpdateDtoFromJson(
  Map<String, dynamic> json
) {
        switch (json['method']) {
                  case '_x.ai/session/update':
          return GrokPersistedGrokSessionUpdateDto.fromJson(
            json
          );
                case 'session/update':
          return GrokPersistedAcpSessionUpdateDto.fromJson(
            json
          );
        
          default:
            return GrokPersistedUpdateUnknownDto.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$GrokPersistedUpdateDto {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokPersistedUpdateDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'GrokPersistedUpdateDto()';
}


}

/// @nodoc
class $GrokPersistedUpdateDtoCopyWith<$Res>  {
$GrokPersistedUpdateDtoCopyWith(GrokPersistedUpdateDto _, $Res Function(GrokPersistedUpdateDto) __);
}



/// @nodoc
@JsonSerializable(createToJson: false)

class GrokPersistedGrokSessionUpdateDto implements GrokPersistedUpdateDto {
  const GrokPersistedGrokSessionUpdateDto({required this.params,  String? $type}): $type = $type ?? '_x.ai/session/update';
  factory GrokPersistedGrokSessionUpdateDto.fromJson(Map<String, dynamic> json) => _$GrokPersistedGrokSessionUpdateDtoFromJson(json);

 final  GrokSessionNotificationDto params;

@JsonKey(name: 'method')
final String $type;


/// Create a copy of GrokPersistedUpdateDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GrokPersistedGrokSessionUpdateDtoCopyWith<GrokPersistedGrokSessionUpdateDto> get copyWith => _$GrokPersistedGrokSessionUpdateDtoCopyWithImpl<GrokPersistedGrokSessionUpdateDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokPersistedGrokSessionUpdateDto&&(identical(other.params, params) || other.params == params));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,params);
}

@override
String toString() {
    return 'GrokPersistedUpdateDto.grokSessionUpdate(params: $params)';
}


}

/// @nodoc
abstract mixin class $GrokPersistedGrokSessionUpdateDtoCopyWith<$Res> implements $GrokPersistedUpdateDtoCopyWith<$Res> {
  factory $GrokPersistedGrokSessionUpdateDtoCopyWith(GrokPersistedGrokSessionUpdateDto value, $Res Function(GrokPersistedGrokSessionUpdateDto) _then) = _$GrokPersistedGrokSessionUpdateDtoCopyWithImpl;
@useResult
$Res call({
 GrokSessionNotificationDto params
});


$GrokSessionNotificationDtoCopyWith<$Res> get params;

}
/// @nodoc
class _$GrokPersistedGrokSessionUpdateDtoCopyWithImpl<$Res>
    implements $GrokPersistedGrokSessionUpdateDtoCopyWith<$Res> {
  _$GrokPersistedGrokSessionUpdateDtoCopyWithImpl(this._self, this._then);

  final GrokPersistedGrokSessionUpdateDto _self;
  final $Res Function(GrokPersistedGrokSessionUpdateDto) _then;

/// Create a copy of GrokPersistedUpdateDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? params = null,}) {
  return _then(GrokPersistedGrokSessionUpdateDto(
params: null == params ? _self.params : params // ignore: cast_nullable_to_non_nullable
as GrokSessionNotificationDto,
  ));
}

/// Create a copy of GrokPersistedUpdateDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GrokSessionNotificationDtoCopyWith<$Res> get params {
  
  return $GrokSessionNotificationDtoCopyWith<$Res>(_self.params, (value) {
    return _then(_self.copyWith(params: value));
  });
}
}

/// @nodoc
@JsonSerializable(createToJson: false)

class GrokPersistedAcpSessionUpdateDto implements GrokPersistedUpdateDto {
  const GrokPersistedAcpSessionUpdateDto({required this.params,  String? $type}): $type = $type ?? 'session/update';
  factory GrokPersistedAcpSessionUpdateDto.fromJson(Map<String, dynamic> json) => _$GrokPersistedAcpSessionUpdateDtoFromJson(json);

 final  GrokPersistedAcpNotificationDto params;

@JsonKey(name: 'method')
final String $type;


/// Create a copy of GrokPersistedUpdateDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GrokPersistedAcpSessionUpdateDtoCopyWith<GrokPersistedAcpSessionUpdateDto> get copyWith => _$GrokPersistedAcpSessionUpdateDtoCopyWithImpl<GrokPersistedAcpSessionUpdateDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokPersistedAcpSessionUpdateDto&&(identical(other.params, params) || other.params == params));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,params);
}

@override
String toString() {
    return 'GrokPersistedUpdateDto.acpSessionUpdate(params: $params)';
}


}

/// @nodoc
abstract mixin class $GrokPersistedAcpSessionUpdateDtoCopyWith<$Res> implements $GrokPersistedUpdateDtoCopyWith<$Res> {
  factory $GrokPersistedAcpSessionUpdateDtoCopyWith(GrokPersistedAcpSessionUpdateDto value, $Res Function(GrokPersistedAcpSessionUpdateDto) _then) = _$GrokPersistedAcpSessionUpdateDtoCopyWithImpl;
@useResult
$Res call({
 GrokPersistedAcpNotificationDto params
});


$GrokPersistedAcpNotificationDtoCopyWith<$Res> get params;

}
/// @nodoc
class _$GrokPersistedAcpSessionUpdateDtoCopyWithImpl<$Res>
    implements $GrokPersistedAcpSessionUpdateDtoCopyWith<$Res> {
  _$GrokPersistedAcpSessionUpdateDtoCopyWithImpl(this._self, this._then);

  final GrokPersistedAcpSessionUpdateDto _self;
  final $Res Function(GrokPersistedAcpSessionUpdateDto) _then;

/// Create a copy of GrokPersistedUpdateDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? params = null,}) {
  return _then(GrokPersistedAcpSessionUpdateDto(
params: null == params ? _self.params : params // ignore: cast_nullable_to_non_nullable
as GrokPersistedAcpNotificationDto,
  ));
}

/// Create a copy of GrokPersistedUpdateDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GrokPersistedAcpNotificationDtoCopyWith<$Res> get params {
  
  return $GrokPersistedAcpNotificationDtoCopyWith<$Res>(_self.params, (value) {
    return _then(_self.copyWith(params: value));
  });
}
}

/// @nodoc
@JsonSerializable(createToJson: false)

class GrokPersistedUpdateUnknownDto implements GrokPersistedUpdateDto {
  const GrokPersistedUpdateUnknownDto({ String? $type}): $type = $type ?? 'unknown';
  factory GrokPersistedUpdateUnknownDto.fromJson(Map<String, dynamic> json) => _$GrokPersistedUpdateUnknownDtoFromJson(json);



@JsonKey(name: 'method')
final String $type;





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokPersistedUpdateUnknownDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'GrokPersistedUpdateDto.unknown()';
}


}





/// @nodoc
mixin _$GrokPersistedAcpNotificationDto {

 String get sessionId; GrokPersistedAcpUpdateDto get update;
/// Create a copy of GrokPersistedAcpNotificationDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GrokPersistedAcpNotificationDtoCopyWith<GrokPersistedAcpNotificationDto> get copyWith => _$GrokPersistedAcpNotificationDtoCopyWithImpl<GrokPersistedAcpNotificationDto>(this as GrokPersistedAcpNotificationDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GrokPersistedAcpNotificationDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokPersistedAcpNotificationDto&&(identical(other.sessionId, _this.sessionId) || other.sessionId == _this.sessionId)&&(identical(other.update, _this.update) || other.update == _this.update));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GrokPersistedAcpNotificationDto;
  return Object.hash(runtimeType,_this.sessionId,_this.update);
}

@override
String toString() {
  final _this = this as GrokPersistedAcpNotificationDto;
  return 'GrokPersistedAcpNotificationDto(sessionId: ${_this.sessionId}, update: ${_this.update})';
}


}

/// @nodoc
abstract mixin class $GrokPersistedAcpNotificationDtoCopyWith<$Res>  {
  factory $GrokPersistedAcpNotificationDtoCopyWith(GrokPersistedAcpNotificationDto value, $Res Function(GrokPersistedAcpNotificationDto) _then) = _$GrokPersistedAcpNotificationDtoCopyWithImpl;
@useResult
$Res call({
 String sessionId, GrokPersistedAcpUpdateDto update
});


$GrokPersistedAcpUpdateDtoCopyWith<$Res> get update;

}
/// @nodoc
class _$GrokPersistedAcpNotificationDtoCopyWithImpl<$Res>
    implements $GrokPersistedAcpNotificationDtoCopyWith<$Res> {
  _$GrokPersistedAcpNotificationDtoCopyWithImpl(this._self, this._then);

  final GrokPersistedAcpNotificationDto _self;
  final $Res Function(GrokPersistedAcpNotificationDto) _then;

/// Create a copy of GrokPersistedAcpNotificationDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? update = null,}) {
  return _then(GrokPersistedAcpNotificationDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,update: null == update ? _self.update : update // ignore: cast_nullable_to_non_nullable
as GrokPersistedAcpUpdateDto,
  ));
}
/// Create a copy of GrokPersistedAcpNotificationDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GrokPersistedAcpUpdateDtoCopyWith<$Res> get update {
  
  return $GrokPersistedAcpUpdateDtoCopyWith<$Res>(_self.update, (value) {
    return _then(_self.copyWith(update: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GrokPersistedAcpNotificationDto implements GrokPersistedAcpNotificationDto {
  const _GrokPersistedAcpNotificationDto({required this.sessionId, required this.update});
  factory _GrokPersistedAcpNotificationDto.fromJson(Map<String, dynamic> json) => _$GrokPersistedAcpNotificationDtoFromJson(json);

@override final  String sessionId;
@override final  GrokPersistedAcpUpdateDto update;

/// Create a copy of GrokPersistedAcpNotificationDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GrokPersistedAcpNotificationDtoCopyWith<_GrokPersistedAcpNotificationDto> get copyWith => __$GrokPersistedAcpNotificationDtoCopyWithImpl<_GrokPersistedAcpNotificationDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GrokPersistedAcpNotificationDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.update, update) || other.update == update));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sessionId,update);
}

@override
String toString() {
    return 'GrokPersistedAcpNotificationDto(sessionId: $sessionId, update: $update)';
}


}

/// @nodoc
abstract mixin class _$GrokPersistedAcpNotificationDtoCopyWith<$Res> implements $GrokPersistedAcpNotificationDtoCopyWith<$Res> {
  factory _$GrokPersistedAcpNotificationDtoCopyWith(_GrokPersistedAcpNotificationDto value, $Res Function(_GrokPersistedAcpNotificationDto) _then) = __$GrokPersistedAcpNotificationDtoCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, GrokPersistedAcpUpdateDto update
});


@override $GrokPersistedAcpUpdateDtoCopyWith<$Res> get update;

}
/// @nodoc
class __$GrokPersistedAcpNotificationDtoCopyWithImpl<$Res>
    implements _$GrokPersistedAcpNotificationDtoCopyWith<$Res> {
  __$GrokPersistedAcpNotificationDtoCopyWithImpl(this._self, this._then);

  final _GrokPersistedAcpNotificationDto _self;
  final $Res Function(_GrokPersistedAcpNotificationDto) _then;

/// Create a copy of GrokPersistedAcpNotificationDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? update = null,}) {
  return _then(_GrokPersistedAcpNotificationDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,update: null == update ? _self.update : update // ignore: cast_nullable_to_non_nullable
as GrokPersistedAcpUpdateDto,
  ));
}

/// Create a copy of GrokPersistedAcpNotificationDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GrokPersistedAcpUpdateDtoCopyWith<$Res> get update {
  
  return $GrokPersistedAcpUpdateDtoCopyWith<$Res>(_self.update, (value) {
    return _then(_self.copyWith(update: value));
  });
}
}

GrokPersistedAcpUpdateDto _$GrokPersistedAcpUpdateDtoFromJson(
  Map<String, dynamic> json
) {
        switch (json['sessionUpdate']) {
                  case 'user_message_chunk':
          return GrokPersistedUserMessageChunkDto.fromJson(
            json
          );
        
          default:
            return GrokPersistedAcpUpdateUnknownDto.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$GrokPersistedAcpUpdateDto {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokPersistedAcpUpdateDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'GrokPersistedAcpUpdateDto()';
}


}

/// @nodoc
class $GrokPersistedAcpUpdateDtoCopyWith<$Res>  {
$GrokPersistedAcpUpdateDtoCopyWith(GrokPersistedAcpUpdateDto _, $Res Function(GrokPersistedAcpUpdateDto) __);
}



/// @nodoc
@JsonSerializable(createToJson: false)

class GrokPersistedUserMessageChunkDto implements GrokPersistedAcpUpdateDto {
  const GrokPersistedUserMessageChunkDto({required this.content,  String? $type}): $type = $type ?? 'user_message_chunk';
  factory GrokPersistedUserMessageChunkDto.fromJson(Map<String, dynamic> json) => _$GrokPersistedUserMessageChunkDtoFromJson(json);

 final  GrokPersistedContentDto content;

@JsonKey(name: 'sessionUpdate')
final String $type;


/// Create a copy of GrokPersistedAcpUpdateDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GrokPersistedUserMessageChunkDtoCopyWith<GrokPersistedUserMessageChunkDto> get copyWith => _$GrokPersistedUserMessageChunkDtoCopyWithImpl<GrokPersistedUserMessageChunkDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokPersistedUserMessageChunkDto&&(identical(other.content, content) || other.content == content));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,content);
}

@override
String toString() {
    return 'GrokPersistedAcpUpdateDto.userMessageChunk(content: $content)';
}


}

/// @nodoc
abstract mixin class $GrokPersistedUserMessageChunkDtoCopyWith<$Res> implements $GrokPersistedAcpUpdateDtoCopyWith<$Res> {
  factory $GrokPersistedUserMessageChunkDtoCopyWith(GrokPersistedUserMessageChunkDto value, $Res Function(GrokPersistedUserMessageChunkDto) _then) = _$GrokPersistedUserMessageChunkDtoCopyWithImpl;
@useResult
$Res call({
 GrokPersistedContentDto content
});


$GrokPersistedContentDtoCopyWith<$Res> get content;

}
/// @nodoc
class _$GrokPersistedUserMessageChunkDtoCopyWithImpl<$Res>
    implements $GrokPersistedUserMessageChunkDtoCopyWith<$Res> {
  _$GrokPersistedUserMessageChunkDtoCopyWithImpl(this._self, this._then);

  final GrokPersistedUserMessageChunkDto _self;
  final $Res Function(GrokPersistedUserMessageChunkDto) _then;

/// Create a copy of GrokPersistedAcpUpdateDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? content = null,}) {
  return _then(GrokPersistedUserMessageChunkDto(
content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as GrokPersistedContentDto,
  ));
}

/// Create a copy of GrokPersistedAcpUpdateDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GrokPersistedContentDtoCopyWith<$Res> get content {
  
  return $GrokPersistedContentDtoCopyWith<$Res>(_self.content, (value) {
    return _then(_self.copyWith(content: value));
  });
}
}

/// @nodoc
@JsonSerializable(createToJson: false)

class GrokPersistedAcpUpdateUnknownDto implements GrokPersistedAcpUpdateDto {
  const GrokPersistedAcpUpdateUnknownDto({ String? $type}): $type = $type ?? 'unknown';
  factory GrokPersistedAcpUpdateUnknownDto.fromJson(Map<String, dynamic> json) => _$GrokPersistedAcpUpdateUnknownDtoFromJson(json);



@JsonKey(name: 'sessionUpdate')
final String $type;





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokPersistedAcpUpdateUnknownDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'GrokPersistedAcpUpdateDto.unknown()';
}


}




GrokPersistedContentDto _$GrokPersistedContentDtoFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'text':
          return GrokPersistedTextContentDto.fromJson(
            json
          );
        
          default:
            return GrokPersistedContentUnknownDto.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$GrokPersistedContentDto {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokPersistedContentDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'GrokPersistedContentDto()';
}


}

/// @nodoc
class $GrokPersistedContentDtoCopyWith<$Res>  {
$GrokPersistedContentDtoCopyWith(GrokPersistedContentDto _, $Res Function(GrokPersistedContentDto) __);
}



/// @nodoc
@JsonSerializable(createToJson: false)

class GrokPersistedTextContentDto implements GrokPersistedContentDto {
  const GrokPersistedTextContentDto({required this.text,  String? $type}): $type = $type ?? 'text';
  factory GrokPersistedTextContentDto.fromJson(Map<String, dynamic> json) => _$GrokPersistedTextContentDtoFromJson(json);

 final  String text;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of GrokPersistedContentDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GrokPersistedTextContentDtoCopyWith<GrokPersistedTextContentDto> get copyWith => _$GrokPersistedTextContentDtoCopyWithImpl<GrokPersistedTextContentDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokPersistedTextContentDto&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,text);
}

@override
String toString() {
    return 'GrokPersistedContentDto.text(text: $text)';
}


}

/// @nodoc
abstract mixin class $GrokPersistedTextContentDtoCopyWith<$Res> implements $GrokPersistedContentDtoCopyWith<$Res> {
  factory $GrokPersistedTextContentDtoCopyWith(GrokPersistedTextContentDto value, $Res Function(GrokPersistedTextContentDto) _then) = _$GrokPersistedTextContentDtoCopyWithImpl;
@useResult
$Res call({
 String text
});




}
/// @nodoc
class _$GrokPersistedTextContentDtoCopyWithImpl<$Res>
    implements $GrokPersistedTextContentDtoCopyWith<$Res> {
  _$GrokPersistedTextContentDtoCopyWithImpl(this._self, this._then);

  final GrokPersistedTextContentDto _self;
  final $Res Function(GrokPersistedTextContentDto) _then;

/// Create a copy of GrokPersistedContentDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(GrokPersistedTextContentDto(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class GrokPersistedContentUnknownDto implements GrokPersistedContentDto {
  const GrokPersistedContentUnknownDto({ String? $type}): $type = $type ?? 'unknown';
  factory GrokPersistedContentUnknownDto.fromJson(Map<String, dynamic> json) => _$GrokPersistedContentUnknownDtoFromJson(json);



@JsonKey(name: 'type')
final String $type;





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokPersistedContentUnknownDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'GrokPersistedContentDto.unknown()';
}


}




// dart format on
