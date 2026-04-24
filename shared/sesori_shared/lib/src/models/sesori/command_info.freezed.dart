// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'command_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CommandInfo {

 String get name; String? get template; List<String>? get hints; String? get description; String? get agent; String? get model; String? get provider;@JsonKey(unknownEnumValue: CommandSource.unknown) CommandSource? get source; bool? get subtask;
/// Create a copy of CommandInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommandInfoCopyWith<CommandInfo> get copyWith => _$CommandInfoCopyWithImpl<CommandInfo>(this as CommandInfo, _$identity);

  /// Serializes this CommandInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommandInfo&&(identical(other.name, name) || other.name == name)&&(identical(other.template, template) || other.template == template)&&const DeepCollectionEquality().equals(other.hints, hints)&&(identical(other.description, description) || other.description == description)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.model, model) || other.model == model)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.source, source) || other.source == source)&&(identical(other.subtask, subtask) || other.subtask == subtask));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,template,const DeepCollectionEquality().hash(hints),description,agent,model,provider,source,subtask);

@override
String toString() {
  return 'CommandInfo(name: $name, template: $template, hints: $hints, description: $description, agent: $agent, model: $model, provider: $provider, source: $source, subtask: $subtask)';
}


}

/// @nodoc
abstract mixin class $CommandInfoCopyWith<$Res>  {
  factory $CommandInfoCopyWith(CommandInfo value, $Res Function(CommandInfo) _then) = _$CommandInfoCopyWithImpl;
@useResult
$Res call({
 String name, String? template, List<String>? hints, String? description, String? agent, String? model, String? provider,@JsonKey(unknownEnumValue: CommandSource.unknown) CommandSource? source, bool? subtask
});




}
/// @nodoc
class _$CommandInfoCopyWithImpl<$Res>
    implements $CommandInfoCopyWith<$Res> {
  _$CommandInfoCopyWithImpl(this._self, this._then);

  final CommandInfo _self;
  final $Res Function(CommandInfo) _then;

/// Create a copy of CommandInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? template = freezed,Object? hints = freezed,Object? description = freezed,Object? agent = freezed,Object? model = freezed,Object? provider = freezed,Object? source = freezed,Object? subtask = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,template: freezed == template ? _self.template : template // ignore: cast_nullable_to_non_nullable
as String?,hints: freezed == hints ? _self.hints : hints // ignore: cast_nullable_to_non_nullable
as List<String>?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,provider: freezed == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as CommandSource?,subtask: freezed == subtask ? _self.subtask : subtask // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _CommandInfo implements CommandInfo {
  const _CommandInfo({required this.name, required this.template, required final  List<String>? hints, required this.description, required this.agent, required this.model, required this.provider, @JsonKey(unknownEnumValue: CommandSource.unknown) required this.source, required this.subtask}): _hints = hints;
  factory _CommandInfo.fromJson(Map<String, dynamic> json) => _$CommandInfoFromJson(json);

@override final  String name;
@override final  String? template;
 final  List<String>? _hints;
@override List<String>? get hints {
  final value = _hints;
  if (value == null) return null;
  if (_hints is EqualUnmodifiableListView) return _hints;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  String? description;
@override final  String? agent;
@override final  String? model;
@override final  String? provider;
@override@JsonKey(unknownEnumValue: CommandSource.unknown) final  CommandSource? source;
@override final  bool? subtask;

/// Create a copy of CommandInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommandInfoCopyWith<_CommandInfo> get copyWith => __$CommandInfoCopyWithImpl<_CommandInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CommandInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommandInfo&&(identical(other.name, name) || other.name == name)&&(identical(other.template, template) || other.template == template)&&const DeepCollectionEquality().equals(other._hints, _hints)&&(identical(other.description, description) || other.description == description)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.model, model) || other.model == model)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.source, source) || other.source == source)&&(identical(other.subtask, subtask) || other.subtask == subtask));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,template,const DeepCollectionEquality().hash(_hints),description,agent,model,provider,source,subtask);

@override
String toString() {
  return 'CommandInfo(name: $name, template: $template, hints: $hints, description: $description, agent: $agent, model: $model, provider: $provider, source: $source, subtask: $subtask)';
}


}

/// @nodoc
abstract mixin class _$CommandInfoCopyWith<$Res> implements $CommandInfoCopyWith<$Res> {
  factory _$CommandInfoCopyWith(_CommandInfo value, $Res Function(_CommandInfo) _then) = __$CommandInfoCopyWithImpl;
@override @useResult
$Res call({
 String name, String? template, List<String>? hints, String? description, String? agent, String? model, String? provider,@JsonKey(unknownEnumValue: CommandSource.unknown) CommandSource? source, bool? subtask
});




}
/// @nodoc
class __$CommandInfoCopyWithImpl<$Res>
    implements _$CommandInfoCopyWith<$Res> {
  __$CommandInfoCopyWithImpl(this._self, this._then);

  final _CommandInfo _self;
  final $Res Function(_CommandInfo) _then;

/// Create a copy of CommandInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? template = freezed,Object? hints = freezed,Object? description = freezed,Object? agent = freezed,Object? model = freezed,Object? provider = freezed,Object? source = freezed,Object? subtask = freezed,}) {
  return _then(_CommandInfo(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,template: freezed == template ? _self.template : template // ignore: cast_nullable_to_non_nullable
as String?,hints: freezed == hints ? _self._hints : hints // ignore: cast_nullable_to_non_nullable
as List<String>?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,provider: freezed == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as CommandSource?,subtask: freezed == subtask ? _self.subtask : subtask // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}

// dart format on
