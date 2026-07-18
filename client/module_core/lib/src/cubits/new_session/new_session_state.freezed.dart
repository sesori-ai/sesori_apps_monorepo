// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'new_session_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$NewSessionState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'NewSessionState()';
}


}

/// @nodoc
class $NewSessionStateCopyWith<$Res>  {
$NewSessionStateCopyWith(NewSessionState _, $Res Function(NewSessionState) __);
}



/// @nodoc


class NewSessionIdle implements NewSessionState {
  const NewSessionIdle({required final  List<PluginMetadata> availablePlugins, required this.selectedPlugin, required this.isComposerDataLoading, required this.isPluginDiscoveryInFlight, required final  List<AgentInfo> availableAgents, required final  List<ProviderInfo> availableProviders, required final  List<CommandInfo> availableCommands, required this.selectedAgent, required this.selectedAgentModel, required this.stagedCommand, final  List<SessionVariant> availableVariants = const [], required this.supportsDedicatedWorktrees}): _availablePlugins = availablePlugins,_availableAgents = availableAgents,_availableProviders = availableProviders,_availableCommands = availableCommands,_availableVariants = availableVariants;
  

 final  List<PluginMetadata> _availablePlugins;
 List<PluginMetadata> get availablePlugins {
  if (_availablePlugins is EqualUnmodifiableListView) return _availablePlugins;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availablePlugins);
}

 final  PluginMetadata? selectedPlugin;
 final  bool isComposerDataLoading;
 final  bool isPluginDiscoveryInFlight;
 final  List<AgentInfo> _availableAgents;
 List<AgentInfo> get availableAgents {
  if (_availableAgents is EqualUnmodifiableListView) return _availableAgents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availableAgents);
}

 final  List<ProviderInfo> _availableProviders;
 List<ProviderInfo> get availableProviders {
  if (_availableProviders is EqualUnmodifiableListView) return _availableProviders;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availableProviders);
}

 final  List<CommandInfo> _availableCommands;
 List<CommandInfo> get availableCommands {
  if (_availableCommands is EqualUnmodifiableListView) return _availableCommands;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availableCommands);
}

 final  String? selectedAgent;
 final  AgentModel? selectedAgentModel;
 final  CommandInfo? stagedCommand;
 final  List<SessionVariant> _availableVariants;
@JsonKey() List<SessionVariant> get availableVariants {
  if (_availableVariants is EqualUnmodifiableListView) return _availableVariants;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availableVariants);
}

 final  bool supportsDedicatedWorktrees;

/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSessionIdleCopyWith<NewSessionIdle> get copyWith => _$NewSessionIdleCopyWithImpl<NewSessionIdle>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionIdle&&const DeepCollectionEquality().equals(other._availablePlugins, _availablePlugins)&&(identical(other.selectedPlugin, selectedPlugin) || other.selectedPlugin == selectedPlugin)&&(identical(other.isComposerDataLoading, isComposerDataLoading) || other.isComposerDataLoading == isComposerDataLoading)&&(identical(other.isPluginDiscoveryInFlight, isPluginDiscoveryInFlight) || other.isPluginDiscoveryInFlight == isPluginDiscoveryInFlight)&&const DeepCollectionEquality().equals(other._availableAgents, _availableAgents)&&const DeepCollectionEquality().equals(other._availableProviders, _availableProviders)&&const DeepCollectionEquality().equals(other._availableCommands, _availableCommands)&&(identical(other.selectedAgent, selectedAgent) || other.selectedAgent == selectedAgent)&&(identical(other.selectedAgentModel, selectedAgentModel) || other.selectedAgentModel == selectedAgentModel)&&(identical(other.stagedCommand, stagedCommand) || other.stagedCommand == stagedCommand)&&const DeepCollectionEquality().equals(other._availableVariants, _availableVariants)&&(identical(other.supportsDedicatedWorktrees, supportsDedicatedWorktrees) || other.supportsDedicatedWorktrees == supportsDedicatedWorktrees));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_availablePlugins),selectedPlugin,isComposerDataLoading,isPluginDiscoveryInFlight,const DeepCollectionEquality().hash(_availableAgents),const DeepCollectionEquality().hash(_availableProviders),const DeepCollectionEquality().hash(_availableCommands),selectedAgent,selectedAgentModel,stagedCommand,const DeepCollectionEquality().hash(_availableVariants),supportsDedicatedWorktrees);

