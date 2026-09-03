// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'grok_session_notification_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GrokSessionNotificationDto {

 String get sessionId; GrokSubagentUpdate get update;
/// Create a copy of GrokSessionNotificationDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GrokSessionNotificationDtoCopyWith<GrokSessionNotificationDto> get copyWith => _$GrokSessionNotificationDtoCopyWithImpl<GrokSessionNotificationDto>(this as GrokSessionNotificationDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokSessionNotificationDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.update, update) || other.update == update));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,update);

@override
String toString() {
  return 'GrokSessionNotificationDto(sessionId: $sessionId, update: $update)';
}


}

/// @nodoc
abstract mixin class $GrokSessionNotificationDtoCopyWith<$Res>  {
  factory $GrokSessionNotificationDtoCopyWith(GrokSessionNotificationDto value, $Res Function(GrokSessionNotificationDto) _then) = _$GrokSessionNotificationDtoCopyWithImpl;
@useResult
$Res call({
 String sessionId, GrokSubagentUpdate update
});


$GrokSubagentUpdateCopyWith<$Res> get update;

}
/// @nodoc
class _$GrokSessionNotificationDtoCopyWithImpl<$Res>
    implements $GrokSessionNotificationDtoCopyWith<$Res> {
  _$GrokSessionNotificationDtoCopyWithImpl(this._self, this._then);

  final GrokSessionNotificationDto _self;
  final $Res Function(GrokSessionNotificationDto) _then;

/// Create a copy of GrokSessionNotificationDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? update = null,}) {
  return _then(GrokSessionNotificationDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,update: null == update ? _self.update : update // ignore: cast_nullable_to_non_nullable
as GrokSubagentUpdate,
  ));
}
/// Create a copy of GrokSessionNotificationDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GrokSubagentUpdateCopyWith<$Res> get update {
  
  return $GrokSubagentUpdateCopyWith<$Res>(_self.update, (value) {
    return _then(_self.copyWith(update: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GrokSessionNotificationDto implements GrokSessionNotificationDto {
  const _GrokSessionNotificationDto({required this.sessionId, required this.update});
  factory _GrokSessionNotificationDto.fromJson(Map<String, dynamic> json) => _$GrokSessionNotificationDtoFromJson(json);

@override final  String sessionId;
@override final  GrokSubagentUpdate update;

/// Create a copy of GrokSessionNotificationDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GrokSessionNotificationDtoCopyWith<_GrokSessionNotificationDto> get copyWith => __$GrokSessionNotificationDtoCopyWithImpl<_GrokSessionNotificationDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GrokSessionNotificationDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.update, update) || other.update == update));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,update);

@override
String toString() {
  return 'GrokSessionNotificationDto(sessionId: $sessionId, update: $update)';
}


}

/// @nodoc
abstract mixin class _$GrokSessionNotificationDtoCopyWith<$Res> implements $GrokSessionNotificationDtoCopyWith<$Res> {
  factory _$GrokSessionNotificationDtoCopyWith(_GrokSessionNotificationDto value, $Res Function(_GrokSessionNotificationDto) _then) = __$GrokSessionNotificationDtoCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, GrokSubagentUpdate update
});


@override $GrokSubagentUpdateCopyWith<$Res> get update;

}
/// @nodoc
class __$GrokSessionNotificationDtoCopyWithImpl<$Res>
    implements _$GrokSessionNotificationDtoCopyWith<$Res> {
  __$GrokSessionNotificationDtoCopyWithImpl(this._self, this._then);

  final _GrokSessionNotificationDto _self;
  final $Res Function(_GrokSessionNotificationDto) _then;

/// Create a copy of GrokSessionNotificationDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? update = null,}) {
  return _then(_GrokSessionNotificationDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,update: null == update ? _self.update : update // ignore: cast_nullable_to_non_nullable
as GrokSubagentUpdate,
  ));
}

/// Create a copy of GrokSessionNotificationDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GrokSubagentUpdateCopyWith<$Res> get update {
  
  return $GrokSubagentUpdateCopyWith<$Res>(_self.update, (value) {
    return _then(_self.copyWith(update: value));
  });
}
}

