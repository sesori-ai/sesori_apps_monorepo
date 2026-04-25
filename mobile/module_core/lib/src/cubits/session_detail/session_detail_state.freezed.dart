// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_detail_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SessionDetailState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionDetailState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SessionDetailState()';
}


}

/// @nodoc
class $SessionDetailStateCopyWith<$Res>  {
$SessionDetailStateCopyWith(SessionDetailState _, $Res Function(SessionDetailState) __);
}



/// @nodoc


class SessionDetailLoading implements SessionDetailState {
  const SessionDetailLoading();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionDetailLoading);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SessionDetailState.loading()';
}


}




/// @nodoc


class SessionDetailLoaded implements SessionDetailState {
  const SessionDetailLoaded({required final  List<MessageWithParts> messages, required final  Map<String, String> streamingText, required this.sessionStatus, required final  List<SesoriQuestionAsked> pendingQuestions, required final  List<SesoriPermissionAsked> pendingPermissions, required this.sessionTitle, required this.agent, required this.assistantAgentModel, required final  List<Session> children, required final  Map<String, SessionStatus> childStatuses, required final  List<QueuedSessionSubmission> queuedMessages, required final  List<AgentInfo> availableAgents, required final  List<ProviderInfo> availableProviders, required final  List<CommandInfo> availableCommands, required this.selectedAgent, required this.selectedAgentModel, required this.stagedCommand, required this.isRefreshing}): _messages = messages,_streamingText = streamingText,_pendingQuestions = pendingQuestions,_pendingPermissions = pendingPermissions,_children = children,_childStatuses = childStatuses,_queuedMessages = queuedMessages,_availableAgents = availableAgents,_availableProviders = availableProviders,_availableCommands = availableCommands;
  

 final  List<MessageWithParts> _messages;
 List<MessageWithParts> get messages {
  if (_messages is EqualUnmodifiableListView) return _messages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_messages);
}

 final  Map<String, String> _streamingText;
 Map<String, String> get streamingText {
  if (_streamingText is EqualUnmodifiableMapView) return _streamingText;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_streamingText);
}

 final  SessionStatus sessionStatus;
 final  List<SesoriQuestionAsked> _pendingQuestions;
 List<SesoriQuestionAsked> get pendingQuestions {
  if (_pendingQuestions is EqualUnmodifiableListView) return _pendingQuestions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pendingQuestions);
}

 final  List<SesoriPermissionAsked> _pendingPermissions;
 List<SesoriPermissionAsked> get pendingPermissions {
  if (_pendingPermissions is EqualUnmodifiableListView) return _pendingPermissions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pendingPermissions);
}

// Session title — updated reactively via SSE `session.updated` events.
 final  String? sessionTitle;
// Agent/model from the latest assistant message.
 final  String? agent;
 final  AgentModel? assistantAgentModel;
// Background tasks (child sessions).
 final  List<Session> _children;
// Background tasks (child sessions).
 List<Session> get children {
  if (_children is EqualUnmodifiableListView) return _children;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_children);
}

 final  Map<String, SessionStatus> _childStatuses;
 Map<String, SessionStatus> get childStatuses {
  if (_childStatuses is EqualUnmodifiableMapView) return _childStatuses;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_childStatuses);
}

// Queued messages (waiting to be sent when connection is restored).
 final  List<QueuedSessionSubmission> _queuedMessages;
// Queued messages (waiting to be sent when connection is restored).
 List<QueuedSessionSubmission> get queuedMessages {
  if (_queuedMessages is EqualUnmodifiableListView) return _queuedMessages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_queuedMessages);
}

// Available agents and providers for selection.
 final  List<AgentInfo> _availableAgents;
// Available agents and providers for selection.
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

// Currently selected agent and model (pre-populated from defaults, never null once loaded).
 final  String selectedAgent;
 final  AgentModel? selectedAgentModel;
 final  CommandInfo? stagedCommand;
 final  bool isRefreshing;

