// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_options_cache_table.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SessionOptionsCacheDto {

 String get pluginId; PluginSessionOptionsScope get scope; String get ownerId; String? get projectId; String? get capturedProjectPath; int get revision; int get capturedAt; PluginSessionOptionsCompleteness get completeness; String get agentsJson; String get providersJson; String get commandsJson;
/// Create a copy of SessionOptionsCacheDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionOptionsCacheDtoCopyWith<SessionOptionsCacheDto> get copyWith => _$SessionOptionsCacheDtoCopyWithImpl<SessionOptionsCacheDto>(this as SessionOptionsCacheDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionOptionsCacheDto&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.ownerId, ownerId) || other.ownerId == ownerId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.capturedProjectPath, capturedProjectPath) || other.capturedProjectPath == capturedProjectPath)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.capturedAt, capturedAt) || other.capturedAt == capturedAt)&&(identical(other.completeness, completeness) || other.completeness == completeness)&&(identical(other.agentsJson, agentsJson) || other.agentsJson == agentsJson)&&(identical(other.providersJson, providersJson) || other.providersJson == providersJson)&&(identical(other.commandsJson, commandsJson) || other.commandsJson == commandsJson));
}


@override
int get hashCode => Object.hash(runtimeType,pluginId,scope,ownerId,projectId,capturedProjectPath,revision,capturedAt,completeness,agentsJson,providersJson,commandsJson);

@override
String toString() {
  return 'SessionOptionsCacheDto(pluginId: $pluginId, scope: $scope, ownerId: $ownerId, projectId: $projectId, capturedProjectPath: $capturedProjectPath, revision: $revision, capturedAt: $capturedAt, completeness: $completeness, agentsJson: $agentsJson, providersJson: $providersJson, commandsJson: $commandsJson)';
}


}