GrokSubagentUpdate _$GrokSubagentUpdateFromJson(
  Map<String, dynamic> json
) {
        switch (json['sessionUpdate']) {
                  case 'subagent_spawned':
          return GrokSubagentSpawned.fromJson(
            json
          );
                case 'subagent_progress':
          return GrokSubagentProgress.fromJson(
            json
          );
                case 'subagent_finished':
          return GrokSubagentFinished.fromJson(
            json
          );
        
          default:
            return GrokSubagentUpdateUnknown.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$GrokSubagentUpdate {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokSubagentUpdate);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'GrokSubagentUpdate()';
}


}

/// @nodoc
class $GrokSubagentUpdateCopyWith<$Res>  {
$GrokSubagentUpdateCopyWith(GrokSubagentUpdate _, $Res Function(GrokSubagentUpdate) __);
}



/// @nodoc
@JsonSerializable(createToJson: false)

class GrokSubagentSpawned implements GrokSubagentUpdate {
  const GrokSubagentSpawned({@JsonKey(name: "subagent_id") required this.subagentId, @JsonKey(name: "child_session_id") required this.childSessionId, @JsonKey(name: "subagent_type") required this.subagentType, required this.description, required this.model,  String? $type}): $type = $type ?? 'subagent_spawned';
  factory GrokSubagentSpawned.fromJson(Map<String, dynamic> json) => _$GrokSubagentSpawnedFromJson(json);

@JsonKey(name: "subagent_id") final  String subagentId;
@JsonKey(name: "child_session_id") final  String childSessionId;
@JsonKey(name: "subagent_type") final  String? subagentType;
 final  String? description;
/// The model the child runs on, which may differ from the root's.
 final  String? model;

@JsonKey(name: 'sessionUpdate')
final String $type;


/// Create a copy of GrokSubagentUpdate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GrokSubagentSpawnedCopyWith<GrokSubagentSpawned> get copyWith => _$GrokSubagentSpawnedCopyWithImpl<GrokSubagentSpawned>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokSubagentSpawned&&(identical(other.subagentId, subagentId) || other.subagentId == subagentId)&&(identical(other.childSessionId, childSessionId) || other.childSessionId == childSessionId)&&(identical(other.subagentType, subagentType) || other.subagentType == subagentType)&&(identical(other.description, description) || other.description == description)&&(identical(other.model, model) || other.model == model));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,subagentId,childSessionId,subagentType,description,model);

@override
String toString() {
  return 'GrokSubagentUpdate.subagentSpawned(subagentId: $subagentId, childSessionId: $childSessionId, subagentType: $subagentType, description: $description, model: $model)';
}


}

