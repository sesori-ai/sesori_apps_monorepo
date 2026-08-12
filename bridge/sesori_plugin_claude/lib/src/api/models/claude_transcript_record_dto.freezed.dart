// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'claude_transcript_record_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ClaudeTranscriptRecordDto {

@JsonKey(fromJson: _stringOrNull) String? get type;@JsonKey(fromJson: _stringOrNull) String? get sessionId;@JsonKey(fromJson: _stringOrNull) String? get cwd;@JsonKey(fromJson: _timestampOrNull) DateTime? get timestamp;@JsonKey(fromJson: _boolOrNull) bool? get isSidechain;@JsonKey(fromJson: _stringOrNull) String? get gitBranch;@JsonKey(fromJson: _stringOrNull) String? get version;@JsonKey(fromJson: _stringOrNull) String? get aiTitle;@JsonKey(fromJson: _stringOrNull) String? get uuid;@JsonKey(fromJson: _boolOrNull) bool? get isMeta;@JsonKey(fromJson: _boolOrNull) bool? get isVisibleInTranscriptOnly;@JsonKey(fromJson: _messageOrNull) ClaudeTranscriptMessageDto? get message;
/// Create a copy of ClaudeTranscriptRecordDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClaudeTranscriptRecordDtoCopyWith<ClaudeTranscriptRecordDto> get copyWith => _$ClaudeTranscriptRecordDtoCopyWithImpl<ClaudeTranscriptRecordDto>(this as ClaudeTranscriptRecordDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaudeTranscriptRecordDto&&(identical(other.type, type) || other.type == type)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.cwd, cwd) || other.cwd == cwd)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.isSidechain, isSidechain) || other.isSidechain == isSidechain)&&(identical(other.gitBranch, gitBranch) || other.gitBranch == gitBranch)&&(identical(other.version, version) || other.version == version)&&(identical(other.aiTitle, aiTitle) || other.aiTitle == aiTitle)&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.isMeta, isMeta) || other.isMeta == isMeta)&&(identical(other.isVisibleInTranscriptOnly, isVisibleInTranscriptOnly) || other.isVisibleInTranscriptOnly == isVisibleInTranscriptOnly)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,sessionId,cwd,timestamp,isSidechain,gitBranch,version,aiTitle,uuid,isMeta,isVisibleInTranscriptOnly,message);



}

/// @nodoc
abstract mixin class $ClaudeTranscriptRecordDtoCopyWith<$Res>  {
  factory $ClaudeTranscriptRecordDtoCopyWith(ClaudeTranscriptRecordDto value, $Res Function(ClaudeTranscriptRecordDto) _then) = _$ClaudeTranscriptRecordDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _stringOrNull) String? type,@JsonKey(fromJson: _stringOrNull) String? sessionId,@JsonKey(fromJson: _stringOrNull) String? cwd,@JsonKey(fromJson: _timestampOrNull) DateTime? timestamp,@JsonKey(fromJson: _boolOrNull) bool? isSidechain,@JsonKey(fromJson: _stringOrNull) String? gitBranch,@JsonKey(fromJson: _stringOrNull) String? version,@JsonKey(fromJson: _stringOrNull) String? aiTitle,@JsonKey(fromJson: _stringOrNull) String? uuid,@JsonKey(fromJson: _boolOrNull) bool? isMeta,@JsonKey(fromJson: _boolOrNull) bool? isVisibleInTranscriptOnly,@JsonKey(fromJson: _messageOrNull) ClaudeTranscriptMessageDto? message
});