/// @nodoc
abstract mixin class $SessionOptionsCacheDtoCopyWith<$Res>  {
  factory $SessionOptionsCacheDtoCopyWith(SessionOptionsCacheDto value, $Res Function(SessionOptionsCacheDto) _then) = _$SessionOptionsCacheDtoCopyWithImpl;
@useResult
$Res call({
 String pluginId, PluginSessionOptionsScope scope, String ownerId, String? projectId, String? capturedProjectPath, int revision, int capturedAt, PluginSessionOptionsCompleteness completeness, String agentsJson, String providersJson, String commandsJson
});




}
/// @nodoc
class _$SessionOptionsCacheDtoCopyWithImpl<$Res>
    implements $SessionOptionsCacheDtoCopyWith<$Res> {
  _$SessionOptionsCacheDtoCopyWithImpl(this._self, this._then);

  final SessionOptionsCacheDto _self;
  final $Res Function(SessionOptionsCacheDto) _then;

/// Create a copy of SessionOptionsCacheDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pluginId = null,Object? scope = null,Object? ownerId = null,Object? projectId = freezed,Object? capturedProjectPath = freezed,Object? revision = null,Object? capturedAt = null,Object? completeness = null,Object? agentsJson = null,Object? providersJson = null,Object? commandsJson = null,}) {
  return _then(_self.copyWith(
pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as PluginSessionOptionsScope,ownerId: null == ownerId ? _self.ownerId : ownerId // ignore: cast_nullable_to_non_nullable
as String,projectId: freezed == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String?,capturedProjectPath: freezed == capturedProjectPath ? _self.capturedProjectPath : capturedProjectPath // ignore: cast_nullable_to_non_nullable
as String?,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,capturedAt: null == capturedAt ? _self.capturedAt : capturedAt // ignore: cast_nullable_to_non_nullable
as int,completeness: null == completeness ? _self.completeness : completeness // ignore: cast_nullable_to_non_nullable
as PluginSessionOptionsCompleteness,agentsJson: null == agentsJson ? _self.agentsJson : agentsJson // ignore: cast_nullable_to_non_nullable
as String,providersJson: null == providersJson ? _self.providersJson : providersJson // ignore: cast_nullable_to_non_nullable
as String,commandsJson: null == commandsJson ? _self.commandsJson : commandsJson // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc


class _SessionOptionsCacheDto extends SessionOptionsCacheDto {
  const _SessionOptionsCacheDto({required this.pluginId, required this.scope, required this.ownerId, required this.projectId, required this.capturedProjectPath, required this.revision, required this.capturedAt, required this.completeness, required this.agentsJson, required this.providersJson, required this.commandsJson}): super._();
  

@override final  String pluginId;
@override final  PluginSessionOptionsScope scope;
@override final  String ownerId;
@override final  String? projectId;
@override final  String? capturedProjectPath;
@override final  int revision;
@override final  int capturedAt;
@override final  PluginSessionOptionsCompleteness completeness;
@override final  String agentsJson;
@override final  String providersJson;
@override final  String commandsJson;

/// Create a copy of SessionOptionsCacheDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionOptionsCacheDtoCopyWith<_SessionOptionsCacheDto> get copyWith => __$SessionOptionsCacheDtoCopyWithImpl<_SessionOptionsCacheDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionOptionsCacheDto&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.ownerId, ownerId) || other.ownerId == ownerId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.capturedProjectPath, capturedProjectPath) || other.capturedProjectPath == capturedProjectPath)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.capturedAt, capturedAt) || other.capturedAt == capturedAt)&&(identical(other.completeness, completeness) || other.completeness == completeness)&&(identical(other.agentsJson, agentsJson) || other.agentsJson == agentsJson)&&(identical(other.providersJson, providersJson) || other.providersJson == providersJson)&&(identical(other.commandsJson, commandsJson) || other.commandsJson == commandsJson));
}


@override
int get hashCode => Object.hash(runtimeType,pluginId,scope,ownerId,projectId,capturedProjectPath,revision,capturedAt,completeness,agentsJson,providersJson,commandsJson);

@override
String toString() {
  return 'SessionOptionsCacheDto(pluginId: $pluginId, scope: $scope, ownerId: $ownerId, projectId: $projectId, capturedProjectPath: $capturedProjectPath, revision: $revision, capturedAt: $capturedAt, completeness: $completeness, agentsJson: $agentsJson, providersJson: $providersJson, commandsJson: $commandsJson)';
}


}

/// @nodoc
abstract mixin class _$SessionOptionsCacheDtoCopyWith<$Res> implements $SessionOptionsCacheDtoCopyWith<$Res> {
  factory _$SessionOptionsCacheDtoCopyWith(_SessionOptionsCacheDto value, $Res Function(_SessionOptionsCacheDto) _then) = __$SessionOptionsCacheDtoCopyWithImpl;
@override @useResult
$Res call({
 String pluginId, PluginSessionOptionsScope scope, String ownerId, String? projectId, String? capturedProjectPath, int revision, int capturedAt, PluginSessionOptionsCompleteness completeness, String agentsJson, String providersJson, String commandsJson
});




}
/// @nodoc
class __$SessionOptionsCacheDtoCopyWithImpl<$Res>
    implements _$SessionOptionsCacheDtoCopyWith<$Res> {
  __$SessionOptionsCacheDtoCopyWithImpl(this._self, this._then);

  final _SessionOptionsCacheDto _self;
  final $Res Function(_SessionOptionsCacheDto) _then;

/// Create a copy of SessionOptionsCacheDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pluginId = null,Object? scope = null,Object? ownerId = null,Object? projectId = freezed,Object? capturedProjectPath = freezed,Object? revision = null,Object? capturedAt = null,Object? completeness = null,Object? agentsJson = null,Object? providersJson = null,Object? commandsJson = null,}) {
  return _then(_SessionOptionsCacheDto(
pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as PluginSessionOptionsScope,ownerId: null == ownerId ? _self.ownerId : ownerId // ignore: cast_nullable_to_non_nullable
as String,projectId: freezed == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String?,capturedProjectPath: freezed == capturedProjectPath ? _self.capturedProjectPath : capturedProjectPath // ignore: cast_nullable_to_non_nullable
as String?,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,capturedAt: null == capturedAt ? _self.capturedAt : capturedAt // ignore: cast_nullable_to_non_nullable
as int,completeness: null == completeness ? _self.completeness : completeness // ignore: cast_nullable_to_non_nullable
as PluginSessionOptionsCompleteness,agentsJson: null == agentsJson ? _self.agentsJson : agentsJson // ignore: cast_nullable_to_non_nullable
as String,providersJson: null == providersJson ? _self.providersJson : providersJson // ignore: cast_nullable_to_non_nullable
as String,commandsJson: null == commandsJson ? _self.commandsJson : commandsJson // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