@override
String toString() {
  return 'NewSessionState.idle(availablePlugins: $availablePlugins, selectedPlugin: $selectedPlugin, isComposerDataLoading: $isComposerDataLoading, isPluginDiscoveryInFlight: $isPluginDiscoveryInFlight, availableAgents: $availableAgents, availableProviders: $availableProviders, availableCommands: $availableCommands, selectedAgent: $selectedAgent, selectedAgentModel: $selectedAgentModel, stagedCommand: $stagedCommand, availableVariants: $availableVariants, supportsDedicatedWorktrees: $supportsDedicatedWorktrees)';
}


}

/// @nodoc
abstract mixin class $NewSessionIdleCopyWith<$Res> implements $NewSessionStateCopyWith<$Res> {
  factory $NewSessionIdleCopyWith(NewSessionIdle value, $Res Function(NewSessionIdle) _then) = _$NewSessionIdleCopyWithImpl;
@useResult
$Res call({
 List<PluginMetadata> availablePlugins, PluginMetadata? selectedPlugin, bool isComposerDataLoading, bool isPluginDiscoveryInFlight, List<AgentInfo> availableAgents, List<ProviderInfo> availableProviders, List<CommandInfo> availableCommands, String? selectedAgent, AgentModel? selectedAgentModel, CommandInfo? stagedCommand, List<SessionVariant> availableVariants, bool supportsDedicatedWorktrees
});


$PluginMetadataCopyWith<$Res>? get selectedPlugin;$AgentModelCopyWith<$Res>? get selectedAgentModel;$CommandInfoCopyWith<$Res>? get stagedCommand;

}
/// @nodoc
class _$NewSessionIdleCopyWithImpl<$Res>
    implements $NewSessionIdleCopyWith<$Res> {
  _$NewSessionIdleCopyWithImpl(this._self, this._then);

  final NewSessionIdle _self;
  final $Res Function(NewSessionIdle) _then;

/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? availablePlugins = null,Object? selectedPlugin = freezed,Object? isComposerDataLoading = null,Object? isPluginDiscoveryInFlight = null,Object? availableAgents = null,Object? availableProviders = null,Object? availableCommands = null,Object? selectedAgent = freezed,Object? selectedAgentModel = freezed,Object? stagedCommand = freezed,Object? availableVariants = null,Object? supportsDedicatedWorktrees = null,}) {
  return _then(NewSessionIdle(
availablePlugins: null == availablePlugins ? _self._availablePlugins : availablePlugins // ignore: cast_nullable_to_non_nullable
as List<PluginMetadata>,selectedPlugin: freezed == selectedPlugin ? _self.selectedPlugin : selectedPlugin // ignore: cast_nullable_to_non_nullable
as PluginMetadata?,isComposerDataLoading: null == isComposerDataLoading ? _self.isComposerDataLoading : isComposerDataLoading // ignore: cast_nullable_to_non_nullable
as bool,isPluginDiscoveryInFlight: null == isPluginDiscoveryInFlight ? _self.isPluginDiscoveryInFlight : isPluginDiscoveryInFlight // ignore: cast_nullable_to_non_nullable
as bool,availableAgents: null == availableAgents ? _self._availableAgents : availableAgents // ignore: cast_nullable_to_non_nullable
as List<AgentInfo>,availableProviders: null == availableProviders ? _self._availableProviders : availableProviders // ignore: cast_nullable_to_non_nullable
as List<ProviderInfo>,availableCommands: null == availableCommands ? _self._availableCommands : availableCommands // ignore: cast_nullable_to_non_nullable
as List<CommandInfo>,selectedAgent: freezed == selectedAgent ? _self.selectedAgent : selectedAgent // ignore: cast_nullable_to_non_nullable
as String?,selectedAgentModel: freezed == selectedAgentModel ? _self.selectedAgentModel : selectedAgentModel // ignore: cast_nullable_to_non_nullable
as AgentModel?,stagedCommand: freezed == stagedCommand ? _self.stagedCommand : stagedCommand // ignore: cast_nullable_to_non_nullable
as CommandInfo?,availableVariants: null == availableVariants ? _self._availableVariants : availableVariants // ignore: cast_nullable_to_non_nullable
as List<SessionVariant>,supportsDedicatedWorktrees: null == supportsDedicatedWorktrees ? _self.supportsDedicatedWorktrees : supportsDedicatedWorktrees // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginMetadataCopyWith<$Res>? get selectedPlugin {
    if (_self.selectedPlugin == null) {
    return null;
  }

  return $PluginMetadataCopyWith<$Res>(_self.selectedPlugin!, (value) {
    return _then(_self.copyWith(selectedPlugin: value));
  });
}/// Create a copy of NewSessionState
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
}/// Create a copy of NewSessionState
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


class NewSessionSending implements NewSessionState {
  const NewSessionSending({required final  List<PluginMetadata> availablePlugins, required this.selectedPlugin, required this.isComposerDataLoading, required this.isPluginDiscoveryInFlight, required final  List<AgentInfo> availableAgents, required final  List<ProviderInfo> availableProviders, required final  List<CommandInfo> availableCommands, required this.selectedAgent, required this.selectedAgentModel, required this.stagedCommand, final  List<SessionVariant> availableVariants = const [], required this.supportsDedicatedWorktrees}): _availablePlugins = availablePlugins,_availableAgents = availableAgents,_availableProviders = availableProviders,_availableCommands = availableCommands,_availableVariants = availableVariants;
  

 final  List<PluginMetadata> _availablePlugins;
 List<PluginMetadata> get availablePlugins {
  if (_availablePlugins is EqualUnmodifiableListView) return _availablePlugins;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availablePlugins);
}

 final  PluginMetadata? selectedPlugin;
 final  bool isComposerDataLoading;
 final  bool isPluginDiscoveryInFlight;
 final  List<AgentInfo> _availableAgents;
 List<AgentInfo> get availableAgents {
  if (_availableAgents is EqualUnmodifiableListView) return _availableAgents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availableAgents);
}

 final  List<ProviderInfo> _availableProviders;
 List<ProviderInfo> get availableProviders {
  if (_availableProviders is EqualUnmodifiableListView) return _availableProviders;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availableProviders);
}

 final  List<CommandInfo> _availableCommands;
 List<CommandInfo> get availableCommands {
  if (_availableCommands is EqualUnmodifiableListView) return _availableCommands;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availableCommands);
}

 final  String? selectedAgent;
 final  AgentModel? selectedAgentModel;
 final  CommandInfo? stagedCommand;
 final  List<SessionVariant> _availableVariants;