$ClaudeTranscriptMessageDtoCopyWith<$Res>? get message;

}
/// @nodoc
class _$ClaudeTranscriptRecordDtoCopyWithImpl<$Res>
    implements $ClaudeTranscriptRecordDtoCopyWith<$Res> {
  _$ClaudeTranscriptRecordDtoCopyWithImpl(this._self, this._then);

  final ClaudeTranscriptRecordDto _self;
  final $Res Function(ClaudeTranscriptRecordDto) _then;

/// Create a copy of ClaudeTranscriptRecordDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = freezed,Object? sessionId = freezed,Object? cwd = freezed,Object? timestamp = freezed,Object? isSidechain = freezed,Object? gitBranch = freezed,Object? version = freezed,Object? aiTitle = freezed,Object? uuid = freezed,Object? isMeta = freezed,Object? isVisibleInTranscriptOnly = freezed,Object? message = freezed,}) {
  return _then(ClaudeTranscriptRecordDto(
type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,sessionId: freezed == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String?,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime?,isSidechain: freezed == isSidechain ? _self.isSidechain : isSidechain // ignore: cast_nullable_to_non_nullable
as bool?,gitBranch: freezed == gitBranch ? _self.gitBranch : gitBranch // ignore: cast_nullable_to_non_nullable
as String?,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,aiTitle: freezed == aiTitle ? _self.aiTitle : aiTitle // ignore: cast_nullable_to_non_nullable
as String?,uuid: freezed == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String?,isMeta: freezed == isMeta ? _self.isMeta : isMeta // ignore: cast_nullable_to_non_nullable
as bool?,isVisibleInTranscriptOnly: freezed == isVisibleInTranscriptOnly ? _self.isVisibleInTranscriptOnly : isVisibleInTranscriptOnly // ignore: cast_nullable_to_non_nullable
as bool?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as ClaudeTranscriptMessageDto?,
  ));
}
/// Create a copy of ClaudeTranscriptRecordDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClaudeTranscriptMessageDtoCopyWith<$Res>? get message {
    if (_self.message == null) {
    return null;
  }

  return $ClaudeTranscriptMessageDtoCopyWith<$Res>(_self.message!, (value) {
    return _then(_self.copyWith(message: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _ClaudeTranscriptRecordDto implements ClaudeTranscriptRecordDto {
  const _ClaudeTranscriptRecordDto({@JsonKey(fromJson: _stringOrNull) required this.type, @JsonKey(fromJson: _stringOrNull) required this.sessionId, @JsonKey(fromJson: _stringOrNull) required this.cwd, @JsonKey(fromJson: _timestampOrNull) required this.timestamp, @JsonKey(fromJson: _boolOrNull) required this.isSidechain, @JsonKey(fromJson: _stringOrNull) required this.gitBranch, @JsonKey(fromJson: _stringOrNull) required this.version, @JsonKey(fromJson: _stringOrNull) required this.aiTitle, @JsonKey(fromJson: _stringOrNull) required this.uuid, @JsonKey(fromJson: _boolOrNull) required this.isMeta, @JsonKey(fromJson: _boolOrNull) required this.isVisibleInTranscriptOnly, @JsonKey(fromJson: _messageOrNull) required this.message});
  factory _ClaudeTranscriptRecordDto.fromJson(Map<String, dynamic> json) => _$ClaudeTranscriptRecordDtoFromJson(json);

@override@JsonKey(fromJson: _stringOrNull) final  String? type;
@override@JsonKey(fromJson: _stringOrNull) final  String? sessionId;
@override@JsonKey(fromJson: _stringOrNull) final  String? cwd;
@override@JsonKey(fromJson: _timestampOrNull) final  DateTime? timestamp;
@override@JsonKey(fromJson: _boolOrNull) final  bool? isSidechain;
@override@JsonKey(fromJson: _stringOrNull) final  String? gitBranch;
@override@JsonKey(fromJson: _stringOrNull) final  String? version;
@override@JsonKey(fromJson: _stringOrNull) final  String? aiTitle;
@override@JsonKey(fromJson: _stringOrNull) final  String? uuid;
@override@JsonKey(fromJson: _boolOrNull) final  bool? isMeta;
@override@JsonKey(fromJson: _boolOrNull) final  bool? isVisibleInTranscriptOnly;
@override@JsonKey(fromJson: _messageOrNull) final  ClaudeTranscriptMessageDto? message;

/// Create a copy of ClaudeTranscriptRecordDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClaudeTranscriptRecordDtoCopyWith<_ClaudeTranscriptRecordDto> get copyWith => __$ClaudeTranscriptRecordDtoCopyWithImpl<_ClaudeTranscriptRecordDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClaudeTranscriptRecordDto&&(identical(other.type, type) || other.type == type)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.cwd, cwd) || other.cwd == cwd)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.isSidechain, isSidechain) || other.isSidechain == isSidechain)&&(identical(other.gitBranch, gitBranch) || other.gitBranch == gitBranch)&&(identical(other.version, version) || other.version == version)&&(identical(other.aiTitle, aiTitle) || other.aiTitle == aiTitle)&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.isMeta, isMeta) || other.isMeta == isMeta)&&(identical(other.isVisibleInTranscriptOnly, isVisibleInTranscriptOnly) || other.isVisibleInTranscriptOnly == isVisibleInTranscriptOnly)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,sessionId,cwd,timestamp,isSidechain,gitBranch,version,aiTitle,uuid,isMeta,isVisibleInTranscriptOnly,message);



}

/// @nodoc
abstract mixin class _$ClaudeTranscriptRecordDtoCopyWith<$Res> implements $ClaudeTranscriptRecordDtoCopyWith<$Res> {
  factory _$ClaudeTranscriptRecordDtoCopyWith(_ClaudeTranscriptRecordDto value, $Res Function(_ClaudeTranscriptRecordDto) _then) = __$ClaudeTranscriptRecordDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _stringOrNull) String? type,@JsonKey(fromJson: _stringOrNull) String? sessionId,@JsonKey(fromJson: _stringOrNull) String? cwd,@JsonKey(fromJson: _timestampOrNull) DateTime? timestamp,@JsonKey(fromJson: _boolOrNull) bool? isSidechain,@JsonKey(fromJson: _stringOrNull) String? gitBranch,@JsonKey(fromJson: _stringOrNull) String? version,@JsonKey(fromJson: _stringOrNull) String? aiTitle,@JsonKey(fromJson: _stringOrNull) String? uuid,@JsonKey(fromJson: _boolOrNull) bool? isMeta,@JsonKey(fromJson: _boolOrNull) bool? isVisibleInTranscriptOnly,@JsonKey(fromJson: _messageOrNull) ClaudeTranscriptMessageDto? message
});


@override $ClaudeTranscriptMessageDtoCopyWith<$Res>? get message;

}
/// @nodoc
class __$ClaudeTranscriptRecordDtoCopyWithImpl<$Res>
    implements _$ClaudeTranscriptRecordDtoCopyWith<$Res> {
  __$ClaudeTranscriptRecordDtoCopyWithImpl(this._self, this._then);

  final _ClaudeTranscriptRecordDto _self;
  final $Res Function(_ClaudeTranscriptRecordDto) _then;

/// Create a copy of ClaudeTranscriptRecordDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = freezed,Object? sessionId = freezed,Object? cwd = freezed,Object? timestamp = freezed,Object? isSidechain = freezed,Object? gitBranch = freezed,Object? version = freezed,Object? aiTitle = freezed,Object? uuid = freezed,Object? isMeta = freezed,Object? isVisibleInTranscriptOnly = freezed,Object? message = freezed,}) {
  return _then(_ClaudeTranscriptRecordDto(
type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,sessionId: freezed == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String?,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime?,isSidechain: freezed == isSidechain ? _self.isSidechain : isSidechain // ignore: cast_nullable_to_non_nullable
as bool?,gitBranch: freezed == gitBranch ? _self.gitBranch : gitBranch // ignore: cast_nullable_to_non_nullable
as String?,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,aiTitle: freezed == aiTitle ? _self.aiTitle : aiTitle // ignore: cast_nullable_to_non_nullable
as String?,uuid: freezed == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String?,isMeta: freezed == isMeta ? _self.isMeta : isMeta // ignore: cast_nullable_to_non_nullable
as bool?,isVisibleInTranscriptOnly: freezed == isVisibleInTranscriptOnly ? _self.isVisibleInTranscriptOnly : isVisibleInTranscriptOnly // ignore: cast_nullable_to_non_nullable
as bool?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as ClaudeTranscriptMessageDto?,
  ));
}

/// Create a copy of ClaudeTranscriptRecordDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClaudeTranscriptMessageDtoCopyWith<$Res>? get message {
    if (_self.message == null) {
    return null;
  }

  return $ClaudeTranscriptMessageDtoCopyWith<$Res>(_self.message!, (value) {
    return _then(_self.copyWith(message: value));
  });
}
}


