// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_command.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PluginCommand {

 String get name; String? get template; List<String> get hints; String? get description; String? get agent; String? get model; PluginCommandSource? get source; bool? get subtask;
/// Create a copy of PluginCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginCommandCopyWith<PluginCommand> get copyWith => _$PluginCommandCopyWithImpl<PluginCommand>(this as PluginCommand, _$identity);

  /// Serializes this PluginCommand to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginCommand&&(identical(other.name, name) || other.name == name)&&(identical(other.template, template) || other.template == template)&&const DeepCollectionEquality().equals(other.hints, hints)&&(identical(other.description, description) || other.description == description)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.model, model) || other.model == model)&&(identical(other.source, source) || other.source == source)&&(identical(other.subtask, subtask) || other.subtask == subtask));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,template,const DeepCollectionEquality().hash(hints),description,agent,model,source,subtask);

@override
String toString() {
  return 'PluginCommand(name: $name, template: $template, hints: $hints, description: $description, agent: $agent, model: $model, source: $source, subtask: $subtask)';
}


}

/// @nodoc
abstract mixin class $PluginCommandCopyWith<$Res>  {
  factory $PluginCommandCopyWith(PluginCommand value, $Res Function(PluginCommand) _then) = _$PluginCommandCopyWithImpl;
@useResult
$Res call({
 String name, String? template, List<String> hints, String? description, String? agent, String? model, PluginCommandSource? source, bool? subtask
});




}
/// @nodoc
class _$PluginCommandCopyWithImpl<$Res>
    implements $PluginCommandCopyWith<$Res> {
  _$PluginCommandCopyWithImpl(this._self, this._then);

  final PluginCommand _self;
  final $Res Function(PluginCommand) _then;

/// Create a copy of PluginCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? template = freezed,Object? hints = null,Object? description = freezed,Object? agent = freezed,Object? model = freezed,Object? source = freezed,Object? subtask = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,template: freezed == template ? _self.template : template // ignore: cast_nullable_to_non_nullable
as String?,hints: null == hints ? _self.hints : hints // ignore: cast_nullable_to_non_nullable
as List<String>,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as PluginCommandSource?,subtask: freezed == subtask ? _self.subtask : subtask // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _PluginCommand implements PluginCommand {
  const _PluginCommand({required this.name, this.template, final  List<String> hints = const <String>[], this.description, this.agent, this.model, this.source, this.subtask}): _hints = hints;
  factory _PluginCommand.fromJson(Map<String, dynamic> json) => _$PluginCommandFromJson(json);

@override final  String name;
@override final  String? template;
 final  List<String> _hints;
@override@JsonKey() List<String> get hints {
  if (_hints is EqualUnmodifiableListView) return _hints;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_hints);
}

@override final  String? description;
@override final  String? agent;
@override final  String? model;
@override final  PluginCommandSource? source;
@override final  bool? subtask;

/// Create a copy of PluginCommand
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginCommandCopyWith<_PluginCommand> get copyWith => __$PluginCommandCopyWithImpl<_PluginCommand>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginCommandToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginCommand&&(identical(other.name, name) || other.name == name)&&(identical(other.template, template) || other.template == template)&&const DeepCollectionEquality().equals(other._hints, _hints)&&(identical(other.description, description) || other.description == description)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.model, model) || other.model == model)&&(identical(other.source, source) || other.source == source)&&(identical(other.subtask, subtask) || other.subtask == subtask));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,template,const DeepCollectionEquality().hash(_hints),description,agent,model,source,subtask);

@override
String toString() {
  return 'PluginCommand(name: $name, template: $template, hints: $hints, description: $description, agent: $agent, model: $model, source: $source, subtask: $subtask)';
}


}

/// @nodoc
abstract mixin class _$PluginCommandCopyWith<$Res> implements $PluginCommandCopyWith<$Res> {
  factory _$PluginCommandCopyWith(_PluginCommand value, $Res Function(_PluginCommand) _then) = __$PluginCommandCopyWithImpl;
@override @useResult
$Res call({
 String name, String? template, List<String> hints, String? description, String? agent, String? model, PluginCommandSource? source, bool? subtask
});




}
/// @nodoc
class __$PluginCommandCopyWithImpl<$Res>
    implements _$PluginCommandCopyWith<$Res> {
  __$PluginCommandCopyWithImpl(this._self, this._then);

  final _PluginCommand _self;
  final $Res Function(_PluginCommand) _then;

/// Create a copy of PluginCommand
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? template = freezed,Object? hints = null,Object? description = freezed,Object? agent = freezed,Object? model = freezed,Object? source = freezed,Object? subtask = freezed,}) {
  return _then(_PluginCommand(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,template: freezed == template ? _self.template : template // ignore: cast_nullable_to_non_nullable
as String?,hints: null == hints ? _self._hints : hints // ignore: cast_nullable_to_non_nullable
as List<String>,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as PluginCommandSource?,subtask: freezed == subtask ? _self.subtask : subtask // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}

// dart format on
