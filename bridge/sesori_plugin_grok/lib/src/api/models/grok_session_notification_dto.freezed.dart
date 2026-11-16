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

 String get sessionId; GrokSubagentUpdate get update;@JsonKey(name: "_meta") GrokEventMetaDto? get meta;
/// Create a copy of GrokSessionNotificationDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GrokSessionNotificationDtoCopyWith<GrokSessionNotificationDto> get copyWith => _$GrokSessionNotificationDtoCopyWithImpl<GrokSessionNotificationDto>(this as GrokSessionNotificationDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GrokSessionNotificationDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokSessionNotificationDto&&(identical(other.sessionId, _this.sessionId) || other.sessionId == _this.sessionId)&&(identical(other.update, _this.update) || other.update == _this.update)&&(identical(other.meta, _this.meta) || other.meta == _this.meta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GrokSessionNotificationDto;
  return Object.hash(runtimeType,_this.sessionId,_this.update,_this.meta);
}

@override
String toString() {
  final _this = this as GrokSessionNotificationDto;
  return 'GrokSessionNotificationDto(sessionId: ${_this.sessionId}, update: ${_this.update}, meta: ${_this.meta})';
}


}

/// @nodoc
abstract mixin class $GrokSessionNotificationDtoCopyWith<$Res>  {
  factory $GrokSessionNotificationDtoCopyWith(GrokSessionNotificationDto value, $Res Function(GrokSessionNotificationDto) _then) = _$GrokSessionNotificationDtoCopyWithImpl;
@useResult
$Res call({
 String sessionId, GrokSubagentUpdate update,@JsonKey(name: "_meta") GrokEventMetaDto? meta
});


$GrokSubagentUpdateCopyWith<$Res> get update;$GrokEventMetaDtoCopyWith<$Res>? get meta;

}
/// @nodoc
class _$GrokSessionNotificationDtoCopyWithImpl<$Res>
    implements $GrokSessionNotificationDtoCopyWith<$Res> {
  _$GrokSessionNotificationDtoCopyWithImpl(this._self, this._then);

  final GrokSessionNotificationDto _self;
  final $Res Function(GrokSessionNotificationDto) _then;

/// Create a copy of GrokSessionNotificationDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? update = null,Object? meta = freezed,}) {
  return _then(GrokSessionNotificationDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,update: null == update ? _self.update : update // ignore: cast_nullable_to_non_nullable
as GrokSubagentUpdate,meta: freezed == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as GrokEventMetaDto?,
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
}/// Create a copy of GrokSessionNotificationDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GrokEventMetaDtoCopyWith<$Res>? get meta {
    if (_self.meta == null) {
    return null;
  }

  return $GrokEventMetaDtoCopyWith<$Res>(_self.meta!, (value) {
    return _then(_self.copyWith(meta: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GrokSessionNotificationDto implements GrokSessionNotificationDto {
  const _GrokSessionNotificationDto({required this.sessionId, required this.update, @JsonKey(name: "_meta") required this.meta});
  factory _GrokSessionNotificationDto.fromJson(Map<String, dynamic> json) => _$GrokSessionNotificationDtoFromJson(json);

@override final  String sessionId;
@override final  GrokSubagentUpdate update;
@override@JsonKey(name: "_meta") final  GrokEventMetaDto? meta;

/// Create a copy of GrokSessionNotificationDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GrokSessionNotificationDtoCopyWith<_GrokSessionNotificationDto> get copyWith => __$GrokSessionNotificationDtoCopyWithImpl<_GrokSessionNotificationDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GrokSessionNotificationDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.update, update) || other.update == update)&&(identical(other.meta, meta) || other.meta == meta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sessionId,update,meta);
}

@override
String toString() {
    return 'GrokSessionNotificationDto(sessionId: $sessionId, update: $update, meta: $meta)';
}


}

/// @nodoc
abstract mixin class _$GrokSessionNotificationDtoCopyWith<$Res> implements $GrokSessionNotificationDtoCopyWith<$Res> {
  factory _$GrokSessionNotificationDtoCopyWith(_GrokSessionNotificationDto value, $Res Function(_GrokSessionNotificationDto) _then) = __$GrokSessionNotificationDtoCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, GrokSubagentUpdate update,@JsonKey(name: "_meta") GrokEventMetaDto? meta
});


@override $GrokSubagentUpdateCopyWith<$Res> get update;@override $GrokEventMetaDtoCopyWith<$Res>? get meta;

}
/// @nodoc
class __$GrokSessionNotificationDtoCopyWithImpl<$Res>
    implements _$GrokSessionNotificationDtoCopyWith<$Res> {
  __$GrokSessionNotificationDtoCopyWithImpl(this._self, this._then);

  final _GrokSessionNotificationDto _self;
  final $Res Function(_GrokSessionNotificationDto) _then;

/// Create a copy of GrokSessionNotificationDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? update = null,Object? meta = freezed,}) {
  return _then(_GrokSessionNotificationDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,update: null == update ? _self.update : update // ignore: cast_nullable_to_non_nullable
as GrokSubagentUpdate,meta: freezed == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as GrokEventMetaDto?,
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
}/// Create a copy of GrokSessionNotificationDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GrokEventMetaDtoCopyWith<$Res>? get meta {
    if (_self.meta == null) {
    return null;
  }

  return $GrokEventMetaDtoCopyWith<$Res>(_self.meta!, (value) {
    return _then(_self.copyWith(meta: value));
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
                case 'turn_completed':
          return GrokTurnCompleted.fromJson(
            json
          );
                case 'auto_compact_started':
          return GrokAutoCompactStarted.fromJson(
            json
          );
                case 'auto_compact_completed':
          return GrokAutoCompactCompleted.fromJson(
            json
          );
                case 'auto_compact_failed':
          return GrokAutoCompactFailed.fromJson(
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
int get hashCode {
    return Object.hash(runtimeType,subagentId,childSessionId,subagentType,description,model);
}

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
int get hashCode {
    return Object.hash(runtimeType,subagentId);
}

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
  const GrokSubagentFinished({@JsonKey(name: "subagent_id") required this.subagentId, @JsonKey(name: "child_session_id") required this.childSessionId, @JsonKey(unknownEnumValue: GrokSubagentStatus.unknown) required this.status, required this.output, required this.error, @JsonKey(name: "will_wake") required this.willWake,  String? $type}): $type = $type ?? 'subagent_finished';
  factory GrokSubagentFinished.fromJson(Map<String, dynamic> json) => _$GrokSubagentFinishedFromJson(json);

@JsonKey(name: "subagent_id") final  String subagentId;
@JsonKey(name: "child_session_id") final  String childSessionId;
@JsonKey(unknownEnumValue: GrokSubagentStatus.unknown) final  GrokSubagentStatus status;
 final  String? output;
 final  String? error;
@JsonKey(name: "will_wake") final  bool? willWake;

@JsonKey(name: 'sessionUpdate')
final String $type;


/// Create a copy of GrokSubagentUpdate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GrokSubagentFinishedCopyWith<GrokSubagentFinished> get copyWith => _$GrokSubagentFinishedCopyWithImpl<GrokSubagentFinished>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokSubagentFinished&&(identical(other.subagentId, subagentId) || other.subagentId == subagentId)&&(identical(other.childSessionId, childSessionId) || other.childSessionId == childSessionId)&&(identical(other.status, status) || other.status == status)&&(identical(other.output, output) || other.output == output)&&(identical(other.error, error) || other.error == error)&&(identical(other.willWake, willWake) || other.willWake == willWake));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,subagentId,childSessionId,status,output,error,willWake);
}

@override
String toString() {
    return 'GrokSubagentUpdate.subagentFinished(subagentId: $subagentId, childSessionId: $childSessionId, status: $status, output: $output, error: $error, willWake: $willWake)';
}


}

/// @nodoc
abstract mixin class $GrokSubagentFinishedCopyWith<$Res> implements $GrokSubagentUpdateCopyWith<$Res> {
  factory $GrokSubagentFinishedCopyWith(GrokSubagentFinished value, $Res Function(GrokSubagentFinished) _then) = _$GrokSubagentFinishedCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: "subagent_id") String subagentId,@JsonKey(name: "child_session_id") String childSessionId,@JsonKey(unknownEnumValue: GrokSubagentStatus.unknown) GrokSubagentStatus status, String? output, String? error,@JsonKey(name: "will_wake") bool? willWake
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
@pragma('vm:prefer-inline') $Res call({Object? subagentId = null,Object? childSessionId = null,Object? status = null,Object? output = freezed,Object? error = freezed,Object? willWake = freezed,}) {
  return _then(GrokSubagentFinished(
subagentId: null == subagentId ? _self.subagentId : subagentId // ignore: cast_nullable_to_non_nullable
as String,childSessionId: null == childSessionId ? _self.childSessionId : childSessionId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as GrokSubagentStatus,output: freezed == output ? _self.output : output // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,willWake: freezed == willWake ? _self.willWake : willWake // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class GrokTurnCompleted implements GrokSubagentUpdate {
  const GrokTurnCompleted({@JsonKey(name: "prompt_id") required this.promptId,  String? $type}): $type = $type ?? 'turn_completed';
  factory GrokTurnCompleted.fromJson(Map<String, dynamic> json) => _$GrokTurnCompletedFromJson(json);

@JsonKey(name: "prompt_id") final  String? promptId;

@JsonKey(name: 'sessionUpdate')
final String $type;


/// Create a copy of GrokSubagentUpdate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GrokTurnCompletedCopyWith<GrokTurnCompleted> get copyWith => _$GrokTurnCompletedCopyWithImpl<GrokTurnCompleted>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokTurnCompleted&&(identical(other.promptId, promptId) || other.promptId == promptId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,promptId);
}

@override
String toString() {
    return 'GrokSubagentUpdate.turnCompleted(promptId: $promptId)';
}


}

/// @nodoc
abstract mixin class $GrokTurnCompletedCopyWith<$Res> implements $GrokSubagentUpdateCopyWith<$Res> {
  factory $GrokTurnCompletedCopyWith(GrokTurnCompleted value, $Res Function(GrokTurnCompleted) _then) = _$GrokTurnCompletedCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: "prompt_id") String? promptId
});




}
/// @nodoc
class _$GrokTurnCompletedCopyWithImpl<$Res>
    implements $GrokTurnCompletedCopyWith<$Res> {
  _$GrokTurnCompletedCopyWithImpl(this._self, this._then);

  final GrokTurnCompleted _self;
  final $Res Function(GrokTurnCompleted) _then;

/// Create a copy of GrokSubagentUpdate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? promptId = freezed,}) {
  return _then(GrokTurnCompleted(
promptId: freezed == promptId ? _self.promptId : promptId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class GrokAutoCompactStarted implements GrokSubagentUpdate {
  const GrokAutoCompactStarted({ String? $type}): $type = $type ?? 'auto_compact_started';
  factory GrokAutoCompactStarted.fromJson(Map<String, dynamic> json) => _$GrokAutoCompactStartedFromJson(json);



@JsonKey(name: 'sessionUpdate')
final String $type;





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokAutoCompactStarted);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'GrokSubagentUpdate.autoCompactStarted()';
}


}




/// @nodoc
@JsonSerializable(createToJson: false)

class GrokAutoCompactCompleted implements GrokSubagentUpdate {
  const GrokAutoCompactCompleted({@JsonKey(name: "tokens_before") required this.tokensBefore, @JsonKey(name: "tokens_after") required this.tokensAfter,  String? $type}): $type = $type ?? 'auto_compact_completed';
  factory GrokAutoCompactCompleted.fromJson(Map<String, dynamic> json) => _$GrokAutoCompactCompletedFromJson(json);

@JsonKey(name: "tokens_before") final  int? tokensBefore;
@JsonKey(name: "tokens_after") final  int? tokensAfter;

@JsonKey(name: 'sessionUpdate')
final String $type;


/// Create a copy of GrokSubagentUpdate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GrokAutoCompactCompletedCopyWith<GrokAutoCompactCompleted> get copyWith => _$GrokAutoCompactCompletedCopyWithImpl<GrokAutoCompactCompleted>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokAutoCompactCompleted&&(identical(other.tokensBefore, tokensBefore) || other.tokensBefore == tokensBefore)&&(identical(other.tokensAfter, tokensAfter) || other.tokensAfter == tokensAfter));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,tokensBefore,tokensAfter);
}

@override
String toString() {
    return 'GrokSubagentUpdate.autoCompactCompleted(tokensBefore: $tokensBefore, tokensAfter: $tokensAfter)';
}


}

/// @nodoc
abstract mixin class $GrokAutoCompactCompletedCopyWith<$Res> implements $GrokSubagentUpdateCopyWith<$Res> {
  factory $GrokAutoCompactCompletedCopyWith(GrokAutoCompactCompleted value, $Res Function(GrokAutoCompactCompleted) _then) = _$GrokAutoCompactCompletedCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: "tokens_before") int? tokensBefore,@JsonKey(name: "tokens_after") int? tokensAfter
});




}
/// @nodoc
class _$GrokAutoCompactCompletedCopyWithImpl<$Res>
    implements $GrokAutoCompactCompletedCopyWith<$Res> {
  _$GrokAutoCompactCompletedCopyWithImpl(this._self, this._then);

  final GrokAutoCompactCompleted _self;
  final $Res Function(GrokAutoCompactCompleted) _then;

/// Create a copy of GrokSubagentUpdate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? tokensBefore = freezed,Object? tokensAfter = freezed,}) {
  return _then(GrokAutoCompactCompleted(
tokensBefore: freezed == tokensBefore ? _self.tokensBefore : tokensBefore // ignore: cast_nullable_to_non_nullable
as int?,tokensAfter: freezed == tokensAfter ? _self.tokensAfter : tokensAfter // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class GrokAutoCompactFailed implements GrokSubagentUpdate {
  const GrokAutoCompactFailed({required this.error,  String? $type}): $type = $type ?? 'auto_compact_failed';
  factory GrokAutoCompactFailed.fromJson(Map<String, dynamic> json) => _$GrokAutoCompactFailedFromJson(json);

 final  String? error;

@JsonKey(name: 'sessionUpdate')
final String $type;


/// Create a copy of GrokSubagentUpdate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GrokAutoCompactFailedCopyWith<GrokAutoCompactFailed> get copyWith => _$GrokAutoCompactFailedCopyWithImpl<GrokAutoCompactFailed>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokAutoCompactFailed&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,error);
}

@override
String toString() {
    return 'GrokSubagentUpdate.autoCompactFailed(error: $error)';
}


}

/// @nodoc
abstract mixin class $GrokAutoCompactFailedCopyWith<$Res> implements $GrokSubagentUpdateCopyWith<$Res> {
  factory $GrokAutoCompactFailedCopyWith(GrokAutoCompactFailed value, $Res Function(GrokAutoCompactFailed) _then) = _$GrokAutoCompactFailedCopyWithImpl;
@useResult
$Res call({
 String? error
});




}
/// @nodoc
class _$GrokAutoCompactFailedCopyWithImpl<$Res>
    implements $GrokAutoCompactFailedCopyWith<$Res> {
  _$GrokAutoCompactFailedCopyWithImpl(this._self, this._then);

  final GrokAutoCompactFailed _self;
  final $Res Function(GrokAutoCompactFailed) _then;

/// Create a copy of GrokSubagentUpdate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? error = freezed,}) {
  return _then(GrokAutoCompactFailed(
error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
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
mixin _$GrokQueueChangedDto {

 String get sessionId; String? get runningPromptId; String? get runningText;
/// Create a copy of GrokQueueChangedDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GrokQueueChangedDtoCopyWith<GrokQueueChangedDto> get copyWith => _$GrokQueueChangedDtoCopyWithImpl<GrokQueueChangedDto>(this as GrokQueueChangedDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GrokQueueChangedDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokQueueChangedDto&&(identical(other.sessionId, _this.sessionId) || other.sessionId == _this.sessionId)&&(identical(other.runningPromptId, _this.runningPromptId) || other.runningPromptId == _this.runningPromptId)&&(identical(other.runningText, _this.runningText) || other.runningText == _this.runningText));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GrokQueueChangedDto;
  return Object.hash(runtimeType,_this.sessionId,_this.runningPromptId,_this.runningText);
}

@override
String toString() {
  final _this = this as GrokQueueChangedDto;
  return 'GrokQueueChangedDto(sessionId: ${_this.sessionId}, runningPromptId: ${_this.runningPromptId}, runningText: ${_this.runningText})';
}


}

/// @nodoc
abstract mixin class $GrokQueueChangedDtoCopyWith<$Res>  {
  factory $GrokQueueChangedDtoCopyWith(GrokQueueChangedDto value, $Res Function(GrokQueueChangedDto) _then) = _$GrokQueueChangedDtoCopyWithImpl;
@useResult
$Res call({
 String sessionId, String? runningPromptId, String? runningText
});




}
/// @nodoc
class _$GrokQueueChangedDtoCopyWithImpl<$Res>
    implements $GrokQueueChangedDtoCopyWith<$Res> {
  _$GrokQueueChangedDtoCopyWithImpl(this._self, this._then);

  final GrokQueueChangedDto _self;
  final $Res Function(GrokQueueChangedDto) _then;

/// Create a copy of GrokQueueChangedDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? runningPromptId = freezed,Object? runningText = freezed,}) {
  return _then(GrokQueueChangedDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,runningPromptId: freezed == runningPromptId ? _self.runningPromptId : runningPromptId // ignore: cast_nullable_to_non_nullable
as String?,runningText: freezed == runningText ? _self.runningText : runningText // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GrokQueueChangedDto implements GrokQueueChangedDto {
  const _GrokQueueChangedDto({required this.sessionId, required this.runningPromptId, required this.runningText});
  factory _GrokQueueChangedDto.fromJson(Map<String, dynamic> json) => _$GrokQueueChangedDtoFromJson(json);

@override final  String sessionId;
@override final  String? runningPromptId;
@override final  String? runningText;

/// Create a copy of GrokQueueChangedDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GrokQueueChangedDtoCopyWith<_GrokQueueChangedDto> get copyWith => __$GrokQueueChangedDtoCopyWithImpl<_GrokQueueChangedDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GrokQueueChangedDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.runningPromptId, runningPromptId) || other.runningPromptId == runningPromptId)&&(identical(other.runningText, runningText) || other.runningText == runningText));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sessionId,runningPromptId,runningText);
}

@override
String toString() {
    return 'GrokQueueChangedDto(sessionId: $sessionId, runningPromptId: $runningPromptId, runningText: $runningText)';
}


}

/// @nodoc
abstract mixin class _$GrokQueueChangedDtoCopyWith<$Res> implements $GrokQueueChangedDtoCopyWith<$Res> {
  factory _$GrokQueueChangedDtoCopyWith(_GrokQueueChangedDto value, $Res Function(_GrokQueueChangedDto) _then) = __$GrokQueueChangedDtoCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, String? runningPromptId, String? runningText
});




}
/// @nodoc
class __$GrokQueueChangedDtoCopyWithImpl<$Res>
    implements _$GrokQueueChangedDtoCopyWith<$Res> {
  __$GrokQueueChangedDtoCopyWithImpl(this._self, this._then);

  final _GrokQueueChangedDto _self;
  final $Res Function(_GrokQueueChangedDto) _then;

/// Create a copy of GrokQueueChangedDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? runningPromptId = freezed,Object? runningText = freezed,}) {
  return _then(_GrokQueueChangedDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,runningPromptId: freezed == runningPromptId ? _self.runningPromptId : runningPromptId // ignore: cast_nullable_to_non_nullable
as String?,runningText: freezed == runningText ? _self.runningText : runningText // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$GrokEventMetaDto {

 String? get eventId; int? get agentTimestampMs;
/// Create a copy of GrokEventMetaDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GrokEventMetaDtoCopyWith<GrokEventMetaDto> get copyWith => _$GrokEventMetaDtoCopyWithImpl<GrokEventMetaDto>(this as GrokEventMetaDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GrokEventMetaDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokEventMetaDto&&(identical(other.eventId, _this.eventId) || other.eventId == _this.eventId)&&(identical(other.agentTimestampMs, _this.agentTimestampMs) || other.agentTimestampMs == _this.agentTimestampMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GrokEventMetaDto;
  return Object.hash(runtimeType,_this.eventId,_this.agentTimestampMs);
}

@override
String toString() {
  final _this = this as GrokEventMetaDto;
  return 'GrokEventMetaDto(eventId: ${_this.eventId}, agentTimestampMs: ${_this.agentTimestampMs})';
}


}

/// @nodoc
abstract mixin class $GrokEventMetaDtoCopyWith<$Res>  {
  factory $GrokEventMetaDtoCopyWith(GrokEventMetaDto value, $Res Function(GrokEventMetaDto) _then) = _$GrokEventMetaDtoCopyWithImpl;
@useResult
$Res call({
 String? eventId, int? agentTimestampMs
});




}
/// @nodoc
class _$GrokEventMetaDtoCopyWithImpl<$Res>
    implements $GrokEventMetaDtoCopyWith<$Res> {
  _$GrokEventMetaDtoCopyWithImpl(this._self, this._then);

  final GrokEventMetaDto _self;
  final $Res Function(GrokEventMetaDto) _then;

/// Create a copy of GrokEventMetaDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? eventId = freezed,Object? agentTimestampMs = freezed,}) {
  return _then(GrokEventMetaDto(
eventId: freezed == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as String?,agentTimestampMs: freezed == agentTimestampMs ? _self.agentTimestampMs : agentTimestampMs // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GrokEventMetaDto implements GrokEventMetaDto {
  const _GrokEventMetaDto({required this.eventId, required this.agentTimestampMs});
  factory _GrokEventMetaDto.fromJson(Map<String, dynamic> json) => _$GrokEventMetaDtoFromJson(json);

@override final  String? eventId;
@override final  int? agentTimestampMs;

/// Create a copy of GrokEventMetaDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GrokEventMetaDtoCopyWith<_GrokEventMetaDto> get copyWith => __$GrokEventMetaDtoCopyWithImpl<_GrokEventMetaDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GrokEventMetaDto&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.agentTimestampMs, agentTimestampMs) || other.agentTimestampMs == agentTimestampMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,eventId,agentTimestampMs);
}

@override
String toString() {
    return 'GrokEventMetaDto(eventId: $eventId, agentTimestampMs: $agentTimestampMs)';
}


}

/// @nodoc
abstract mixin class _$GrokEventMetaDtoCopyWith<$Res> implements $GrokEventMetaDtoCopyWith<$Res> {
  factory _$GrokEventMetaDtoCopyWith(_GrokEventMetaDto value, $Res Function(_GrokEventMetaDto) _then) = __$GrokEventMetaDtoCopyWithImpl;
@override @useResult
$Res call({
 String? eventId, int? agentTimestampMs
});




}
/// @nodoc
class __$GrokEventMetaDtoCopyWithImpl<$Res>
    implements _$GrokEventMetaDtoCopyWith<$Res> {
  __$GrokEventMetaDtoCopyWithImpl(this._self, this._then);

  final _GrokEventMetaDto _self;
  final $Res Function(_GrokEventMetaDto) _then;

/// Create a copy of GrokEventMetaDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? eventId = freezed,Object? agentTimestampMs = freezed,}) {
  return _then(_GrokEventMetaDto(
eventId: freezed == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as String?,agentTimestampMs: freezed == agentTimestampMs ? _self.agentTimestampMs : agentTimestampMs // ignore: cast_nullable_to_non_nullable
as int?,
  ));
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
  final _this = this as GrokToolCallMetaDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokToolCallMetaDto&&(identical(other.tool, _this.tool) || other.tool == _this.tool));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GrokToolCallMetaDto;
  return Object.hash(runtimeType,_this.tool);
}

@override
String toString() {
  final _this = this as GrokToolCallMetaDto;
  return 'GrokToolCallMetaDto(tool: ${_this.tool})';
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
int get hashCode {
    return Object.hash(runtimeType,tool);
}

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
  final _this = this as GrokToolIdentityDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokToolIdentityDto&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.kind, _this.kind) || other.kind == _this.kind));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GrokToolIdentityDto;
  return Object.hash(runtimeType,_this.name,_this.kind);
}