/// @nodoc
mixin _$ClaudeTranscriptMessageDto {

@JsonKey(fromJson: _stringOrNull) String? get id;@JsonKey(fromJson: _stringOrNull) String? get model; Object? get content;
/// Create a copy of ClaudeTranscriptMessageDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClaudeTranscriptMessageDtoCopyWith<ClaudeTranscriptMessageDto> get copyWith => _$ClaudeTranscriptMessageDtoCopyWithImpl<ClaudeTranscriptMessageDto>(this as ClaudeTranscriptMessageDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaudeTranscriptMessageDto&&(identical(other.id, id) || other.id == id)&&(identical(other.model, model) || other.model == model)&&const DeepCollectionEquality().equals(other.content, content));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,model,const DeepCollectionEquality().hash(content));



}

/// @nodoc
abstract mixin class $ClaudeTranscriptMessageDtoCopyWith<$Res>  {
  factory $ClaudeTranscriptMessageDtoCopyWith(ClaudeTranscriptMessageDto value, $Res Function(ClaudeTranscriptMessageDto) _then) = _$ClaudeTranscriptMessageDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _stringOrNull) String? id,@JsonKey(fromJson: _stringOrNull) String? model, Object? content
});




}
/// @nodoc
class _$ClaudeTranscriptMessageDtoCopyWithImpl<$Res>
    implements $ClaudeTranscriptMessageDtoCopyWith<$Res> {
  _$ClaudeTranscriptMessageDtoCopyWithImpl(this._self, this._then);

  final ClaudeTranscriptMessageDto _self;
  final $Res Function(ClaudeTranscriptMessageDto) _then;

/// Create a copy of ClaudeTranscriptMessageDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? model = freezed,Object? content = freezed,}) {
  return _then(ClaudeTranscriptMessageDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,content: freezed == content ? _self.content : content ,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _ClaudeTranscriptMessageDto implements ClaudeTranscriptMessageDto {
  const _ClaudeTranscriptMessageDto({@JsonKey(fromJson: _stringOrNull) required this.id, @JsonKey(fromJson: _stringOrNull) required this.model, required this.content});
  factory _ClaudeTranscriptMessageDto.fromJson(Map<String, dynamic> json) => _$ClaudeTranscriptMessageDtoFromJson(json);

@override@JsonKey(fromJson: _stringOrNull) final  String? id;
@override@JsonKey(fromJson: _stringOrNull) final  String? model;
@override final  Object? content;

/// Create a copy of ClaudeTranscriptMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClaudeTranscriptMessageDtoCopyWith<_ClaudeTranscriptMessageDto> get copyWith => __$ClaudeTranscriptMessageDtoCopyWithImpl<_ClaudeTranscriptMessageDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClaudeTranscriptMessageDto&&(identical(other.id, id) || other.id == id)&&(identical(other.model, model) || other.model == model)&&const DeepCollectionEquality().equals(other.content, content));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,model,const DeepCollectionEquality().hash(content));



}

/// @nodoc
abstract mixin class _$ClaudeTranscriptMessageDtoCopyWith<$Res> implements $ClaudeTranscriptMessageDtoCopyWith<$Res> {
  factory _$ClaudeTranscriptMessageDtoCopyWith(_ClaudeTranscriptMessageDto value, $Res Function(_ClaudeTranscriptMessageDto) _then) = __$ClaudeTranscriptMessageDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _stringOrNull) String? id,@JsonKey(fromJson: _stringOrNull) String? model, Object? content
});




}
/// @nodoc
class __$ClaudeTranscriptMessageDtoCopyWithImpl<$Res>
    implements _$ClaudeTranscriptMessageDtoCopyWith<$Res> {
  __$ClaudeTranscriptMessageDtoCopyWithImpl(this._self, this._then);

  final _ClaudeTranscriptMessageDto _self;
  final $Res Function(_ClaudeTranscriptMessageDto) _then;

/// Create a copy of ClaudeTranscriptMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? model = freezed,Object? content = freezed,}) {
  return _then(_ClaudeTranscriptMessageDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,content: freezed == content ? _self.content : content ,
  ));
}


}

// dart format on
