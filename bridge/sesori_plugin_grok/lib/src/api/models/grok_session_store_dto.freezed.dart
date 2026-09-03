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


/// @nodoc
mixin _$GrokPersistedUpdateDto {

 String? get method; Map<String, dynamic>? get params;
/// Create a copy of GrokPersistedUpdateDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GrokPersistedUpdateDtoCopyWith<GrokPersistedUpdateDto> get copyWith => _$GrokPersistedUpdateDtoCopyWithImpl<GrokPersistedUpdateDto>(this as GrokPersistedUpdateDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokPersistedUpdateDto&&(identical(other.method, method) || other.method == method)&&const DeepCollectionEquality().equals(other.params, params));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,method,const DeepCollectionEquality().hash(params));

@override
String toString() {
  return 'GrokPersistedUpdateDto(method: $method, params: $params)';
}


}

/// @nodoc
abstract mixin class $GrokPersistedUpdateDtoCopyWith<$Res>  {
  factory $GrokPersistedUpdateDtoCopyWith(GrokPersistedUpdateDto value, $Res Function(GrokPersistedUpdateDto) _then) = _$GrokPersistedUpdateDtoCopyWithImpl;
@useResult
$Res call({
 String? method, Map<String, dynamic>? params
});




}
/// @nodoc
class _$GrokPersistedUpdateDtoCopyWithImpl<$Res>
    implements $GrokPersistedUpdateDtoCopyWith<$Res> {
  _$GrokPersistedUpdateDtoCopyWithImpl(this._self, this._then);

  final GrokPersistedUpdateDto _self;
  final $Res Function(GrokPersistedUpdateDto) _then;

/// Create a copy of GrokPersistedUpdateDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? method = freezed,Object? params = freezed,}) {
  return _then(GrokPersistedUpdateDto(
method: freezed == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String?,params: freezed == params ? _self.params : params // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GrokPersistedUpdateDto implements GrokPersistedUpdateDto {
  const _GrokPersistedUpdateDto({required this.method, required  Map<String, dynamic>? params}): _params = params;
  factory _GrokPersistedUpdateDto.fromJson(Map<String, dynamic> json) => _$GrokPersistedUpdateDtoFromJson(json);

@override final  String? method;
 final  Map<String, dynamic>? _params;
@override Map<String, dynamic>? get params {
  final value = _params;
  if (value == null) return null;
  if (_params is EqualUnmodifiableMapView) return _params;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


/// Create a copy of GrokPersistedUpdateDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GrokPersistedUpdateDtoCopyWith<_GrokPersistedUpdateDto> get copyWith => __$GrokPersistedUpdateDtoCopyWithImpl<_GrokPersistedUpdateDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GrokPersistedUpdateDto&&(identical(other.method, method) || other.method == method)&&const DeepCollectionEquality().equals(other._params, _params));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,method,const DeepCollectionEquality().hash(_params));

@override
String toString() {
  return 'GrokPersistedUpdateDto(method: $method, params: $params)';
}


}

/// @nodoc
abstract mixin class _$GrokPersistedUpdateDtoCopyWith<$Res> implements $GrokPersistedUpdateDtoCopyWith<$Res> {
  factory _$GrokPersistedUpdateDtoCopyWith(_GrokPersistedUpdateDto value, $Res Function(_GrokPersistedUpdateDto) _then) = __$GrokPersistedUpdateDtoCopyWithImpl;
@override @useResult
$Res call({
 String? method, Map<String, dynamic>? params
});




}
/// @nodoc
class __$GrokPersistedUpdateDtoCopyWithImpl<$Res>
    implements _$GrokPersistedUpdateDtoCopyWith<$Res> {
  __$GrokPersistedUpdateDtoCopyWithImpl(this._self, this._then);

  final _GrokPersistedUpdateDto _self;
  final $Res Function(_GrokPersistedUpdateDto) _then;

/// Create a copy of GrokPersistedUpdateDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? method = freezed,Object? params = freezed,}) {
  return _then(_GrokPersistedUpdateDto(
method: freezed == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String?,params: freezed == params ? _self._params : params // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}


}

// dart format on