/// Create a copy of SessionDetailState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionDetailLoadedCopyWith<SessionDetailLoaded> get copyWith => _$SessionDetailLoadedCopyWithImpl<SessionDetailLoaded>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionDetailLoaded&&const DeepCollectionEquality().equals(other._messages, _messages)&&const DeepCollectionEquality().equals(other._streamingText, _streamingText)&&(identical(other.sessionStatus, sessionStatus) || other.sessionStatus == sessionStatus)&&const DeepCollectionEquality().equals(other._pendingQuestions, _pendingQuestions)&&const DeepCollectionEquality().equals(other._pendingPermissions, _pendingPermissions)&&(identical(other.sessionTitle, sessionTitle) || other.sessionTitle == sessionTitle)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.assistantAgentModel, assistantAgentModel) || other.assistantAgentModel == assistantAgentModel)&&const DeepCollectionEquality().equals(other._children, _children)&&const DeepCollectionEquality().equals(other._childStatuses, _childStatuses)&&const DeepCollectionEquality().equals(other._queuedMessages, _queuedMessages)&&const DeepCollectionEquality().equals(other._availableAgents, _availableAgents)&&const DeepCollectionEquality().equals(other._availableProviders, _availableProviders)&&const DeepCollectionEquality().equals(other._availableCommands, _availableCommands)&&(identical(other.selectedAgent, selectedAgent) || other.selectedAgent == selectedAgent)&&(identical(other.selectedAgentModel, selectedAgentModel) || other.selectedAgentModel == selectedAgentModel)&&(identical(other.stagedCommand, stagedCommand) || other.stagedCommand == stagedCommand)&&(identical(other.isRefreshing, isRefreshing) || other.isRefreshing == isRefreshing));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_messages),const DeepCollectionEquality().hash(_streamingText),sessionStatus,const DeepCollectionEquality().hash(_pendingQuestions),const DeepCollectionEquality().hash(_pendingPermissions),sessionTitle,agent,assistantAgentModel,const DeepCollectionEquality().hash(_children),const DeepCollectionEquality().hash(_childStatuses),const DeepCollectionEquality().hash(_queuedMessages),const DeepCollectionEquality().hash(_availableAgents),const DeepCollectionEquality().hash(_availableProviders),const DeepCollectionEquality().hash(_availableCommands),selectedAgent,selectedAgentModel,stagedCommand,isRefreshing);

@override
String toString() {
  return 'SessionDetailState.loaded(messages: $messages, streamingText: $streamingText, sessionStatus: $sessionStatus, pendingQuestions: $pendingQuestions, pendingPermissions: $pendingPermissions, sessionTitle: $sessionTitle, agent: $agent, assistantAgentModel: $assistantAgentModel, children: $children, childStatuses: $childStatuses, queuedMessages: $queuedMessages, availableAgents: $availableAgents, availableProviders: $availableProviders, availableCommands: $availableCommands, selectedAgent: $selectedAgent, selectedAgentModel: $selectedAgentModel, stagedCommand: $stagedCommand, isRefreshing: $isRefreshing)';
}


}