/// @nodoc
abstract mixin class $GrokSubagentSpawnedCopyWith<$Res> implements $GrokSubagentUpdateCopyWith<$Res> {
  factory $GrokSubagentSpawnedCopyWith(GrokSubagentSpawned value, $Res Function(GrokSubagentSpawned) _then) = _$GrokSubagentSpawnedCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: "subagent_id") String subagentId,@JsonKey(name: "child_session_id") String childSessionId,@JsonKey(name: "subagent_type") String? subagentType, String? description, String? model
});




}
/// @nodoc
class _$GrokSubagentSpawnedCopyWithImpl<$Res>
    implements $GrokSubagentSpawnedCopyWith<$Res> {
  _$GrokSubagentSpawnedCopyWithImpl(this._self, this._then);

  final GrokSubagentSpawned _self;
  final $Res Function(GrokSubagentSpawned) _then;

/// Create a copy of GrokSubagentUpdate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? subagentId = null,Object? childSessionId = null,Object? subagentType = freezed,Object? description = freezed,Object? model = freezed,}) {
  return _then(GrokSubagentSpawned(
subagentId: null == subagentId ? _self.subagentId : subagentId // ignore: cast_nullable_to_non_nullable
as String,childSessionId: null == childSessionId ? _self.childSessionId : childSessionId // ignore: cast_nullable_to_non_nullable
as String,subagentType: freezed == subagentType ? _self.subagentType : subagentType // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class GrokSubagentProgress implements GrokSubagentUpdate {
  const GrokSubagentProgress({@JsonKey(name: "subagent_id") required this.subagentId,  String? $type}): $type = $type ?? 'subagent_progress';
  factory GrokSubagentProgress.fromJson(Map<String, dynamic> json) => _$GrokSubagentProgressFromJson(json);

@JsonKey(name: "subagent_id") final  String subagentId;

@JsonKey(name: 'sessionUpdate')
final String $type;


/// Create a copy of GrokSubagentUpdate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GrokSubagentProgressCopyWith<GrokSubagentProgress> get copyWith => _$GrokSubagentProgressCopyWithImpl<GrokSubagentProgress>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokSubagentProgress&&(identical(other.subagentId, subagentId) || other.subagentId == subagentId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,subagentId);

@override
String toString() {
  return 'GrokSubagentUpdate.subagentProgress(subagentId: $subagentId)';
}


}

/// @nodoc
abstract mixin class $GrokSubagentProgressCopyWith<$Res> implements $GrokSubagentUpdateCopyWith<$Res> {
  factory $GrokSubagentProgressCopyWith(GrokSubagentProgress value, $Res Function(GrokSubagentProgress) _then) = _$GrokSubagentProgressCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: "subagent_id") String subagentId
});




}
/// @nodoc
class _$GrokSubagentProgressCopyWithImpl<$Res>
    implements $GrokSubagentProgressCopyWith<$Res> {
  _$GrokSubagentProgressCopyWithImpl(this._self, this._then);

  final GrokSubagentProgress _self;
  final $Res Function(GrokSubagentProgress) _then;

/// Create a copy of GrokSubagentUpdate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? subagentId = null,}) {
  return _then(GrokSubagentProgress(
subagentId: null == subagentId ? _self.subagentId : subagentId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class GrokSubagentFinished implements GrokSubagentUpdate {
  const GrokSubagentFinished({@JsonKey(name: "subagent_id") required this.subagentId, @JsonKey(name: "child_session_id") required this.childSessionId, @JsonKey(unknownEnumValue: GrokSubagentStatus.unknown) required this.status, required this.output, required this.error,  String? $type}): $type = $type ?? 'subagent_finished';
  factory GrokSubagentFinished.fromJson(Map<String, dynamic> json) => _$GrokSubagentFinishedFromJson(json);

@JsonKey(name: "subagent_id") final  String subagentId;
@JsonKey(name: "child_session_id") final  String childSessionId;
@JsonKey(unknownEnumValue: GrokSubagentStatus.unknown) final  GrokSubagentStatus status;
 final  String? output;
 final  String? error;

@JsonKey(name: 'sessionUpdate')
final String $type;


/// Create a copy of GrokSubagentUpdate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GrokSubagentFinishedCopyWith<GrokSubagentFinished> get copyWith => _$GrokSubagentFinishedCopyWithImpl<GrokSubagentFinished>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokSubagentFinished&&(identical(other.subagentId, subagentId) || other.subagentId == subagentId)&&(identical(other.childSessionId, childSessionId) || other.childSessionId == childSessionId)&&(identical(other.status, status) || other.status == status)&&(identical(other.output, output) || other.output == output)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,subagentId,childSessionId,status,output,error);

@override
String toString() {
  return 'GrokSubagentUpdate.subagentFinished(subagentId: $subagentId, childSessionId: $childSessionId, status: $status, output: $output, error: $error)';
}


}

/// @nodoc
abstract mixin class $GrokSubagentFinishedCopyWith<$Res> implements $GrokSubagentUpdateCopyWith<$Res> {
  factory $GrokSubagentFinishedCopyWith(GrokSubagentFinished value, $Res Function(GrokSubagentFinished) _then) = _$GrokSubagentFinishedCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: "subagent_id") String subagentId,@JsonKey(name: "child_session_id") String childSessionId,@JsonKey(unknownEnumValue: GrokSubagentStatus.unknown) GrokSubagentStatus status, String? output, String? error
});




}
/// @nodoc
class _$GrokSubagentFinishedCopyWithImpl<$Res>
    implements $GrokSubagentFinishedCopyWith<$Res> {
  _$GrokSubagentFinishedCopyWithImpl(this._self, this._then);

  final GrokSubagentFinished _self;
  final $Res Function(GrokSubagentFinished) _then;

/// Create a copy of GrokSubagentUpdate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? subagentId = null,Object? childSessionId = null,Object? status = null,Object? output = freezed,Object? error = freezed,}) {
  return _then(GrokSubagentFinished(
subagentId: null == subagentId ? _self.subagentId : subagentId // ignore: cast_nullable_to_non_nullable
as String,childSessionId: null == childSessionId ? _self.childSessionId : childSessionId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as GrokSubagentStatus,output: freezed == output ? _self.output : output // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class GrokSubagentUpdateUnknown implements GrokSubagentUpdate {
  const GrokSubagentUpdateUnknown({ String? $type}): $type = $type ?? 'unknown';
  factory GrokSubagentUpdateUnknown.fromJson(Map<String, dynamic> json) => _$GrokSubagentUpdateUnknownFromJson(json);



@JsonKey(name: 'sessionUpdate')
final String $type;





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokSubagentUpdateUnknown);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'GrokSubagentUpdate.unknown()';
}


}