@JsonKey() List<SessionVariant> get availableVariants {
  if (_availableVariants is EqualUnmodifiableListView) return _availableVariants;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availableVariants);
}

 final  bool supportsDedicatedWorktrees;

/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSessionSendingCopyWith<NewSessionSending> get copyWith => _$NewSessionSendingCopyWithImpl<NewSessionSending>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionSending&&const DeepCollectionEquality().equals(other._availablePlugins, _availablePlugins)&&(identical(other.selectedPlugin, selectedPlugin) || other.selectedPlugin == selectedPlugin)&&(identical(other.isComposerDataLoading, isComposerDataLoading) || other.isComposerDataLoading == isComposerDataLoading)&&(identical(other.isPluginDiscoveryInFlight, isPluginDiscoveryInFlight) || other.isPluginDiscoveryInFlight == isPluginDiscoveryInFlight)&&const DeepCollectionEquality().equals(other._availableAgents, _availableAgents)&&const DeepCollectionEquality().equals(other._availableProviders, _availableProviders)&&const DeepCollectionEquality().equals(other._availableCommands, _availableCommands)&&(identical(other.selectedAgent, selectedAgent) || other.selectedAgent == selectedAgent)&&(identical(other.selectedAgentModel, selectedAgentModel) || other.selectedAgentModel == selectedAgentModel)&&(identical(other.stagedCommand, stagedCommand) || other.stagedCommand == stagedCommand)&&const DeepCollectionEquality().equals(other._availableVariants, _availableVariants)&&(identical(other.supportsDedicatedWorktrees, supportsDedicatedWorktrees) || other.supportsDedicatedWorktrees == supportsDedicatedWorktrees));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_availablePlugins),selectedPlugin,isComposerDataLoading,isPluginDiscoveryInFlight,const DeepCollectionEquality().hash(_availableAgents),const DeepCollectionEquality().hash(_availableProviders),const DeepCollectionEquality().hash(_availableCommands),selectedAgent,selectedAgentModel,stagedCommand,const DeepCollectionEquality().hash(_availableVariants),supportsDedicatedWorktrees);

