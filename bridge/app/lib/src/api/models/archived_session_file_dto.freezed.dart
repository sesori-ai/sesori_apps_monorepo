// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'archived_session_file_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ArchivedSessionFileDto {

 int get schemaVersion; int get archivedAt; ArchivedSessionCompleteness get completeness; ArchivedSessionSnapshotDto get session; List<ArchivedMessageDto> get messages;
/// Create a copy of ArchivedSessionFileDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ArchivedSessionFileDtoCopyWith<ArchivedSessionFileDto> get copyWith => _$ArchivedSessionFileDtoCopyWithImpl<ArchivedSessionFileDto>(this as ArchivedSessionFileDto, _$identity);

  /// Serializes this ArchivedSessionFileDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ArchivedSessionFileDto&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.completeness, completeness) || other.completeness == completeness)&&(identical(other.session, session) || other.session == session)&&const DeepCollectionEquality().equals(other.messages, messages));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,schemaVersion,archivedAt,completeness,session,const DeepCollectionEquality().hash(messages));

@override
String toString() {
  return 'ArchivedSessionFileDto(schemaVersion: $schemaVersion, archivedAt: $archivedAt, completeness: $completeness, session: $session, messages: $messages)';
}


}

/// @nodoc
abstract mixin class $ArchivedSessionFileDtoCopyWith<$Res>  {
  factory $ArchivedSessionFileDtoCopyWith(ArchivedSessionFileDto value, $Res Function(ArchivedSessionFileDto) _then) = _$ArchivedSessionFileDtoCopyWithImpl;
@useResult
$Res call({
 int schemaVersion, int archivedAt, ArchivedSessionCompleteness completeness, ArchivedSessionSnapshotDto session, List<ArchivedMessageDto> messages
});


$ArchivedSessionSnapshotDtoCopyWith<$Res> get session;

}
/// @nodoc
class _$ArchivedSessionFileDtoCopyWithImpl<$Res>
    implements $ArchivedSessionFileDtoCopyWith<$Res> {
  _$ArchivedSessionFileDtoCopyWithImpl(this._self, this._then);

  final ArchivedSessionFileDto _self;
  final $Res Function(ArchivedSessionFileDto) _then;

/// Create a copy of ArchivedSessionFileDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? schemaVersion = null,Object? archivedAt = null,Object? completeness = null,Object? session = null,Object? messages = null,}) {
  return _then(_self.copyWith(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,completeness: null == completeness ? _self.completeness : completeness // ignore: cast_nullable_to_non_nullable
as ArchivedSessionCompleteness,session: null == session ? _self.session : session // ignore: cast_nullable_to_non_nullable
as ArchivedSessionSnapshotDto,messages: null == messages ? _self.messages : messages // ignore: cast_nullable_to_non_nullable
as List<ArchivedMessageDto>,
  ));
}
/// Create a copy of ArchivedSessionFileDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ArchivedSessionSnapshotDtoCopyWith<$Res> get session {
  
  return $ArchivedSessionSnapshotDtoCopyWith<$Res>(_self.session, (value) {
    return _then(_self.copyWith(session: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _ArchivedSessionFileDto implements ArchivedSessionFileDto {
  const _ArchivedSessionFileDto({required this.schemaVersion, required this.archivedAt, required this.completeness, required this.session, required final  List<ArchivedMessageDto> messages}): _messages = messages;
  factory _ArchivedSessionFileDto.fromJson(Map<String, dynamic> json) => _$ArchivedSessionFileDtoFromJson(json);

@override final  int schemaVersion;
@override final  int archivedAt;
@override final  ArchivedSessionCompleteness completeness;
@override final  ArchivedSessionSnapshotDto session;
 final  List<ArchivedMessageDto> _messages;
@override List<ArchivedMessageDto> get messages {
  if (_messages is EqualUnmodifiableListView) return _messages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_messages);
}


/// Create a copy of ArchivedSessionFileDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ArchivedSessionFileDtoCopyWith<_ArchivedSessionFileDto> get copyWith => __$ArchivedSessionFileDtoCopyWithImpl<_ArchivedSessionFileDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ArchivedSessionFileDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ArchivedSessionFileDto&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.completeness, completeness) || other.completeness == completeness)&&(identical(other.session, session) || other.session == session)&&const DeepCollectionEquality().equals(other._messages, _messages));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,schemaVersion,archivedAt,completeness,session,const DeepCollectionEquality().hash(_messages));

@override
String toString() {
  return 'ArchivedSessionFileDto(schemaVersion: $schemaVersion, archivedAt: $archivedAt, completeness: $completeness, session: $session, messages: $messages)';
}


}

/// @nodoc
abstract mixin class _$ArchivedSessionFileDtoCopyWith<$Res> implements $ArchivedSessionFileDtoCopyWith<$Res> {
  factory _$ArchivedSessionFileDtoCopyWith(_ArchivedSessionFileDto value, $Res Function(_ArchivedSessionFileDto) _then) = __$ArchivedSessionFileDtoCopyWithImpl;
@override @useResult
$Res call({
 int schemaVersion, int archivedAt, ArchivedSessionCompleteness completeness, ArchivedSessionSnapshotDto session, List<ArchivedMessageDto> messages
});


@override $ArchivedSessionSnapshotDtoCopyWith<$Res> get session;

}
/// @nodoc
class __$ArchivedSessionFileDtoCopyWithImpl<$Res>
    implements _$ArchivedSessionFileDtoCopyWith<$Res> {
  __$ArchivedSessionFileDtoCopyWithImpl(this._self, this._then);

  final _ArchivedSessionFileDto _self;
  final $Res Function(_ArchivedSessionFileDto) _then;

/// Create a copy of ArchivedSessionFileDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? schemaVersion = null,Object? archivedAt = null,Object? completeness = null,Object? session = null,Object? messages = null,}) {
  return _then(_ArchivedSessionFileDto(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,completeness: null == completeness ? _self.completeness : completeness // ignore: cast_nullable_to_non_nullable
as ArchivedSessionCompleteness,session: null == session ? _self.session : session // ignore: cast_nullable_to_non_nullable
as ArchivedSessionSnapshotDto,messages: null == messages ? _self._messages : messages // ignore: cast_nullable_to_non_nullable
as List<ArchivedMessageDto>,
  ));
}

/// Create a copy of ArchivedSessionFileDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ArchivedSessionSnapshotDtoCopyWith<$Res> get session {
  
  return $ArchivedSessionSnapshotDtoCopyWith<$Res>(_self.session, (value) {
    return _then(_self.copyWith(session: value));
  });
}
}


/// @nodoc
mixin _$ArchivedSessionSnapshotDto {

 String get sessionId; String get backendSessionId; String get pluginId; String get projectId; String? get parentSessionId; String get directory; String? get worktreePath; String? get branchName; String? get baseBranch; String? get baseCommit; String? get lastAgent; String? get lastAgentModel; String? get title; int get createdAt; int get updatedAt;
/// Create a copy of ArchivedSessionSnapshotDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ArchivedSessionSnapshotDtoCopyWith<ArchivedSessionSnapshotDto> get copyWith => _$ArchivedSessionSnapshotDtoCopyWithImpl<ArchivedSessionSnapshotDto>(this as ArchivedSessionSnapshotDto, _$identity);

  /// Serializes this ArchivedSessionSnapshotDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ArchivedSessionSnapshotDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.backendSessionId, backendSessionId) || other.backendSessionId == backendSessionId)&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.parentSessionId, parentSessionId) || other.parentSessionId == parentSessionId)&&(identical(other.directory, directory) || other.directory == directory)&&(identical(other.worktreePath, worktreePath) || other.worktreePath == worktreePath)&&(identical(other.branchName, branchName) || other.branchName == branchName)&&(identical(other.baseBranch, baseBranch) || other.baseBranch == baseBranch)&&(identical(other.baseCommit, baseCommit) || other.baseCommit == baseCommit)&&(identical(other.lastAgent, lastAgent) || other.lastAgent == lastAgent)&&(identical(other.lastAgentModel, lastAgentModel) || other.lastAgentModel == lastAgentModel)&&(identical(other.title, title) || other.title == title)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,backendSessionId,pluginId,projectId,parentSessionId,directory,worktreePath,branchName,baseBranch,baseCommit,lastAgent,lastAgentModel,title,createdAt,updatedAt);

@override
String toString() {
  return 'ArchivedSessionSnapshotDto(sessionId: $sessionId, backendSessionId: $backendSessionId, pluginId: $pluginId, projectId: $projectId, parentSessionId: $parentSessionId, directory: $directory, worktreePath: $worktreePath, branchName: $branchName, baseBranch: $baseBranch, baseCommit: $baseCommit, lastAgent: $lastAgent, lastAgentModel: $lastAgentModel, title: $title, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $ArchivedSessionSnapshotDtoCopyWith<$Res>  {
  factory $ArchivedSessionSnapshotDtoCopyWith(ArchivedSessionSnapshotDto value, $Res Function(ArchivedSessionSnapshotDto) _then) = _$ArchivedSessionSnapshotDtoCopyWithImpl;
@useResult
$Res call({
 String sessionId, String backendSessionId, String pluginId, String projectId, String? parentSessionId, String directory, String? worktreePath, String? branchName, String? baseBranch, String? baseCommit, String? lastAgent, String? lastAgentModel, String? title, int createdAt, int updatedAt
});




}
/// @nodoc
class _$ArchivedSessionSnapshotDtoCopyWithImpl<$Res>
    implements $ArchivedSessionSnapshotDtoCopyWith<$Res> {
  _$ArchivedSessionSnapshotDtoCopyWithImpl(this._self, this._then);

  final ArchivedSessionSnapshotDto _self;
  final $Res Function(ArchivedSessionSnapshotDto) _then;

/// Create a copy of ArchivedSessionSnapshotDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? backendSessionId = null,Object? pluginId = null,Object? projectId = null,Object? parentSessionId = freezed,Object? directory = null,Object? worktreePath = freezed,Object? branchName = freezed,Object? baseBranch = freezed,Object? baseCommit = freezed,Object? lastAgent = freezed,Object? lastAgentModel = freezed,Object? title = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,backendSessionId: null == backendSessionId ? _self.backendSessionId : backendSessionId // ignore: cast_nullable_to_non_nullable
as String,pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,parentSessionId: freezed == parentSessionId ? _self.parentSessionId : parentSessionId // ignore: cast_nullable_to_non_nullable
as String?,directory: null == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String,worktreePath: freezed == worktreePath ? _self.worktreePath : worktreePath // ignore: cast_nullable_to_non_nullable
as String?,branchName: freezed == branchName ? _self.branchName : branchName // ignore: cast_nullable_to_non_nullable
as String?,baseBranch: freezed == baseBranch ? _self.baseBranch : baseBranch // ignore: cast_nullable_to_non_nullable
as String?,baseCommit: freezed == baseCommit ? _self.baseCommit : baseCommit // ignore: cast_nullable_to_non_nullable
as String?,lastAgent: freezed == lastAgent ? _self.lastAgent : lastAgent // ignore: cast_nullable_to_non_nullable
as String?,lastAgentModel: freezed == lastAgentModel ? _self.lastAgentModel : lastAgentModel // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _ArchivedSessionSnapshotDto implements ArchivedSessionSnapshotDto {
  const _ArchivedSessionSnapshotDto({required this.sessionId, required this.backendSessionId, required this.pluginId, required this.projectId, required this.parentSessionId, required this.directory, required this.worktreePath, required this.branchName, required this.baseBranch, required this.baseCommit, required this.lastAgent, required this.lastAgentModel, required this.title, required this.createdAt, required this.updatedAt});
  factory _ArchivedSessionSnapshotDto.fromJson(Map<String, dynamic> json) => _$ArchivedSessionSnapshotDtoFromJson(json);

@override final  String sessionId;
@override final  String backendSessionId;
@override final  String pluginId;
@override final  String projectId;
@override final  String? parentSessionId;
@override final  String directory;
@override final  String? worktreePath;
@override final  String? branchName;
@override final  String? baseBranch;
@override final  String? baseCommit;
@override final  String? lastAgent;
@override final  String? lastAgentModel;
@override final  String? title;
@override final  int createdAt;
@override final  int updatedAt;

/// Create a copy of ArchivedSessionSnapshotDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ArchivedSessionSnapshotDtoCopyWith<_ArchivedSessionSnapshotDto> get copyWith => __$ArchivedSessionSnapshotDtoCopyWithImpl<_ArchivedSessionSnapshotDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ArchivedSessionSnapshotDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ArchivedSessionSnapshotDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.backendSessionId, backendSessionId) || other.backendSessionId == backendSessionId)&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.parentSessionId, parentSessionId) || other.parentSessionId == parentSessionId)&&(identical(other.directory, directory) || other.directory == directory)&&(identical(other.worktreePath, worktreePath) || other.worktreePath == worktreePath)&&(identical(other.branchName, branchName) || other.branchName == branchName)&&(identical(other.baseBranch, baseBranch) || other.baseBranch == baseBranch)&&(identical(other.baseCommit, baseCommit) || other.baseCommit == baseCommit)&&(identical(other.lastAgent, lastAgent) || other.lastAgent == lastAgent)&&(identical(other.lastAgentModel, lastAgentModel) || other.lastAgentModel == lastAgentModel)&&(identical(other.title, title) || other.title == title)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,backendSessionId,pluginId,projectId,parentSessionId,directory,worktreePath,branchName,baseBranch,baseCommit,lastAgent,lastAgentModel,title,createdAt,updatedAt);

@override
String toString() {
  return 'ArchivedSessionSnapshotDto(sessionId: $sessionId, backendSessionId: $backendSessionId, pluginId: $pluginId, projectId: $projectId, parentSessionId: $parentSessionId, directory: $directory, worktreePath: $worktreePath, branchName: $branchName, baseBranch: $baseBranch, baseCommit: $baseCommit, lastAgent: $lastAgent, lastAgentModel: $lastAgentModel, title: $title, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$ArchivedSessionSnapshotDtoCopyWith<$Res> implements $ArchivedSessionSnapshotDtoCopyWith<$Res> {
  factory _$ArchivedSessionSnapshotDtoCopyWith(_ArchivedSessionSnapshotDto value, $Res Function(_ArchivedSessionSnapshotDto) _then) = __$ArchivedSessionSnapshotDtoCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, String backendSessionId, String pluginId, String projectId, String? parentSessionId, String directory, String? worktreePath, String? branchName, String? baseBranch, String? baseCommit, String? lastAgent, String? lastAgentModel, String? title, int createdAt, int updatedAt
});




}
/// @nodoc
class __$ArchivedSessionSnapshotDtoCopyWithImpl<$Res>
    implements _$ArchivedSessionSnapshotDtoCopyWith<$Res> {
  __$ArchivedSessionSnapshotDtoCopyWithImpl(this._self, this._then);

  final _ArchivedSessionSnapshotDto _self;
  final $Res Function(_ArchivedSessionSnapshotDto) _then;

/// Create a copy of ArchivedSessionSnapshotDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? backendSessionId = null,Object? pluginId = null,Object? projectId = null,Object? parentSessionId = freezed,Object? directory = null,Object? worktreePath = freezed,Object? branchName = freezed,Object? baseBranch = freezed,Object? baseCommit = freezed,Object? lastAgent = freezed,Object? lastAgentModel = freezed,Object? title = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_ArchivedSessionSnapshotDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,backendSessionId: null == backendSessionId ? _self.backendSessionId : backendSessionId // ignore: cast_nullable_to_non_nullable
as String,pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,parentSessionId: freezed == parentSessionId ? _self.parentSessionId : parentSessionId // ignore: cast_nullable_to_non_nullable
as String?,directory: null == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String,worktreePath: freezed == worktreePath ? _self.worktreePath : worktreePath // ignore: cast_nullable_to_non_nullable
as String?,branchName: freezed == branchName ? _self.branchName : branchName // ignore: cast_nullable_to_non_nullable
as String?,baseBranch: freezed == baseBranch ? _self.baseBranch : baseBranch // ignore: cast_nullable_to_non_nullable
as String?,baseCommit: freezed == baseCommit ? _self.baseCommit : baseCommit // ignore: cast_nullable_to_non_nullable
as String?,lastAgent: freezed == lastAgent ? _self.lastAgent : lastAgent // ignore: cast_nullable_to_non_nullable
as String?,lastAgentModel: freezed == lastAgentModel ? _self.lastAgentModel : lastAgentModel // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$ArchivedMessageDto {

 int get seq; Message get info;/// Parts in their **stored** form — the same JSON the live store holds,
/// with attachments as internal `stored_file` references into the archived
/// spill directory.
///
/// Deliberately untyped: `MessagePart.fromJson` maps that internal source
/// to its forward-compatible `unknown` fallback, which would silently drop
/// the digest and lose the attachment. The read path rehydrates these maps
/// exactly as it rehydrates a database row.
 List<Map<String, dynamic>> get parts;
/// Create a copy of ArchivedMessageDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ArchivedMessageDtoCopyWith<ArchivedMessageDto> get copyWith => _$ArchivedMessageDtoCopyWithImpl<ArchivedMessageDto>(this as ArchivedMessageDto, _$identity);

  /// Serializes this ArchivedMessageDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ArchivedMessageDto&&(identical(other.seq, seq) || other.seq == seq)&&(identical(other.info, info) || other.info == info)&&const DeepCollectionEquality().equals(other.parts, parts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,seq,info,const DeepCollectionEquality().hash(parts));

@override
String toString() {
  return 'ArchivedMessageDto(seq: $seq, info: $info, parts: $parts)';
}


}

/// @nodoc
abstract mixin class $ArchivedMessageDtoCopyWith<$Res>  {
  factory $ArchivedMessageDtoCopyWith(ArchivedMessageDto value, $Res Function(ArchivedMessageDto) _then) = _$ArchivedMessageDtoCopyWithImpl;
@useResult
$Res call({
 int seq, Message info, List<Map<String, dynamic>> parts
});


$MessageCopyWith<$Res> get info;

}
/// @nodoc
class _$ArchivedMessageDtoCopyWithImpl<$Res>
    implements $ArchivedMessageDtoCopyWith<$Res> {
  _$ArchivedMessageDtoCopyWithImpl(this._self, this._then);

  final ArchivedMessageDto _self;
  final $Res Function(ArchivedMessageDto) _then;

/// Create a copy of ArchivedMessageDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? seq = null,Object? info = null,Object? parts = null,}) {
  return _then(_self.copyWith(
seq: null == seq ? _self.seq : seq // ignore: cast_nullable_to_non_nullable
as int,info: null == info ? _self.info : info // ignore: cast_nullable_to_non_nullable
as Message,parts: null == parts ? _self.parts : parts // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,
  ));
}
/// Create a copy of ArchivedMessageDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessageCopyWith<$Res> get info {
  
  return $MessageCopyWith<$Res>(_self.info, (value) {
    return _then(_self.copyWith(info: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _ArchivedMessageDto implements ArchivedMessageDto {
  const _ArchivedMessageDto({required this.seq, required this.info, required final  List<Map<String, dynamic>> parts}): _parts = parts;
  factory _ArchivedMessageDto.fromJson(Map<String, dynamic> json) => _$ArchivedMessageDtoFromJson(json);

@override final  int seq;
@override final  Message info;
/// Parts in their **stored** form — the same JSON the live store holds,
/// with attachments as internal `stored_file` references into the archived
/// spill directory.
///
/// Deliberately untyped: `MessagePart.fromJson` maps that internal source
/// to its forward-compatible `unknown` fallback, which would silently drop
/// the digest and lose the attachment. The read path rehydrates these maps
/// exactly as it rehydrates a database row.
 final  List<Map<String, dynamic>> _parts;
/// Parts in their **stored** form — the same JSON the live store holds,
/// with attachments as internal `stored_file` references into the archived
/// spill directory.
///
/// Deliberately untyped: `MessagePart.fromJson` maps that internal source
/// to its forward-compatible `unknown` fallback, which would silently drop
/// the digest and lose the attachment. The read path rehydrates these maps
/// exactly as it rehydrates a database row.
@override List<Map<String, dynamic>> get parts {
  if (_parts is EqualUnmodifiableListView) return _parts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_parts);
}


/// Create a copy of ArchivedMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ArchivedMessageDtoCopyWith<_ArchivedMessageDto> get copyWith => __$ArchivedMessageDtoCopyWithImpl<_ArchivedMessageDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ArchivedMessageDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ArchivedMessageDto&&(identical(other.seq, seq) || other.seq == seq)&&(identical(other.info, info) || other.info == info)&&const DeepCollectionEquality().equals(other._parts, _parts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,seq,info,const DeepCollectionEquality().hash(_parts));

@override
String toString() {
  return 'ArchivedMessageDto(seq: $seq, info: $info, parts: $parts)';
}


}

/// @nodoc
abstract mixin class _$ArchivedMessageDtoCopyWith<$Res> implements $ArchivedMessageDtoCopyWith<$Res> {
  factory _$ArchivedMessageDtoCopyWith(_ArchivedMessageDto value, $Res Function(_ArchivedMessageDto) _then) = __$ArchivedMessageDtoCopyWithImpl;
@override @useResult
$Res call({
 int seq, Message info, List<Map<String, dynamic>> parts
});


@override $MessageCopyWith<$Res> get info;

}
/// @nodoc
class __$ArchivedMessageDtoCopyWithImpl<$Res>
    implements _$ArchivedMessageDtoCopyWith<$Res> {
  __$ArchivedMessageDtoCopyWithImpl(this._self, this._then);

  final _ArchivedMessageDto _self;
  final $Res Function(_ArchivedMessageDto) _then;

/// Create a copy of ArchivedMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? seq = null,Object? info = null,Object? parts = null,}) {
  return _then(_ArchivedMessageDto(
seq: null == seq ? _self.seq : seq // ignore: cast_nullable_to_non_nullable
as int,info: null == info ? _self.info : info // ignore: cast_nullable_to_non_nullable
as Message,parts: null == parts ? _self._parts : parts // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,
  ));
}

/// Create a copy of ArchivedMessageDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessageCopyWith<$Res> get info {
  
  return $MessageCopyWith<$Res>(_self.info, (value) {
    return _then(_self.copyWith(info: value));
  });
}
}

// dart format on
