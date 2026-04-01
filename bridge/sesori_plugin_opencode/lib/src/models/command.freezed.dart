// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'command.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Command {

 String get name;@JsonKey(readValue: _readTemplate) String? get template; List<String> get hints; String? get description; String? get agent; String? get model;@JsonKey(unknownEnumValue: CommandSource.unknown) CommandSource? get source; bool? get subtask;
/// Create a copy of Command
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommandCopyWith<Command> get copyWith => _$CommandCopyWithImpl<Command>(this as Command, _$identity);

  /// Serializes this Command to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Command&&(identical(other.name, name) || other.name == name)&&(identical(other.template, template) || other.template == template)&&const DeepCollectionEquality().equals(other.hints, hints)&&(identical(other.description, description) || other.description == description)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.model, model) || other.model == model)&&(identical(other.source, source) || other.source == source)&&(identical(other.subtask, subtask) || other.subtask == subtask));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,template,const DeepCollectionEquality().hash(hints),description,agent,model,source,subtask);

@override
String toString() {
  return 'Command(name: $name, template: $template, hints: $hints, description: $description, agent: $agent, model: $model, source: $source, subtask: $subtask)';
}


}

/// @nodoc
abstract mixin class $CommandCopyWith<$Res>  {
  factory $CommandCopyWith(Command value, $Res Function(Command) _then) = _$CommandCopyWithImpl;
@useResult
$Res call({
 String name,@JsonKey(readValue: _readTemplate) String? template, List<String> hints, String? description, String? agent, String? model,@JsonKey(unknownEnumValue: CommandSource.unknown) CommandSource? source, bool? subtask
});




}
/// @nodoc
class _$CommandCopyWithImpl<$Res>
    implements $CommandCopyWith<$Res> {
  _$CommandCopyWithImpl(this._self, this._then);

  final Command _self;
  final $Res Function(Command) _then;

/// Create a copy of Command
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
as CommandSource?,subtask: freezed == subtask ? _self.subtask : subtask // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _Command implements Command {
  const _Command({required this.name, @JsonKey(readValue: _readTemplate) this.template, final  List<String> hints = const <String>[], this.description, this.agent, this.model, @JsonKey(unknownEnumValue: CommandSource.unknown) this.source, this.subtask}): _hints = hints;
  factory _Command.fromJson(Map<String, dynamic> json) => _$CommandFromJson(json);

@override final  String name;
@override@JsonKey(readValue: _readTemplate) final  String? template;
 final  List<String> _hints;
@override@JsonKey() List<String> get hints {
  if (_hints is EqualUnmodifiableListView) return _hints;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_hints);
}

@override final  String? description;
@override final  String? agent;
@override final  String? model;
@override@JsonKey(unknownEnumValue: CommandSource.unknown) final  CommandSource? source;
@override final  bool? subtask;

/// Create a copy of Command
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommandCopyWith<_Command> get copyWith => __$CommandCopyWithImpl<_Command>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CommandToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Command&&(identical(other.name, name) || other.name == name)&&(identical(other.template, template) || other.template == template)&&const DeepCollectionEquality().equals(other._hints, _hints)&&(identical(other.description, description) || other.description == description)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.model, model) || other.model == model)&&(identical(other.source, source) || other.source == source)&&(identical(other.subtask, subtask) || other.subtask == subtask));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,template,const DeepCollectionEquality().hash(_hints),description,agent,model,source,subtask);

@override
String toString() {
  return 'Command(name: $name, template: $template, hints: $hints, description: $description, agent: $agent, model: $model, source: $source, subtask: $subtask)';
}


}

/// @nodoc
abstract mixin class _$CommandCopyWith<$Res> implements $CommandCopyWith<$Res> {
  factory _$CommandCopyWith(_Command value, $Res Function(_Command) _then) = __$CommandCopyWithImpl;
@override @useResult
$Res call({
 String name,@JsonKey(readValue: _readTemplate) String? template, List<String> hints, String? description, String? agent, String? model,@JsonKey(unknownEnumValue: CommandSource.unknown) CommandSource? source, bool? subtask
});




}
/// @nodoc
class __$CommandCopyWithImpl<$Res>
    implements _$CommandCopyWith<$Res> {
  __$CommandCopyWithImpl(this._self, this._then);

  final _Command _self;
  final $Res Function(_Command) _then;

/// Create a copy of Command
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? template = freezed,Object? hints = null,Object? description = freezed,Object? agent = freezed,Object? model = freezed,Object? source = freezed,Object? subtask = freezed,}) {
  return _then(_Command(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,template: freezed == template ? _self.template : template // ignore: cast_nullable_to_non_nullable
as String?,hints: null == hints ? _self._hints : hints // ignore: cast_nullable_to_non_nullable
as List<String>,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as CommandSource?,subtask: freezed == subtask ? _self.subtask : subtask // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}

// dart format on