/// @nodoc
abstract mixin class $SessionDetailLoadedCopyWith<$Res> implements $SessionDetailStateCopyWith<$Res> {
  factory $SessionDetailLoadedCopyWith(SessionDetailLoaded value, $Res Function(SessionDetailLoaded) _then) = _$SessionDetailLoadedCopyWithImpl;
@useResult
$Res call({
 List<MessageWithParts> messages, Map<String, String> streamingText, SessionStatus sessionStatus, List<SesoriQuestionAsked> pendingQuestions, List<SesoriPermissionAsked> pendingPermissions, String? sessionTitle, String? agent, AgentModel? assistantAgentModel, List<Session> children, Map<String, SessionStatus> childStatuses, List<QueuedSessionSubmission> queuedMessages, List<AgentInfo> availableAgents, List<ProviderInfo> availableProviders, List<CommandInfo> availableCommands, String selectedAgent, AgentModel? selectedAgentModel, CommandInfo? stagedCommand, bool isRefreshing
});


$SessionStatusCopyWith<$Res> get sessionStatus;$AgentModelCopyWith<$Res>? get assistantAgentModel;$AgentModelCopyWith<$Res>? get selectedAgentModel;$CommandInfoCopyWith<$Res>? get stagedCommand;

}
/// @nodoc
class _$SessionDetailLoadedCopyWithImpl<$Res>
    implements $SessionDetailLoadedCopyWith<$Res> {
  _$SessionDetailLoadedCopyWithImpl(this._self, this._then);

  final SessionDetailLoaded _self;
  final $Res Function(SessionDetailLoaded) _then;

/// Create a copy of SessionDetailState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? messages = null,Object? streamingText = null,Object? sessionStatus = null,Object? pendingQuestions = null,Object? pendingPermissions = null,Object? sessionTitle = freezed,Object? agent = freezed,Object? assistantAgentModel = freezed,Object? children = null,Object? childStatuses = null,Object? queuedMessages = null,Object? availableAgents = null,Object? availableProviders = null,Object? availableCommands = null,Object? selectedAgent = null,Object? selectedAgentModel = freezed,Object? stagedCommand = freezed,Object? isRefreshing = null,}) {
  return _then(SessionDetailLoaded(
messages: null == messages ? _self._messages : messages // ignore: cast_nullable_to_non_nullable
as List<MessageWithParts>,streamingText: null == streamingText ? _self._streamingText : streamingText // ignore: cast_nullable_to_non_nullable
as Map<String, String>,sessionStatus: null == sessionStatus ? _self.sessionStatus : sessionStatus // ignore: cast_nullable_to_non_nullable
as SessionStatus,pendingQuestions: null == pendingQuestions ? _self._pendingQuestions : pendingQuestions // ignore: cast_nullable_to_non_nullable
as List<SesoriQuestionAsked>,pendingPermissions: null == pendingPermissions ? _self._pendingPermissions : pendingPermissions // ignore: cast_nullable_to_non_nullable
as List<SesoriPermissionAsked>,sessionTitle: freezed == sessionTitle ? _self.sessionTitle : sessionTitle // ignore: cast_nullable_to_non_nullable
as String?,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,assistantAgentModel: freezed == assistantAgentModel ? _self.assistantAgentModel : assistantAgentModel // ignore: cast_nullable_to_non_nullable
as AgentModel?,children: null == children ? _self._children : children // ignore: cast_nullable_to_non_nullable
as List<Session>,childStatuses: null == childStatuses ? _self._childStatuses : childStatuses // ignore: cast_nullable_to_non_nullable
as Map<String, SessionStatus>,queuedMessages: null == queuedMessages ? _self._queuedMessages : queuedMessages // ignore: cast_nullable_to_non_nullable
as List<QueuedSessionSubmission>,availableAgents: null == availableAgents ? _self._availableAgents : availableAgents // ignore: cast_nullable_to_non_nullable
as List<AgentInfo>,availableProviders: null == availableProviders ? _self._availableProviders : availableProviders // ignore: cast_nullable_to_non_nullable
as List<ProviderInfo>,availableCommands: null == availableCommands ? _self._availableCommands : availableCommands // ignore: cast_nullable_to_non_nullable
as List<CommandInfo>,selectedAgent: null == selectedAgent ? _self.selectedAgent : selectedAgent // ignore: cast_nullable_to_non_nullable
as String,selectedAgentModel: freezed == selectedAgentModel ? _self.selectedAgentModel : selectedAgentModel // ignore: cast_nullable_to_non_nullable
as AgentModel?,stagedCommand: freezed == stagedCommand ? _self.stagedCommand : stagedCommand // ignore: cast_nullable_to_non_nullable
as CommandInfo?,isRefreshing: null == isRefreshing ? _self.isRefreshing : isRefreshing // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of SessionDetailState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionStatusCopyWith<$Res> get sessionStatus {
  
  return $SessionStatusCopyWith<$Res>(_self.sessionStatus, (value) {
    return _then(_self.copyWith(sessionStatus: value));
  });
}/// Create a copy of SessionDetailState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AgentModelCopyWith<$Res>? get assistantAgentModel {
    if (_self.assistantAgentModel == null) {
    return null;
  }

  return $AgentModelCopyWith<$Res>(_self.assistantAgentModel!, (value) {
    return _then(_self.copyWith(assistantAgentModel: value));
  });
}/// Create a copy of SessionDetailState
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
}/// Create a copy of SessionDetailState
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


class SessionDetailFailed implements SessionDetailState {
  const SessionDetailFailed({required this.error});
  

 final  ApiError error;

/// Create a copy of SessionDetailState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionDetailFailedCopyWith<SessionDetailFailed> get copyWith => _$SessionDetailFailedCopyWithImpl<SessionDetailFailed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionDetailFailed&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,error);

@override
String toString() {
  return 'SessionDetailState.failed(error: $error)';
}


}

/// @nodoc
abstract mixin class $SessionDetailFailedCopyWith<$Res> implements $SessionDetailStateCopyWith<$Res> {
  factory $SessionDetailFailedCopyWith(SessionDetailFailed value, $Res Function(SessionDetailFailed) _then) = _$SessionDetailFailedCopyWithImpl;
@useResult
$Res call({
 ApiError error
});


$ApiErrorCopyWith<$Res> get error;

}
/// @nodoc
class _$SessionDetailFailedCopyWithImpl<$Res>
    implements $SessionDetailFailedCopyWith<$Res> {
  _$SessionDetailFailedCopyWithImpl(this._self, this._then);

  final SessionDetailFailed _self;
  final $Res Function(SessionDetailFailed) _then;

/// Create a copy of SessionDetailState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? error = null,}) {
  return _then(SessionDetailFailed(
error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ApiError,
  ));
}

/// Create a copy of SessionDetailState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ApiErrorCopyWith<$Res> get error {
  
  return $ApiErrorCopyWith<$Res>(_self.error, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}

// dart format on
