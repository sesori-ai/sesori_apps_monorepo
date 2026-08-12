// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'new_session_options_service.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$NewSessionOptionsData {

 List<AgentInfo> get agents; List<ProviderInfo> get providers; List<CommandInfo> get commands; String? get selectedAgent; AgentModel? get selectedAgentModel; CommandInfo? get stagedCommand; List<SessionVariant> get availableVariants;
/// Create a copy of NewSessionOptionsData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSessionOptionsDataCopyWith<NewSessionOptionsData> get copyWith => _$NewSessionOptionsDataCopyWithImpl<NewSessionOptionsData>(this as NewSessionOptionsData, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionOptionsData&&const DeepCollectionEquality().equals(other.agents, agents)&&const DeepCollectionEquality().equals(other.providers, providers)&&const DeepCollectionEquality().equals(other.commands, commands)&&(identical(other.selectedAgent, selectedAgent) || other.selectedAgent == selectedAgent)&&(identical(other.selectedAgentModel, selectedAgentModel) || other.selectedAgentModel == selectedAgentModel)&&(identical(other.stagedCommand, stagedCommand) || other.stagedCommand == stagedCommand)&&const DeepCollectionEquality().equals(other.availableVariants, availableVariants));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(agents),const DeepCollectionEquality().hash(providers),const DeepCollectionEquality().hash(commands),selectedAgent,selectedAgentModel,stagedCommand,const DeepCollectionEquality().hash(availableVariants));

@override
String toString() {
  return 'NewSessionOptionsData(agents: $agents, providers: $providers, commands: $commands, selectedAgent: $selectedAgent, selectedAgentModel: $selectedAgentModel, stagedCommand: $stagedCommand, availableVariants: $availableVariants)';
}


}

/// @nodoc
abstract mixin class $NewSessionOptionsDataCopyWith<$Res>  {
  factory $NewSessionOptionsDataCopyWith(NewSessionOptionsData value, $Res Function(NewSessionOptionsData) _then) = _$NewSessionOptionsDataCopyWithImpl;
@useResult
$Res call({
 List<AgentInfo> agents, List<ProviderInfo> providers, List<CommandInfo> commands, String? selectedAgent, AgentModel? selectedAgentModel, CommandInfo? stagedCommand, List<SessionVariant> availableVariants
});


$AgentModelCopyWith<$Res>? get selectedAgentModel;$CommandInfoCopyWith<$Res>? get stagedCommand;

}
/// @nodoc
class _$NewSessionOptionsDataCopyWithImpl<$Res>
    implements $NewSessionOptionsDataCopyWith<$Res> {
  _$NewSessionOptionsDataCopyWithImpl(this._self, this._then);

  final NewSessionOptionsData _self;
  final $Res Function(NewSessionOptionsData) _then;

/// Create a copy of NewSessionOptionsData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? agents = null,Object? providers = null,Object? commands = null,Object? selectedAgent = freezed,Object? selectedAgentModel = freezed,Object? stagedCommand = freezed,Object? availableVariants = null,}) {
  return _then(NewSessionOptionsData(
agents: null == agents ? _self.agents : agents // ignore: cast_nullable_to_non_nullable
as List<AgentInfo>,providers: null == providers ? _self.providers : providers // ignore: cast_nullable_to_non_nullable
as List<ProviderInfo>,commands: null == commands ? _self.commands : commands // ignore: cast_nullable_to_non_nullable
as List<CommandInfo>,selectedAgent: freezed == selectedAgent ? _self.selectedAgent : selectedAgent // ignore: cast_nullable_to_non_nullable
as String?,selectedAgentModel: freezed == selectedAgentModel ? _self.selectedAgentModel : selectedAgentModel // ignore: cast_nullable_to_non_nullable
as AgentModel?,stagedCommand: freezed == stagedCommand ? _self.stagedCommand : stagedCommand // ignore: cast_nullable_to_non_nullable
as CommandInfo?,availableVariants: null == availableVariants ? _self.availableVariants : availableVariants // ignore: cast_nullable_to_non_nullable
as List<SessionVariant>,
  ));
}
/// Create a copy of NewSessionOptionsData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AgentModelCopyWith<$Res>? get selectedAgentModel {
    if (_self.selectedAgentModel == null) {
    return null;
  }

  return $AgentModelCopyWith<$Res>(_self.selectedAgentModel!, (value) {
    return _then(_self.copyWith(selectedAgentModel: value));
  });
}/// Create a copy of NewSessionOptionsData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CommandInfoCopyWith<$Res>? get stagedCommand {
    if (_self.stagedCommand == null) {
    return null;
  }

  return $CommandInfoCopyWith<$Res>(_self.stagedCommand!, (value) {
    return _then(_self.copyWith(stagedCommand: value));
  });
}
}



/// @nodoc


class _NewSessionOptionsData implements NewSessionOptionsData {
  const _NewSessionOptionsData({required  List<AgentInfo> agents, required  List<ProviderInfo> providers, required  List<CommandInfo> commands, required this.selectedAgent, required this.selectedAgentModel, required this.stagedCommand, required  List<SessionVariant> availableVariants}): _agents = agents,_providers = providers,_commands = commands,_availableVariants = availableVariants;
  

