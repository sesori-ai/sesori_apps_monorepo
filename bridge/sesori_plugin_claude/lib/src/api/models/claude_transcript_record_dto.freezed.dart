// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'claude_transcript_record_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ClaudeTranscriptRecordDto {

@JsonKey(fromJson: _stringOrNull) String? get type;@JsonKey(fromJson: _stringOrNull) String? get sessionId;@JsonKey(fromJson: _stringOrNull) String? get cwd;@JsonKey(fromJson: _timestampOrNull) DateTime? get timestamp;@JsonKey(fromJson: _boolOrNull) bool? get isSidechain;@JsonKey(fromJson: _stringOrNull) String? get gitBranch;@JsonKey(fromJson: _stringOrNull) String? get version;@JsonKey(fromJson: _stringOrNull) String? get aiTitle;
/// Create a copy of ClaudeTranscriptRecordDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClaudeTranscriptRecordDtoCopyWith<ClaudeTranscriptRecordDto> get copyWith => _$ClaudeTranscriptRecordDtoCopyWithImpl<ClaudeTranscriptRecordDto>(this as ClaudeTranscriptRecordDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaudeTranscriptRecordDto&&(identical(other.type, type) || other.type == type)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.cwd, cwd) || other.cwd == cwd)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.isSidechain, isSidechain) || other.isSidechain == isSidechain)&&(identical(other.gitBranch, gitBranch) || other.gitBranch == gitBranch)&&(identical(other.version, version) || other.version == version)&&(identical(other.aiTitle, aiTitle) || other.aiTitle == aiTitle));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,sessionId,cwd,timestamp,isSidechain,gitBranch,version,aiTitle);

@override
String toString() {
  return 'ClaudeTranscriptRecordDto(type: $type, sessionId: $sessionId, cwd: $cwd, timestamp: $timestamp, isSidechain: $isSidechain, gitBranch: $gitBranch, version: $version, aiTitle: $aiTitle)';
}


}