@override
String toString() {
  return 'NewSessionState.sending(availablePlugins: $availablePlugins, selectedPlugin: $selectedPlugin, isComposerDataLoading: $isComposerDataLoading, isPluginDiscoveryInFlight: $isPluginDiscoveryInFlight, availableAgents: $availableAgents, availableProviders: $availableProviders, availableCommands: $availableCommands, selectedAgent: $selectedAgent, selectedAgentModel: $selectedAgentModel, stagedCommand: $stagedCommand, availableVariants: $availableVariants, supportsDedicatedWorktrees: $supportsDedicatedWorktrees)';
}


}

/// @nodoc
abstract mixin class $NewSessionSendingCopyWith<$Res> implements $NewSessionStateCopyWith<$Res> {
  factory $NewSessionSendingCopyWith(NewSessionSending value, $Res Function(NewSessionSending) _then) = _$NewSessionSendingCopyWithImpl;
@useResult
$Res call({
 List<PluginMetadata> availablePlugins, PluginMetadata? selectedPlugin, bool isComposerDataLoading, bool isPluginDiscoveryInFlight, List<AgentInfo> availableAgents, List<ProviderInfo> availableProviders, List<CommandInfo> availableCommands, String? selectedAgent, AgentModel? selectedAgentModel, CommandInfo? stagedCommand, List<SessionVariant> availableVariants, bool supportsDedicatedWorktrees
});


$PluginMetadataCopyWith<$Res>? get selectedPlugin;$AgentModelCopyWith<$Res>? get selectedAgentModel;$CommandInfoCopyWith<$Res>? get stagedCommand;

}
/// @nodoc
class _$NewSessionSendingCopyWithImpl<$Res>
    implements $NewSessionSendingCopyWith<$Res> {
  _$NewSessionSendingCopyWithImpl(this._self, this._then);

  final NewSessionSending _self;
  final $Res Function(NewSessionSending) _then;

/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? availablePlugins = null,Object? selectedPlugin = freezed,Object? isComposerDataLoading = null,Object? isPluginDiscoveryInFlight = null,Object? availableAgents = null,Object? availableProviders = null,Object? availableCommands = null,Object? selectedAgent = freezed,Object? selectedAgentModel = freezed,Object? stagedCommand = freezed,Object? availableVariants = null,Object? supportsDedicatedWorktrees = null,}) {
  return _then(NewSessionSending(
availablePlugins: null == availablePlugins ? _self._availablePlugins : availablePlugins // ignore: cast_nullable_to_non_nullable
as List<PluginMetadata>,selectedPlugin: freezed == selectedPlugin ? _self.selectedPlugin : selectedPlugin // ignore: cast_nullable_to_non_nullable
as PluginMetadata?,isComposerDataLoading: null == isComposerDataLoading ? _self.isComposerDataLoading : isComposerDataLoading // ignore: cast_nullable_to_non_nullable
as bool,isPluginDiscoveryInFlight: null == isPluginDiscoveryInFlight ? _self.isPluginDiscoveryInFlight : isPluginDiscoveryInFlight // ignore: cast_nullable_to_non_nullable
as bool,availableAgents: null == availableAgents ? _self._availableAgents : availableAgents // ignore: cast_nullable_to_non_nullable
as List<AgentInfo>,availableProviders: null == availableProviders ? _self._availableProviders : availableProviders // ignore: cast_nullable_to_non_nullable
as List<ProviderInfo>,availableCommands: null == availableCommands ? _self._availableCommands : availableCommands // ignore: cast_nullable_to_non_nullable
as List<CommandInfo>,selectedAgent: freezed == selectedAgent ? _self.selectedAgent : selectedAgent // ignore: cast_nullable_to_non_nullable
as String?,selectedAgentModel: freezed == selectedAgentModel ? _self.selectedAgentModel : selectedAgentModel // ignore: cast_nullable_to_non_nullable
as AgentModel?,stagedCommand: freezed == stagedCommand ? _self.stagedCommand : stagedCommand // ignore: cast_nullable_to_non_nullable
as CommandInfo?,availableVariants: null == availableVariants ? _self._availableVariants : availableVariants // ignore: cast_nullable_to_non_nullable
as List<SessionVariant>,supportsDedicatedWorktrees: null == supportsDedicatedWorktrees ? _self.supportsDedicatedWorktrees : supportsDedicatedWorktrees // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginMetadataCopyWith<$Res>? get selectedPlugin {
    if (_self.selectedPlugin == null) {
    return null;
  }

  return $PluginMetadataCopyWith<$Res>(_self.selectedPlugin!, (value) {
    return _then(_self.copyWith(selectedPlugin: value));
  });
}/// Create a copy of NewSessionState
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
}/// Create a copy of NewSessionState
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


class NewSessionError implements NewSessionState {
  const NewSessionError({required this.reason, required final  List<PluginMetadata> availablePlugins, required this.selectedPlugin, required this.isComposerDataLoading, required this.isPluginDiscoveryInFlight, required final  List<AgentInfo> availableAgents, required final  List<ProviderInfo> availableProviders, required final  List<CommandInfo> availableCommands, required this.selectedAgent, required this.selectedAgentModel, required this.stagedCommand, final  List<SessionVariant> availableVariants = const [], required this.supportsDedicatedWorktrees}): _availablePlugins = availablePlugins,_availableAgents = availableAgents,_availableProviders = availableProviders,_availableCommands = availableCommands,_availableVariants = availableVariants;
  

 final  RemoteFailureReason reason;
 final  List<PluginMetadata> _availablePlugins;
 List<PluginMetadata> get availablePlugins {
  if (_availablePlugins is EqualUnmodifiableListView) return _availablePlugins;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availablePlugins);
}

 final  PluginMetadata? selectedPlugin;
 final  bool isComposerDataLoading;
 final  bool isPluginDiscoveryInFlight;
 final  List<AgentInfo> _availableAgents;
 List<AgentInfo> get availableAgents {
  if (_availableAgents is EqualUnmodifiableListView) return _availableAgents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availableAgents);
}

 final  List<ProviderInfo> _availableProviders;
 List<ProviderInfo> get availableProviders {
  if (_availableProviders is EqualUnmodifiableListView) return _availableProviders;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availableProviders);
}

 final  List<CommandInfo> _availableCommands;
 List<CommandInfo> get availableCommands {
  if (_availableCommands is EqualUnmodifiableListView) return _availableCommands;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availableCommands);
}

 final  String? selectedAgent;
 final  AgentModel? selectedAgentModel;
 final  CommandInfo? stagedCommand;
 final  List<SessionVariant> _availableVariants;