@override
String toString() {
  final _this = this as GrokToolIdentityDto;
  return 'GrokToolIdentityDto(name: ${_this.name}, kind: ${_this.kind})';
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
int get hashCode {
    return Object.hash(runtimeType,name,kind);
}

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


/// @nodoc
mixin _$GrokTerminalInputDto {

 String? get command;
/// Create a copy of GrokTerminalInputDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GrokTerminalInputDtoCopyWith<GrokTerminalInputDto> get copyWith => _$GrokTerminalInputDtoCopyWithImpl<GrokTerminalInputDto>(this as GrokTerminalInputDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GrokTerminalInputDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GrokTerminalInputDto&&(identical(other.command, _this.command) || other.command == _this.command));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GrokTerminalInputDto;
  return Object.hash(runtimeType,_this.command);
}

@override
String toString() {
  final _this = this as GrokTerminalInputDto;
  return 'GrokTerminalInputDto(command: ${_this.command})';
}


}

/// @nodoc
abstract mixin class $GrokTerminalInputDtoCopyWith<$Res>  {
  factory $GrokTerminalInputDtoCopyWith(GrokTerminalInputDto value, $Res Function(GrokTerminalInputDto) _then) = _$GrokTerminalInputDtoCopyWithImpl;
@useResult
$Res call({
 String? command
});




}
/// @nodoc
class _$GrokTerminalInputDtoCopyWithImpl<$Res>
    implements $GrokTerminalInputDtoCopyWith<$Res> {
  _$GrokTerminalInputDtoCopyWithImpl(this._self, this._then);

  final GrokTerminalInputDto _self;
  final $Res Function(GrokTerminalInputDto) _then;

/// Create a copy of GrokTerminalInputDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? command = freezed,}) {
  return _then(GrokTerminalInputDto(
command: freezed == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GrokTerminalInputDto implements GrokTerminalInputDto {
  const _GrokTerminalInputDto({required this.command});
  factory _GrokTerminalInputDto.fromJson(Map<String, dynamic> json) => _$GrokTerminalInputDtoFromJson(json);

@override final  String? command;

/// Create a copy of GrokTerminalInputDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GrokTerminalInputDtoCopyWith<_GrokTerminalInputDto> get copyWith => __$GrokTerminalInputDtoCopyWithImpl<_GrokTerminalInputDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GrokTerminalInputDto&&(identical(other.command, command) || other.command == command));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,command);
}

@override
String toString() {
    return 'GrokTerminalInputDto(command: $command)';
}


}

/// @nodoc
abstract mixin class _$GrokTerminalInputDtoCopyWith<$Res> implements $GrokTerminalInputDtoCopyWith<$Res> {
  factory _$GrokTerminalInputDtoCopyWith(_GrokTerminalInputDto value, $Res Function(_GrokTerminalInputDto) _then) = __$GrokTerminalInputDtoCopyWithImpl;
@override @useResult
$Res call({
 String? command
});




}
/// @nodoc
class __$GrokTerminalInputDtoCopyWithImpl<$Res>
    implements _$GrokTerminalInputDtoCopyWith<$Res> {
  __$GrokTerminalInputDtoCopyWithImpl(this._self, this._then);

  final _GrokTerminalInputDto _self;
  final $Res Function(_GrokTerminalInputDto) _then;

/// Create a copy of GrokTerminalInputDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? command = freezed,}) {
  return _then(_GrokTerminalInputDto(
command: freezed == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