/// @nodoc
mixin _$GrokToolCallMetaDto {

@JsonKey(name: "x.ai/tool") GrokToolIdentityDto? get tool;
/// Create a copy of GrokToolCallMetaDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GrokToolCallMetaDtoCopyWith<GrokToolCallMetaDto> get copyWith => _$GrokToolCallMetaDtoCopyWithImpl<GrokToolCallMetaDto>(this as GrokToolCallMetaDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokToolCallMetaDto&&(identical(other.tool, tool) || other.tool == tool));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,tool);

@override
String toString() {
  return 'GrokToolCallMetaDto(tool: $tool)';
}


}

/// @nodoc
abstract mixin class $GrokToolCallMetaDtoCopyWith<$Res>  {
  factory $GrokToolCallMetaDtoCopyWith(GrokToolCallMetaDto value, $Res Function(GrokToolCallMetaDto) _then) = _$GrokToolCallMetaDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: "x.ai/tool") GrokToolIdentityDto? tool
});


$GrokToolIdentityDtoCopyWith<$Res>? get tool;

}
/// @nodoc
class _$GrokToolCallMetaDtoCopyWithImpl<$Res>
    implements $GrokToolCallMetaDtoCopyWith<$Res> {
  _$GrokToolCallMetaDtoCopyWithImpl(this._self, this._then);

  final GrokToolCallMetaDto _self;
  final $Res Function(GrokToolCallMetaDto) _then;

/// Create a copy of GrokToolCallMetaDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? tool = freezed,}) {
  return _then(GrokToolCallMetaDto(
tool: freezed == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as GrokToolIdentityDto?,
  ));
}
/// Create a copy of GrokToolCallMetaDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GrokToolIdentityDtoCopyWith<$Res>? get tool {
    if (_self.tool == null) {
    return null;
  }

  return $GrokToolIdentityDtoCopyWith<$Res>(_self.tool!, (value) {
    return _then(_self.copyWith(tool: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GrokToolCallMetaDto implements GrokToolCallMetaDto {
  const _GrokToolCallMetaDto({@JsonKey(name: "x.ai/tool") required this.tool});
  factory _GrokToolCallMetaDto.fromJson(Map<String, dynamic> json) => _$GrokToolCallMetaDtoFromJson(json);

@override@JsonKey(name: "x.ai/tool") final  GrokToolIdentityDto? tool;

/// Create a copy of GrokToolCallMetaDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GrokToolCallMetaDtoCopyWith<_GrokToolCallMetaDto> get copyWith => __$GrokToolCallMetaDtoCopyWithImpl<_GrokToolCallMetaDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GrokToolCallMetaDto&&(identical(other.tool, tool) || other.tool == tool));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,tool);

@override
String toString() {
  return 'GrokToolCallMetaDto(tool: $tool)';
}


}

/// @nodoc
abstract mixin class _$GrokToolCallMetaDtoCopyWith<$Res> implements $GrokToolCallMetaDtoCopyWith<$Res> {
  factory _$GrokToolCallMetaDtoCopyWith(_GrokToolCallMetaDto value, $Res Function(_GrokToolCallMetaDto) _then) = __$GrokToolCallMetaDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: "x.ai/tool") GrokToolIdentityDto? tool
});


@override $GrokToolIdentityDtoCopyWith<$Res>? get tool;

}
/// @nodoc
class __$GrokToolCallMetaDtoCopyWithImpl<$Res>
    implements _$GrokToolCallMetaDtoCopyWith<$Res> {
  __$GrokToolCallMetaDtoCopyWithImpl(this._self, this._then);

  final _GrokToolCallMetaDto _self;
  final $Res Function(_GrokToolCallMetaDto) _then;

/// Create a copy of GrokToolCallMetaDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? tool = freezed,}) {
  return _then(_GrokToolCallMetaDto(
tool: freezed == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as GrokToolIdentityDto?,
  ));
}

/// Create a copy of GrokToolCallMetaDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GrokToolIdentityDtoCopyWith<$Res>? get tool {
    if (_self.tool == null) {
    return null;
  }

  return $GrokToolIdentityDtoCopyWith<$Res>(_self.tool!, (value) {
    return _then(_self.copyWith(tool: value));
  });
}
}