@JsonKey() List<SessionVariant> get availableVariants {
  if (_availableVariants is EqualUnmodifiableListView) return _availableVariants;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availableVariants);
}

 final  bool supportsDedicatedWorktrees;

/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSessionErrorCopyWith<NewSessionError> get copyWith => _$NewSessionErrorCopyWithImpl<NewSessionError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionError&&(identical(other.reason, reason) || other.reason == reason)&&const DeepCollectionEquality().equals(other._availablePlugins, _availablePlugins)&&(identical(other.selectedPlugin, selectedPlugin) || other.selectedPlugin == selectedPlugin)&&(identical(other.isComposerDataLoading, isComposerDataLoading) || other.isComposerDataLoading == isComposerDataLoading)&&(identical(other.isPluginDiscoveryInFlight, isPluginDiscoveryInFlight) || other.isPluginDiscoveryInFlight == isPluginDiscoveryInFlight)&&const DeepCollectionEquality().equals(other._availableAgents, _availableAgents)&&const DeepCollectionEquality().equals(other._availableProviders, _availableProviders)&&const DeepCollectionEquality().equals(other._availableCommands, _availableCommands)&&(identical(other.selectedAgent, selectedAgent) || other.selectedAgent == selectedAgent)&&(identical(other.selectedAgentModel, selectedAgentModel) || other.selectedAgentModel == selectedAgentModel)&&(identical(other.stagedCommand, stagedCommand) || other.stagedCommand == stagedCommand)&&const DeepCollectionEquality().equals(other._availableVariants, _availableVariants)&&(identical(other.supportsDedicatedWorktrees, supportsDedicatedWorktrees) || other.supportsDedicatedWorktrees == supportsDedicatedWorktrees));
}