/// @nodoc
abstract mixin class $ClaudeTranscriptRecordDtoCopyWith<$Res>  {
  factory $ClaudeTranscriptRecordDtoCopyWith(ClaudeTranscriptRecordDto value, $Res Function(ClaudeTranscriptRecordDto) _then) = _$ClaudeTranscriptRecordDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _stringOrNull) String? type,@JsonKey(fromJson: _stringOrNull) String? sessionId,@JsonKey(fromJson: _stringOrNull) String? cwd,@JsonKey(fromJson: _timestampOrNull) DateTime? timestamp,@JsonKey(fromJson: _boolOrNull) bool? isSidechain,@JsonKey(fromJson: _stringOrNull) String? gitBranch,@JsonKey(fromJson: _stringOrNull) String? version,@JsonKey(fromJson: _stringOrNull) String? aiTitle
});




}
/// @nodoc
class _$ClaudeTranscriptRecordDtoCopyWithImpl<$Res>
    implements $ClaudeTranscriptRecordDtoCopyWith<$Res> {
  _$ClaudeTranscriptRecordDtoCopyWithImpl(this._self, this._then);

  final ClaudeTranscriptRecordDto _self;
  final $Res Function(ClaudeTranscriptRecordDto) _then;

/// Create a copy of ClaudeTranscriptRecordDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = freezed,Object? sessionId = freezed,Object? cwd = freezed,Object? timestamp = freezed,Object? isSidechain = freezed,Object? gitBranch = freezed,Object? version = freezed,Object? aiTitle = freezed,}) {
  return _then(_self.copyWith(
type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,sessionId: freezed == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String?,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime?,isSidechain: freezed == isSidechain ? _self.isSidechain : isSidechain // ignore: cast_nullable_to_non_nullable
as bool?,gitBranch: freezed == gitBranch ? _self.gitBranch : gitBranch // ignore: cast_nullable_to_non_nullable
as String?,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,aiTitle: freezed == aiTitle ? _self.aiTitle : aiTitle // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _ClaudeTranscriptRecordDto implements ClaudeTranscriptRecordDto {
  const _ClaudeTranscriptRecordDto({@JsonKey(fromJson: _stringOrNull) required this.type, @JsonKey(fromJson: _stringOrNull) required this.sessionId, @JsonKey(fromJson: _stringOrNull) required this.cwd, @JsonKey(fromJson: _timestampOrNull) required this.timestamp, @JsonKey(fromJson: _boolOrNull) required this.isSidechain, @JsonKey(fromJson: _stringOrNull) required this.gitBranch, @JsonKey(fromJson: _stringOrNull) required this.version, @JsonKey(fromJson: _stringOrNull) required this.aiTitle});
  factory _ClaudeTranscriptRecordDto.fromJson(Map<String, dynamic> json) => _$ClaudeTranscriptRecordDtoFromJson(json);

@override@JsonKey(fromJson: _stringOrNull) final  String? type;
@override@JsonKey(fromJson: _stringOrNull) final  String? sessionId;
@override@JsonKey(fromJson: _stringOrNull) final  String? cwd;
@override@JsonKey(fromJson: _timestampOrNull) final  DateTime? timestamp;
@override@JsonKey(fromJson: _boolOrNull) final  bool? isSidechain;
@override@JsonKey(fromJson: _stringOrNull) final  String? gitBranch;
@override@JsonKey(fromJson: _stringOrNull) final  String? version;
@override@JsonKey(fromJson: _stringOrNull) final  String? aiTitle;

/// Create a copy of ClaudeTranscriptRecordDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClaudeTranscriptRecordDtoCopyWith<_ClaudeTranscriptRecordDto> get copyWith => __$ClaudeTranscriptRecordDtoCopyWithImpl<_ClaudeTranscriptRecordDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClaudeTranscriptRecordDto&&(identical(other.type, type) || other.type == type)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.cwd, cwd) || other.cwd == cwd)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.isSidechain, isSidechain) || other.isSidechain == isSidechain)&&(identical(other.gitBranch, gitBranch) || other.gitBranch == gitBranch)&&(identical(other.version, version) || other.version == version)&&(identical(other.aiTitle, aiTitle) || other.aiTitle == aiTitle));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,sessionId,cwd,timestamp,isSidechain,gitBranch,version,aiTitle);

@override
String toString() {
  return 'ClaudeTranscriptRecordDto(type: $type, sessionId: $sessionId, cwd: $cwd, timestamp: $timestamp, isSidechain: $isSidechain, gitBranch: $gitBranch, version: $version, aiTitle: $aiTitle)';
}


}

/// @nodoc
abstract mixin class _$ClaudeTranscriptRecordDtoCopyWith<$Res> implements $ClaudeTranscriptRecordDtoCopyWith<$Res> {
  factory _$ClaudeTranscriptRecordDtoCopyWith(_ClaudeTranscriptRecordDto value, $Res Function(_ClaudeTranscriptRecordDto) _then) = __$ClaudeTranscriptRecordDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _stringOrNull) String? type,@JsonKey(fromJson: _stringOrNull) String? sessionId,@JsonKey(fromJson: _stringOrNull) String? cwd,@JsonKey(fromJson: _timestampOrNull) DateTime? timestamp,@JsonKey(fromJson: _boolOrNull) bool? isSidechain,@JsonKey(fromJson: _stringOrNull) String? gitBranch,@JsonKey(fromJson: _stringOrNull) String? version,@JsonKey(fromJson: _stringOrNull) String? aiTitle
});




}
/// @nodoc
class __$ClaudeTranscriptRecordDtoCopyWithImpl<$Res>
    implements _$ClaudeTranscriptRecordDtoCopyWith<$Res> {
  __$ClaudeTranscriptRecordDtoCopyWithImpl(this._self, this._then);

  final _ClaudeTranscriptRecordDto _self;
  final $Res Function(_ClaudeTranscriptRecordDto) _then;

/// Create a copy of ClaudeTranscriptRecordDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = freezed,Object? sessionId = freezed,Object? cwd = freezed,Object? timestamp = freezed,Object? isSidechain = freezed,Object? gitBranch = freezed,Object? version = freezed,Object? aiTitle = freezed,}) {
  return _then(_ClaudeTranscriptRecordDto(
type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,sessionId: freezed == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String?,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime?,isSidechain: freezed == isSidechain ? _self.isSidechain : isSidechain // ignore: cast_nullable_to_non_nullable
as bool?,gitBranch: freezed == gitBranch ? _self.gitBranch : gitBranch // ignore: cast_nullable_to_non_nullable
as String?,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,aiTitle: freezed == aiTitle ? _self.aiTitle : aiTitle // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