 final  List<AgentInfo> _agents;
@override List<AgentInfo> get agents {
  if (_agents is EqualUnmodifiableListView) return _agents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_agents);
}

 final  List<ProviderInfo> _providers;
@override List<ProviderInfo> get providers {
  if (_providers is EqualUnmodifiableListView) return _providers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_providers);
}

 final  List<CommandInfo> _commands;
@override List<CommandInfo> get commands {
  if (_commands is EqualUnmodifiableListView) return _commands;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_commands);
}

@override final  String? selectedAgent;
@override final  AgentModel? selectedAgentModel;
@override final  CommandInfo? stagedCommand;
 final  List<SessionVariant> _availableVariants;
@override List<SessionVariant> get availableVariants {
  if (_availableVariants is EqualUnmodifiableListView) return _availableVariants;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availableVariants);
}


/// Create a copy of NewSessionOptionsData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NewSessionOptionsDataCopyWith<_NewSessionOptionsData> get copyWith => __$NewSessionOptionsDataCopyWithImpl<_NewSessionOptionsData>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NewSessionOptionsData&&const DeepCollectionEquality().equals(other._agents, _agents)&&const DeepCollectionEquality().equals(other._providers, _providers)&&const DeepCollectionEquality().equals(other._commands, _commands)&&(identical(other.selectedAgent, selectedAgent) || other.selectedAgent == selectedAgent)&&(identical(other.selectedAgentModel, selectedAgentModel) || other.selectedAgentModel == selectedAgentModel)&&(identical(other.stagedCommand, stagedCommand) || other.stagedCommand == stagedCommand)&&const DeepCollectionEquality().equals(other._availableVariants, _availableVariants));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_agents),const DeepCollectionEquality().hash(_providers),const DeepCollectionEquality().hash(_commands),selectedAgent,selectedAgentModel,stagedCommand,const DeepCollectionEquality().hash(_availableVariants));

@override
String toString() {
  return 'NewSessionOptionsData(agents: $agents, providers: $providers, commands: $commands, selectedAgent: $selectedAgent, selectedAgentModel: $selectedAgentModel, stagedCommand: $stagedCommand, availableVariants: $availableVariants)';
}


}

/// @nodoc
abstract mixin class _$NewSessionOptionsDataCopyWith<$Res> implements $NewSessionOptionsDataCopyWith<$Res> {
  factory _$NewSessionOptionsDataCopyWith(_NewSessionOptionsData value, $Res Function(_NewSessionOptionsData) _then) = __$NewSessionOptionsDataCopyWithImpl;
@override @useResult
$Res call({
 List<AgentInfo> agents, List<ProviderInfo> providers, List<CommandInfo> commands, String? selectedAgent, AgentModel? selectedAgentModel, CommandInfo? stagedCommand, List<SessionVariant> availableVariants
});


@override $AgentModelCopyWith<$Res>? get selectedAgentModel;@override $CommandInfoCopyWith<$Res>? get stagedCommand;

}
/// @nodoc
class __$NewSessionOptionsDataCopyWithImpl<$Res>
    implements _$NewSessionOptionsDataCopyWith<$Res> {
  __$NewSessionOptionsDataCopyWithImpl(this._self, this._then);

  final _NewSessionOptionsData _self;
  final $Res Function(_NewSessionOptionsData) _then;

/// Create a copy of NewSessionOptionsData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? agents = null,Object? providers = null,Object? commands = null,Object? selectedAgent = freezed,Object? selectedAgentModel = freezed,Object? stagedCommand = freezed,Object? availableVariants = null,}) {
  return _then(_NewSessionOptionsData(
agents: null == agents ? _self._agents : agents // ignore: cast_nullable_to_non_nullable
as List<AgentInfo>,providers: null == providers ? _self._providers : providers // ignore: cast_nullable_to_non_nullable
as List<ProviderInfo>,commands: null == commands ? _self._commands : commands // ignore: cast_nullable_to_non_nullable
as List<CommandInfo>,selectedAgent: freezed == selectedAgent ? _self.selectedAgent : selectedAgent // ignore: cast_nullable_to_non_nullable
as String?,selectedAgentModel: freezed == selectedAgentModel ? _self.selectedAgentModel : selectedAgentModel // ignore: cast_nullable_to_non_nullable
as AgentModel?,stagedCommand: freezed == stagedCommand ? _self.stagedCommand : stagedCommand // ignore: cast_nullable_to_non_nullable
as CommandInfo?,availableVariants: null == availableVariants ? _self._availableVariants : availableVariants // ignore: cast_nullable_to_non_nullable
as List<SessionVariant>,
  ));
}

/// Create a copy of NewSessionOptionsData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AgentModelCopyWith<$Res>? get selectedAgentModel {
    if (_self.selectedAgentModel == null) {
    return null;
  }

  return $AgentModelCopyWith<$Res>(_self.selectedAgentModel!, (value) {
    return _then(_self.copyWith(selectedAgentModel: value));
  });
}/// Create a copy of NewSessionOptionsData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CommandInfoCopyWith<$Res>? get stagedCommand {
    if (_self.stagedCommand == null) {
    return null;
  }

  return $CommandInfoCopyWith<$Res>(_self.stagedCommand!, (value) {
    return _then(_self.copyWith(stagedCommand: value));
  });
}
}

// dart format on