/// @nodoc
mixin _$GrokToolIdentityDto {

 String? get name; String? get kind;
/// Create a copy of GrokToolIdentityDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GrokToolIdentityDtoCopyWith<GrokToolIdentityDto> get copyWith => _$GrokToolIdentityDtoCopyWithImpl<GrokToolIdentityDto>(this as GrokToolIdentityDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokToolIdentityDto&&(identical(other.name, name) || other.name == name)&&(identical(other.kind, kind) || other.kind == kind));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,kind);

@override
String toString() {
  return 'GrokToolIdentityDto(name: $name, kind: $kind)';
}


}

/// @nodoc
abstract mixin class $GrokToolIdentityDtoCopyWith<$Res>  {
  factory $GrokToolIdentityDtoCopyWith(GrokToolIdentityDto value, $Res Function(GrokToolIdentityDto) _then) = _$GrokToolIdentityDtoCopyWithImpl;
@useResult
$Res call({
 String? name, String? kind
});




}
/// @nodoc
class _$GrokToolIdentityDtoCopyWithImpl<$Res>
    implements $GrokToolIdentityDtoCopyWith<$Res> {
  _$GrokToolIdentityDtoCopyWithImpl(this._self, this._then);

  final GrokToolIdentityDto _self;
  final $Res Function(GrokToolIdentityDto) _then;

/// Create a copy of GrokToolIdentityDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = freezed,Object? kind = freezed,}) {
  return _then(GrokToolIdentityDto(
name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GrokToolIdentityDto implements GrokToolIdentityDto {
  const _GrokToolIdentityDto({required this.name, required this.kind});
  factory _GrokToolIdentityDto.fromJson(Map<String, dynamic> json) => _$GrokToolIdentityDtoFromJson(json);

@override final  String? name;
@override final  String? kind;

/// Create a copy of GrokToolIdentityDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GrokToolIdentityDtoCopyWith<_GrokToolIdentityDto> get copyWith => __$GrokToolIdentityDtoCopyWithImpl<_GrokToolIdentityDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GrokToolIdentityDto&&(identical(other.name, name) || other.name == name)&&(identical(other.kind, kind) || other.kind == kind));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,kind);

@override
String toString() {
  return 'GrokToolIdentityDto(name: $name, kind: $kind)';
}


}

/// @nodoc
abstract mixin class _$GrokToolIdentityDtoCopyWith<$Res> implements $GrokToolIdentityDtoCopyWith<$Res> {
  factory _$GrokToolIdentityDtoCopyWith(_GrokToolIdentityDto value, $Res Function(_GrokToolIdentityDto) _then) = __$GrokToolIdentityDtoCopyWithImpl;
@override @useResult
$Res call({
 String? name, String? kind
});




}
/// @nodoc
class __$GrokToolIdentityDtoCopyWithImpl<$Res>
    implements _$GrokToolIdentityDtoCopyWith<$Res> {
  __$GrokToolIdentityDtoCopyWithImpl(this._self, this._then);

  final _GrokToolIdentityDto _self;
  final $Res Function(_GrokToolIdentityDto) _then;

/// Create a copy of GrokToolIdentityDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = freezed,Object? kind = freezed,}) {
  return _then(_GrokToolIdentityDto(
name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