@override
int get hashCode => Object.hash(runtimeType,reason,const DeepCollectionEquality().hash(_availablePlugins),selectedPlugin,isComposerDataLoading,isPluginDiscoveryInFlight,const DeepCollectionEquality().hash(_availableAgents),const DeepCollectionEquality().hash(_availableProviders),const DeepCollectionEquality().hash(_availableCommands),selectedAgent,selectedAgentModel,stagedCommand,const DeepCollectionEquality().hash(_availableVariants),supportsDedicatedWorktrees);

@override
String toString() {
  return 'NewSessionState.error(reason: $reason, availablePlugins: $availablePlugins, selectedPlugin: $selectedPlugin, isComposerDataLoading: $isComposerDataLoading, isPluginDiscoveryInFlight: $isPluginDiscoveryInFlight, availableAgents: $availableAgents, availableProviders: $availableProviders, availableCommands: $availableCommands, selectedAgent: $selectedAgent, selectedAgentModel: $selectedAgentModel, stagedCommand: $stagedCommand, availableVariants: $availableVariants, supportsDedicatedWorktrees: $supportsDedicatedWorktrees)';
}


}

/// @nodoc
abstract mixin class $NewSessionErrorCopyWith<$Res> implements $NewSessionStateCopyWith<$Res> {
  factory $NewSessionErrorCopyWith(NewSessionError value, $Res Function(NewSessionError) _then) = _$NewSessionErrorCopyWithImpl;
@useResult
$Res call({
 RemoteFailureReason reason, List<PluginMetadata> availablePlugins, PluginMetadata? selectedPlugin, bool isComposerDataLoading, bool isPluginDiscoveryInFlight, List<AgentInfo> availableAgents, List<ProviderInfo> availableProviders, List<CommandInfo> availableCommands, String? selectedAgent, AgentModel? selectedAgentModel, CommandInfo? stagedCommand, List<SessionVariant> availableVariants, bool supportsDedicatedWorktrees
});


$PluginMetadataCopyWith<$Res>? get selectedPlugin;$AgentModelCopyWith<$Res>? get selectedAgentModel;$CommandInfoCopyWith<$Res>? get stagedCommand;

}
/// @nodoc
class _$NewSessionErrorCopyWithImpl<$Res>
    implements $NewSessionErrorCopyWith<$Res> {
  _$NewSessionErrorCopyWithImpl(this._self, this._then);

  final NewSessionError _self;
  final $Res Function(NewSessionError) _then;

/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reason = null,Object? availablePlugins = null,Object? selectedPlugin = freezed,Object? isComposerDataLoading = null,Object? isPluginDiscoveryInFlight = null,Object? availableAgents = null,Object? availableProviders = null,Object? availableCommands = null,Object? selectedAgent = freezed,Object? selectedAgentModel = freezed,Object? stagedCommand = freezed,Object? availableVariants = null,Object? supportsDedicatedWorktrees = null,}) {
  return _then(NewSessionError(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as RemoteFailureReason,availablePlugins: null == availablePlugins ? _self._availablePlugins : availablePlugins // ignore: cast_nullable_to_non_nullable
as List<PluginMetadata>,selectedPlugin: freezed == selectedPlugin ? _self.selectedPlugin : selectedPlugin // ignore: cast_nullable_to_non_nullable
as PluginMetadata?,isComposerDataLoading: null == isComposerDataLoading ? _self.isComposerDataLoading : isComposerDataLoading // ignore: cast_nullable_to_non_nullable
as bool,isPluginDiscoveryInFlight: null == isPluginDiscoveryInFlight ? _self.isPluginDiscoveryInFlight : isPluginDiscoveryInFlight // ignore: cast_nullable_to_non_nullable
as bool,availableAgents: null == availableAgents ? _self._availableAgents : availableAgents // ignore: cast_nullable_to_non_nullable
as List<AgentInfo>,availableProviders: null == availableProviders ? _self._availableProviders : availableProviders // ignore: cast_nullable_to_non_nullable
as List<ProviderInfo>,availableCommands: null == availableCommands ? _self._availableCommands : availableCommands // ignore: cast_nullable_to_non_nullable
as List<CommandInfo>,selectedAgent: freezed == selectedAgent ? _self.selectedAgent : selectedAgent // ignore: cast_nullable_to_non_nullable
as String?,selectedAgentModel: freezed == selectedAgentModel ? _self.selectedAgentModel : selectedAgentModel // ignore: cast_nullable_to_non_nullable
as AgentModel?,stagedCommand: freezed == stagedCommand ? _self.stagedCommand : stagedCommand // ignore: cast_nullable_to_non_nullable
as CommandInfo?,availableVariants: null == availableVariants ? _self._availableVariants : availableVariants // ignore: cast_nullable_to_non_nullable
as List<SessionVariant>,supportsDedicatedWorktrees: null == supportsDedicatedWorktrees ? _self.supportsDedicatedWorktrees : supportsDedicatedWorktrees // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginMetadataCopyWith<$Res>? get selectedPlugin {
    if (_self.selectedPlugin == null) {
    return null;
  }

  return $PluginMetadataCopyWith<$Res>(_self.selectedPlugin!, (value) {
    return _then(_self.copyWith(selectedPlugin: value));
  });
}/// Create a copy of NewSessionState
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
}/// Create a copy of NewSessionState
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


class NewSessionCreated implements NewSessionState {
  const NewSessionCreated({required this.session});
  

 final  Session session;

/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSessionCreatedCopyWith<NewSessionCreated> get copyWith => _$NewSessionCreatedCopyWithImpl<NewSessionCreated>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionCreated&&(identical(other.session, session) || other.session == session));
}


@override
int get hashCode => Object.hash(runtimeType,session);

@override
String toString() {
  return 'NewSessionState.created(session: $session)';
}


}

/// @nodoc
abstract mixin class $NewSessionCreatedCopyWith<$Res> implements $NewSessionStateCopyWith<$Res> {
  factory $NewSessionCreatedCopyWith(NewSessionCreated value, $Res Function(NewSessionCreated) _then) = _$NewSessionCreatedCopyWithImpl;
@useResult
$Res call({
 Session session
});


$SessionCopyWith<$Res> get session;

}
/// @nodoc
class _$NewSessionCreatedCopyWithImpl<$Res>
    implements $NewSessionCreatedCopyWith<$Res> {
  _$NewSessionCreatedCopyWithImpl(this._self, this._then);

  final NewSessionCreated _self;
  final $Res Function(NewSessionCreated) _then;

/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? session = null,}) {
  return _then(NewSessionCreated(
session: null == session ? _self.session : session // ignore: cast_nullable_to_non_nullable
as Session,
  ));
}

/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionCopyWith<$Res> get session {
  
  return $SessionCopyWith<$Res>(_self.session, (value) {
    return _then(_self.copyWith(session: value));
  });
}
}

// dart format on
