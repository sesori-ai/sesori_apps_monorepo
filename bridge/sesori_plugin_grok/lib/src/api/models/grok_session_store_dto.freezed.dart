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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokSessionSummaryDto&&(identical(other.info, info) || other.info == info)&&(identical(other.sessionKind, sessionKind) || other.sessionKind == sessionKind)&&(identical(other.agentName, agentName) || other.agentName == agentName)&&(identical(other.generatedTitle, generatedTitle) || other.generatedTitle == generatedTitle)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,info,sessionKind,agentName,generatedTitle,createdAt,updatedAt);

@override
String toString() {
  return 'GrokSessionSummaryDto(info: $info, sessionKind: $sessionKind, agentName: $agentName, generatedTitle: $generatedTitle, createdAt: $createdAt, updatedAt: $updatedAt)';
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
int get hashCode => Object.hash(runtimeType,info,sessionKind,agentName,generatedTitle,createdAt,updatedAt);

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokSessionSummaryInfoDto&&(identical(other.id, id) || other.id == id)&&(identical(other.cwd, cwd) || other.cwd == cwd));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,cwd);

@override
String toString() {
  return 'GrokSessionSummaryInfoDto(id: $id, cwd: $cwd)';
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
int get hashCode => Object.hash(runtimeType,id,cwd);

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
          return GrokPersistedSessionUpdateDto.fromJson(
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

class GrokPersistedSessionUpdateDto implements GrokPersistedUpdateDto {
  const GrokPersistedSessionUpdateDto({required this.params,  String? $type}): $type = $type ?? '_x.ai/session/update';
  factory GrokPersistedSessionUpdateDto.fromJson(Map<String, dynamic> json) => _$GrokPersistedSessionUpdateDtoFromJson(json);

 final  GrokSessionNotificationDto params;

@JsonKey(name: 'method')
final String $type;


/// Create a copy of GrokPersistedUpdateDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GrokPersistedSessionUpdateDtoCopyWith<GrokPersistedSessionUpdateDto> get copyWith => _$GrokPersistedSessionUpdateDtoCopyWithImpl<GrokPersistedSessionUpdateDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokPersistedSessionUpdateDto&&(identical(other.params, params) || other.params == params));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,params);

@override
String toString() {
  return 'GrokPersistedUpdateDto.sessionUpdate(params: $params)';
}


}

/// @nodoc
abstract mixin class $GrokPersistedSessionUpdateDtoCopyWith<$Res> implements $GrokPersistedUpdateDtoCopyWith<$Res> {
  factory $GrokPersistedSessionUpdateDtoCopyWith(GrokPersistedSessionUpdateDto value, $Res Function(GrokPersistedSessionUpdateDto) _then) = _$GrokPersistedSessionUpdateDtoCopyWithImpl;
@useResult
$Res call({
 GrokSessionNotificationDto params
});


$GrokSessionNotificationDtoCopyWith<$Res> get params;

}
/// @nodoc
class _$GrokPersistedSessionUpdateDtoCopyWithImpl<$Res>
    implements $GrokPersistedSessionUpdateDtoCopyWith<$Res> {
  _$GrokPersistedSessionUpdateDtoCopyWithImpl(this._self, this._then);

  final GrokPersistedSessionUpdateDto _self;
  final $Res Function(GrokPersistedSessionUpdateDto) _then;

/// Create a copy of GrokPersistedUpdateDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? params = null,}) {
  return _then(GrokPersistedSessionUpdateDto(
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




// dart format on
