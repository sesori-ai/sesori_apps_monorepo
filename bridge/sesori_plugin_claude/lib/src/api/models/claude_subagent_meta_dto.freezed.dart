// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'claude_subagent_meta_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ClaudeSubagentMetaDto {

@JsonKey(fromJson: _stringOrNull) String? get agentType;@JsonKey(fromJson: _stringOrNull) String? get description;@JsonKey(fromJson: _stringOrNull) String? get toolUseId;@JsonKey(fromJson: _intOrNull) int? get spawnDepth;
/// Create a copy of ClaudeSubagentMetaDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClaudeSubagentMetaDtoCopyWith<ClaudeSubagentMetaDto> get copyWith => _$ClaudeSubagentMetaDtoCopyWithImpl<ClaudeSubagentMetaDto>(this as ClaudeSubagentMetaDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaudeSubagentMetaDto&&(identical(other.agentType, agentType) || other.agentType == agentType)&&(identical(other.description, description) || other.description == description)&&(identical(other.toolUseId, toolUseId) || other.toolUseId == toolUseId)&&(identical(other.spawnDepth, spawnDepth) || other.spawnDepth == spawnDepth));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,agentType,description,toolUseId,spawnDepth);



}

/// @nodoc
abstract mixin class $ClaudeSubagentMetaDtoCopyWith<$Res>  {
  factory $ClaudeSubagentMetaDtoCopyWith(ClaudeSubagentMetaDto value, $Res Function(ClaudeSubagentMetaDto) _then) = _$ClaudeSubagentMetaDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _stringOrNull) String? agentType,@JsonKey(fromJson: _stringOrNull) String? description,@JsonKey(fromJson: _stringOrNull) String? toolUseId,@JsonKey(fromJson: _intOrNull) int? spawnDepth
});




}
/// @nodoc
class _$ClaudeSubagentMetaDtoCopyWithImpl<$Res>
    implements $ClaudeSubagentMetaDtoCopyWith<$Res> {
  _$ClaudeSubagentMetaDtoCopyWithImpl(this._self, this._then);

  final ClaudeSubagentMetaDto _self;
  final $Res Function(ClaudeSubagentMetaDto) _then;

/// Create a copy of ClaudeSubagentMetaDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? agentType = freezed,Object? description = freezed,Object? toolUseId = freezed,Object? spawnDepth = freezed,}) {
  return _then(ClaudeSubagentMetaDto(
agentType: freezed == agentType ? _self.agentType : agentType // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,toolUseId: freezed == toolUseId ? _self.toolUseId : toolUseId // ignore: cast_nullable_to_non_nullable
as String?,spawnDepth: freezed == spawnDepth ? _self.spawnDepth : spawnDepth // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _ClaudeSubagentMetaDto implements ClaudeSubagentMetaDto {
  const _ClaudeSubagentMetaDto({@JsonKey(fromJson: _stringOrNull) required this.agentType, @JsonKey(fromJson: _stringOrNull) required this.description, @JsonKey(fromJson: _stringOrNull) required this.toolUseId, @JsonKey(fromJson: _intOrNull) required this.spawnDepth});
  factory _ClaudeSubagentMetaDto.fromJson(Map<String, dynamic> json) => _$ClaudeSubagentMetaDtoFromJson(json);

@override@JsonKey(fromJson: _stringOrNull) final  String? agentType;
@override@JsonKey(fromJson: _stringOrNull) final  String? description;
@override@JsonKey(fromJson: _stringOrNull) final  String? toolUseId;
@override@JsonKey(fromJson: _intOrNull) final  int? spawnDepth;

/// Create a copy of ClaudeSubagentMetaDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClaudeSubagentMetaDtoCopyWith<_ClaudeSubagentMetaDto> get copyWith => __$ClaudeSubagentMetaDtoCopyWithImpl<_ClaudeSubagentMetaDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClaudeSubagentMetaDto&&(identical(other.agentType, agentType) || other.agentType == agentType)&&(identical(other.description, description) || other.description == description)&&(identical(other.toolUseId, toolUseId) || other.toolUseId == toolUseId)&&(identical(other.spawnDepth, spawnDepth) || other.spawnDepth == spawnDepth));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,agentType,description,toolUseId,spawnDepth);



}

/// @nodoc
abstract mixin class _$ClaudeSubagentMetaDtoCopyWith<$Res> implements $ClaudeSubagentMetaDtoCopyWith<$Res> {
  factory _$ClaudeSubagentMetaDtoCopyWith(_ClaudeSubagentMetaDto value, $Res Function(_ClaudeSubagentMetaDto) _then) = __$ClaudeSubagentMetaDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _stringOrNull) String? agentType,@JsonKey(fromJson: _stringOrNull) String? description,@JsonKey(fromJson: _stringOrNull) String? toolUseId,@JsonKey(fromJson: _intOrNull) int? spawnDepth
});




}
/// @nodoc
class __$ClaudeSubagentMetaDtoCopyWithImpl<$Res>
    implements _$ClaudeSubagentMetaDtoCopyWith<$Res> {
  __$ClaudeSubagentMetaDtoCopyWithImpl(this._self, this._then);

  final _ClaudeSubagentMetaDto _self;
  final $Res Function(_ClaudeSubagentMetaDto) _then;

/// Create a copy of ClaudeSubagentMetaDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? agentType = freezed,Object? description = freezed,Object? toolUseId = freezed,Object? spawnDepth = freezed,}) {
  return _then(_ClaudeSubagentMetaDto(
agentType: freezed == agentType ? _self.agentType : agentType // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,toolUseId: freezed == toolUseId ? _self.toolUseId : toolUseId // ignore: cast_nullable_to_non_nullable
as String?,spawnDepth: freezed == spawnDepth ? _self.spawnDepth : spawnDepth // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
