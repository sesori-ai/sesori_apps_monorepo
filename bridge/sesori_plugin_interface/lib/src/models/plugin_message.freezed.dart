// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PluginMessageWithParts {

 PluginMessage get info; List<PluginMessagePart> get parts;
/// Create a copy of PluginMessageWithParts
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginMessageWithPartsCopyWith<PluginMessageWithParts> get copyWith => _$PluginMessageWithPartsCopyWithImpl<PluginMessageWithParts>(this as PluginMessageWithParts, _$identity);

  /// Serializes this PluginMessageWithParts to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMessageWithParts&&(identical(other.info, info) || other.info == info)&&const DeepCollectionEquality().equals(other.parts, parts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,info,const DeepCollectionEquality().hash(parts));

@override
String toString() {
  return 'PluginMessageWithParts(info: $info, parts: $parts)';
}


}

/// @nodoc
abstract mixin class $PluginMessageWithPartsCopyWith<$Res>  {
  factory $PluginMessageWithPartsCopyWith(PluginMessageWithParts value, $Res Function(PluginMessageWithParts) _then) = _$PluginMessageWithPartsCopyWithImpl;
@useResult
$Res call({
 PluginMessage info, List<PluginMessagePart> parts
});


$PluginMessageCopyWith<$Res> get info;

}
/// @nodoc
class _$PluginMessageWithPartsCopyWithImpl<$Res>
    implements $PluginMessageWithPartsCopyWith<$Res> {
  _$PluginMessageWithPartsCopyWithImpl(this._self, this._then);

  final PluginMessageWithParts _self;
  final $Res Function(PluginMessageWithParts) _then;

/// Create a copy of PluginMessageWithParts
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? info = null,Object? parts = null,}) {
  return _then(_self.copyWith(
info: null == info ? _self.info : info // ignore: cast_nullable_to_non_nullable
as PluginMessage,parts: null == parts ? _self.parts : parts // ignore: cast_nullable_to_non_nullable
as List<PluginMessagePart>,
  ));
}
/// Create a copy of PluginMessageWithParts
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginMessageCopyWith<$Res> get info {
  
  return $PluginMessageCopyWith<$Res>(_self.info, (value) {
    return _then(_self.copyWith(info: value));
  });
}
}



/// @nodoc
@JsonSerializable(createFactory: false)

class _PluginMessageWithParts implements PluginMessageWithParts {
  const _PluginMessageWithParts({required this.info, required final  List<PluginMessagePart> parts}): _parts = parts;
  

@override final  PluginMessage info;
 final  List<PluginMessagePart> _parts;
@override List<PluginMessagePart> get parts {
  if (_parts is EqualUnmodifiableListView) return _parts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_parts);
}


/// Create a copy of PluginMessageWithParts
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginMessageWithPartsCopyWith<_PluginMessageWithParts> get copyWith => __$PluginMessageWithPartsCopyWithImpl<_PluginMessageWithParts>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginMessageWithPartsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginMessageWithParts&&(identical(other.info, info) || other.info == info)&&const DeepCollectionEquality().equals(other._parts, _parts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,info,const DeepCollectionEquality().hash(_parts));

@override
String toString() {
  return 'PluginMessageWithParts(info: $info, parts: $parts)';
}


}

/// @nodoc
abstract mixin class _$PluginMessageWithPartsCopyWith<$Res> implements $PluginMessageWithPartsCopyWith<$Res> {
  factory _$PluginMessageWithPartsCopyWith(_PluginMessageWithParts value, $Res Function(_PluginMessageWithParts) _then) = __$PluginMessageWithPartsCopyWithImpl;
@override @useResult
$Res call({
 PluginMessage info, List<PluginMessagePart> parts
});


@override $PluginMessageCopyWith<$Res> get info;

}
/// @nodoc
class __$PluginMessageWithPartsCopyWithImpl<$Res>
    implements _$PluginMessageWithPartsCopyWith<$Res> {
  __$PluginMessageWithPartsCopyWithImpl(this._self, this._then);

  final _PluginMessageWithParts _self;
  final $Res Function(_PluginMessageWithParts) _then;

/// Create a copy of PluginMessageWithParts
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? info = null,Object? parts = null,}) {
  return _then(_PluginMessageWithParts(
info: null == info ? _self.info : info // ignore: cast_nullable_to_non_nullable
as PluginMessage,parts: null == parts ? _self._parts : parts // ignore: cast_nullable_to_non_nullable
as List<PluginMessagePart>,
  ));
}

/// Create a copy of PluginMessageWithParts
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginMessageCopyWith<$Res> get info {
  
  return $PluginMessageCopyWith<$Res>(_self.info, (value) {
    return _then(_self.copyWith(info: value));
  });
}
}

/// @nodoc
mixin _$PluginMessagePart {

 String get id; String get sessionID; String get messageID; PluginMessagePartType get type;// text / reasoning
 String? get text;// tool
 String? get tool; PluginToolState? get state;// subtask
 String? get prompt; String? get description; String? get agent;// agent
 String? get agentName;// retry
 int? get attempt; String? get retryError;
/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginMessagePartCopyWith<PluginMessagePart> get copyWith => _$PluginMessagePartCopyWithImpl<PluginMessagePart>(this as PluginMessagePart, _$identity);

  /// Serializes this PluginMessagePart to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMessagePart&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID)&&(identical(other.type, type) || other.type == type)&&(identical(other.text, text) || other.text == text)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.state, state) || other.state == state)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.description, description) || other.description == description)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.agentName, agentName) || other.agentName == agentName)&&(identical(other.attempt, attempt) || other.attempt == attempt)&&(identical(other.retryError, retryError) || other.retryError == retryError));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID,type,text,tool,state,prompt,description,agent,agentName,attempt,retryError);

@override
String toString() {
  return 'PluginMessagePart(id: $id, sessionID: $sessionID, messageID: $messageID, type: $type, text: $text, tool: $tool, state: $state, prompt: $prompt, description: $description, agent: $agent, agentName: $agentName, attempt: $attempt, retryError: $retryError)';
}


}

/// @nodoc
abstract mixin class $PluginMessagePartCopyWith<$Res>  {
  factory $PluginMessagePartCopyWith(PluginMessagePart value, $Res Function(PluginMessagePart) _then) = _$PluginMessagePartCopyWithImpl;
@useResult
$Res call({
 String id, String sessionID, String messageID, PluginMessagePartType type, String? text, String? tool, PluginToolState? state, String? prompt, String? description, String? agent, String? agentName, int? attempt, String? retryError
});


$PluginToolStateCopyWith<$Res>? get state;

}
/// @nodoc
class _$PluginMessagePartCopyWithImpl<$Res>
    implements $PluginMessagePartCopyWith<$Res> {
  _$PluginMessagePartCopyWithImpl(this._self, this._then);

  final PluginMessagePart _self;
  final $Res Function(PluginMessagePart) _then;

/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,Object? type = null,Object? text = freezed,Object? tool = freezed,Object? state = freezed,Object? prompt = freezed,Object? description = freezed,Object? agent = freezed,Object? agentName = freezed,Object? attempt = freezed,Object? retryError = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as PluginMessagePartType,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,tool: freezed == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as String?,state: freezed == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as PluginToolState?,prompt: freezed == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,agentName: freezed == agentName ? _self.agentName : agentName // ignore: cast_nullable_to_non_nullable
as String?,attempt: freezed == attempt ? _self.attempt : attempt // ignore: cast_nullable_to_non_nullable
as int?,retryError: freezed == retryError ? _self.retryError : retryError // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginToolStateCopyWith<$Res>? get state {
    if (_self.state == null) {
    return null;
  }

  return $PluginToolStateCopyWith<$Res>(_self.state!, (value) {
    return _then(_self.copyWith(state: value));
  });
}
}



/// @nodoc
@JsonSerializable(createFactory: false)

class _PluginMessagePart implements PluginMessagePart {
  const _PluginMessagePart({required this.id, required this.sessionID, required this.messageID, required this.type, required this.text, required this.tool, required this.state, required this.prompt, required this.description, required this.agent, required this.agentName, required this.attempt, required this.retryError});
  

@override final  String id;
@override final  String sessionID;
@override final  String messageID;
@override final  PluginMessagePartType type;
// text / reasoning
@override final  String? text;
// tool
@override final  String? tool;
@override final  PluginToolState? state;
// subtask
@override final  String? prompt;
@override final  String? description;
@override final  String? agent;
// agent
@override final  String? agentName;
// retry
@override final  int? attempt;
@override final  String? retryError;

/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginMessagePartCopyWith<_PluginMessagePart> get copyWith => __$PluginMessagePartCopyWithImpl<_PluginMessagePart>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginMessagePartToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginMessagePart&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID)&&(identical(other.type, type) || other.type == type)&&(identical(other.text, text) || other.text == text)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.state, state) || other.state == state)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.description, description) || other.description == description)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.agentName, agentName) || other.agentName == agentName)&&(identical(other.attempt, attempt) || other.attempt == attempt)&&(identical(other.retryError, retryError) || other.retryError == retryError));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID,type,text,tool,state,prompt,description,agent,agentName,attempt,retryError);

@override
String toString() {
  return 'PluginMessagePart(id: $id, sessionID: $sessionID, messageID: $messageID, type: $type, text: $text, tool: $tool, state: $state, prompt: $prompt, description: $description, agent: $agent, agentName: $agentName, attempt: $attempt, retryError: $retryError)';
}


}

/// @nodoc
abstract mixin class _$PluginMessagePartCopyWith<$Res> implements $PluginMessagePartCopyWith<$Res> {
  factory _$PluginMessagePartCopyWith(_PluginMessagePart value, $Res Function(_PluginMessagePart) _then) = __$PluginMessagePartCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String messageID, PluginMessagePartType type, String? text, String? tool, PluginToolState? state, String? prompt, String? description, String? agent, String? agentName, int? attempt, String? retryError
});


@override $PluginToolStateCopyWith<$Res>? get state;

}
/// @nodoc
class __$PluginMessagePartCopyWithImpl<$Res>
    implements _$PluginMessagePartCopyWith<$Res> {
  __$PluginMessagePartCopyWithImpl(this._self, this._then);

  final _PluginMessagePart _self;
  final $Res Function(_PluginMessagePart) _then;

/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,Object? type = null,Object? text = freezed,Object? tool = freezed,Object? state = freezed,Object? prompt = freezed,Object? description = freezed,Object? agent = freezed,Object? agentName = freezed,Object? attempt = freezed,Object? retryError = freezed,}) {
  return _then(_PluginMessagePart(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as PluginMessagePartType,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,tool: freezed == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as String?,state: freezed == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as PluginToolState?,prompt: freezed == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,agentName: freezed == agentName ? _self.agentName : agentName // ignore: cast_nullable_to_non_nullable
as String?,attempt: freezed == attempt ? _self.attempt : attempt // ignore: cast_nullable_to_non_nullable
as int?,retryError: freezed == retryError ? _self.retryError : retryError // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginToolStateCopyWith<$Res>? get state {
    if (_self.state == null) {
    return null;
  }

  return $PluginToolStateCopyWith<$Res>(_self.state!, (value) {
    return _then(_self.copyWith(state: value));
  });
}
}

/// @nodoc
mixin _$PluginToolState {

 PluginToolStatus get status; String? get title; String? get output; String? get error;
/// Create a copy of PluginToolState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginToolStateCopyWith<PluginToolState> get copyWith => _$PluginToolStateCopyWithImpl<PluginToolState>(this as PluginToolState, _$identity);

  /// Serializes this PluginToolState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginToolState&&(identical(other.status, status) || other.status == status)&&(identical(other.title, title) || other.title == title)&&(identical(other.output, output) || other.output == output)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,title,output,error);

@override
String toString() {
  return 'PluginToolState(status: $status, title: $title, output: $output, error: $error)';
}


}

/// @nodoc
abstract mixin class $PluginToolStateCopyWith<$Res>  {
  factory $PluginToolStateCopyWith(PluginToolState value, $Res Function(PluginToolState) _then) = _$PluginToolStateCopyWithImpl;
@useResult
$Res call({
 PluginToolStatus status, String? title, String? output, String? error
});




}
/// @nodoc
class _$PluginToolStateCopyWithImpl<$Res>
    implements $PluginToolStateCopyWith<$Res> {
  _$PluginToolStateCopyWithImpl(this._self, this._then);

  final PluginToolState _self;
  final $Res Function(PluginToolState) _then;

/// Create a copy of PluginToolState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? title = freezed,Object? output = freezed,Object? error = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PluginToolStatus,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,output: freezed == output ? _self.output : output // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createFactory: false)

class _PluginToolState implements PluginToolState {
  const _PluginToolState({required this.status, required this.title, required this.output, required this.error});
  

@override final  PluginToolStatus status;
@override final  String? title;
@override final  String? output;
@override final  String? error;

/// Create a copy of PluginToolState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginToolStateCopyWith<_PluginToolState> get copyWith => __$PluginToolStateCopyWithImpl<_PluginToolState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginToolStateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginToolState&&(identical(other.status, status) || other.status == status)&&(identical(other.title, title) || other.title == title)&&(identical(other.output, output) || other.output == output)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,title,output,error);

@override
String toString() {
  return 'PluginToolState(status: $status, title: $title, output: $output, error: $error)';
}


}

/// @nodoc
abstract mixin class _$PluginToolStateCopyWith<$Res> implements $PluginToolStateCopyWith<$Res> {
  factory _$PluginToolStateCopyWith(_PluginToolState value, $Res Function(_PluginToolState) _then) = __$PluginToolStateCopyWithImpl;
@override @useResult
$Res call({
 PluginToolStatus status, String? title, String? output, String? error
});




}
/// @nodoc
class __$PluginToolStateCopyWithImpl<$Res>
    implements _$PluginToolStateCopyWith<$Res> {
  __$PluginToolStateCopyWithImpl(this._self, this._then);

  final _PluginToolState _self;
  final $Res Function(_PluginToolState) _then;

/// Create a copy of PluginToolState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? title = freezed,Object? output = freezed,Object? error = freezed,}) {
  return _then(_PluginToolState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PluginToolStatus,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,output: freezed == output ? _self.output : output // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

PluginMessage _$PluginMessageFromJson(
  Map<String, dynamic> json
) {
        switch (json['role']) {
                  case 'user':
          return PluginMessageUser.fromJson(
            json
          );
                case 'command':
          return PluginMessageCommand.fromJson(
            json
          );
                case 'assistant':
          return PluginMessageAssistant.fromJson(
            json
          );
                case 'error':
          return PluginMessageError.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'role',
  'PluginMessage',
  'Invalid union type "${json['role']}"!'
);
        }
      
}

/// @nodoc
mixin _$PluginMessage {

 String get id; String get sessionID; PluginMessageTime? get time;
/// Create a copy of PluginMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginMessageCopyWith<PluginMessage> get copyWith => _$PluginMessageCopyWithImpl<PluginMessage>(this as PluginMessage, _$identity);

  /// Serializes this PluginMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.time, time) || other.time == time));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,time);

@override
String toString() {
  return 'PluginMessage(id: $id, sessionID: $sessionID, time: $time)';
}


}

/// @nodoc
abstract mixin class $PluginMessageCopyWith<$Res>  {
  factory $PluginMessageCopyWith(PluginMessage value, $Res Function(PluginMessage) _then) = _$PluginMessageCopyWithImpl;
@useResult
$Res call({
 String id, String sessionID, PluginMessageTime? time
});


$PluginMessageTimeCopyWith<$Res>? get time;

}
/// @nodoc
class _$PluginMessageCopyWithImpl<$Res>
    implements $PluginMessageCopyWith<$Res> {
  _$PluginMessageCopyWithImpl(this._self, this._then);

  final PluginMessage _self;
  final $Res Function(PluginMessage) _then;

/// Create a copy of PluginMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sessionID = null,Object? time = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as PluginMessageTime?,
  ));
}
/// Create a copy of PluginMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginMessageTimeCopyWith<$Res>? get time {
    if (_self.time == null) {
    return null;
  }

  return $PluginMessageTimeCopyWith<$Res>(_self.time!, (value) {
    return _then(_self.copyWith(time: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class PluginMessageUser implements PluginMessage {
  const PluginMessageUser({required this.id, required this.sessionID, required this.agent, required this.time, final  String? $type}): $type = $type ?? 'user';
  factory PluginMessageUser.fromJson(Map<String, dynamic> json) => _$PluginMessageUserFromJson(json);

@override final  String id;
@override final  String sessionID;
 final  String? agent;
@override final  PluginMessageTime? time;

@JsonKey(name: 'role')
final String $type;


/// Create a copy of PluginMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginMessageUserCopyWith<PluginMessageUser> get copyWith => _$PluginMessageUserCopyWithImpl<PluginMessageUser>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginMessageUserToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMessageUser&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.time, time) || other.time == time));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,agent,time);

@override
String toString() {
  return 'PluginMessage.user(id: $id, sessionID: $sessionID, agent: $agent, time: $time)';
}


}

/// @nodoc
abstract mixin class $PluginMessageUserCopyWith<$Res> implements $PluginMessageCopyWith<$Res> {
  factory $PluginMessageUserCopyWith(PluginMessageUser value, $Res Function(PluginMessageUser) _then) = _$PluginMessageUserCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String? agent, PluginMessageTime? time
});


@override $PluginMessageTimeCopyWith<$Res>? get time;

}
/// @nodoc
class _$PluginMessageUserCopyWithImpl<$Res>
    implements $PluginMessageUserCopyWith<$Res> {
  _$PluginMessageUserCopyWithImpl(this._self, this._then);

  final PluginMessageUser _self;
  final $Res Function(PluginMessageUser) _then;

/// Create a copy of PluginMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? agent = freezed,Object? time = freezed,}) {
  return _then(PluginMessageUser(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as PluginMessageTime?,
  ));
}

/// Create a copy of PluginMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginMessageTimeCopyWith<$Res>? get time {
    if (_self.time == null) {
    return null;
  }

  return $PluginMessageTimeCopyWith<$Res>(_self.time!, (value) {
    return _then(_self.copyWith(time: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class PluginMessageCommand implements PluginMessage {
  const PluginMessageCommand({required this.id, required this.sessionID, required this.name, required this.arguments, @JsonKey(unknownEnumValue: PluginCommandOrigin.unknown) required this.origin, required this.invocationId, required this.time, final  String? $type}): $type = $type ?? 'command';
  factory PluginMessageCommand.fromJson(Map<String, dynamic> json) => _$PluginMessageCommandFromJson(json);

@override final  String id;
@override final  String sessionID;
 final  String name;
 final  String? arguments;
@JsonKey(unknownEnumValue: PluginCommandOrigin.unknown) final  PluginCommandOrigin origin;
 final  String? invocationId;
@override final  PluginMessageTime? time;

@JsonKey(name: 'role')
final String $type;


/// Create a copy of PluginMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginMessageCommandCopyWith<PluginMessageCommand> get copyWith => _$PluginMessageCommandCopyWithImpl<PluginMessageCommand>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginMessageCommandToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMessageCommand&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.name, name) || other.name == name)&&(identical(other.arguments, arguments) || other.arguments == arguments)&&(identical(other.origin, origin) || other.origin == origin)&&(identical(other.invocationId, invocationId) || other.invocationId == invocationId)&&(identical(other.time, time) || other.time == time));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,name,arguments,origin,invocationId,time);

@override
String toString() {
  return 'PluginMessage.command(id: $id, sessionID: $sessionID, name: $name, arguments: $arguments, origin: $origin, invocationId: $invocationId, time: $time)';
}


}

/// @nodoc
abstract mixin class $PluginMessageCommandCopyWith<$Res> implements $PluginMessageCopyWith<$Res> {
  factory $PluginMessageCommandCopyWith(PluginMessageCommand value, $Res Function(PluginMessageCommand) _then) = _$PluginMessageCommandCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String name, String? arguments,@JsonKey(unknownEnumValue: PluginCommandOrigin.unknown) PluginCommandOrigin origin, String? invocationId, PluginMessageTime? time
});


@override $PluginMessageTimeCopyWith<$Res>? get time;

}
/// @nodoc
class _$PluginMessageCommandCopyWithImpl<$Res>
    implements $PluginMessageCommandCopyWith<$Res> {
  _$PluginMessageCommandCopyWithImpl(this._self, this._then);

  final PluginMessageCommand _self;
  final $Res Function(PluginMessageCommand) _then;

/// Create a copy of PluginMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? name = null,Object? arguments = freezed,Object? origin = null,Object? invocationId = freezed,Object? time = freezed,}) {
  return _then(PluginMessageCommand(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,arguments: freezed == arguments ? _self.arguments : arguments // ignore: cast_nullable_to_non_nullable
as String?,origin: null == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as PluginCommandOrigin,invocationId: freezed == invocationId ? _self.invocationId : invocationId // ignore: cast_nullable_to_non_nullable
as String?,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as PluginMessageTime?,
  ));
}

/// Create a copy of PluginMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginMessageTimeCopyWith<$Res>? get time {
    if (_self.time == null) {
    return null;
  }

  return $PluginMessageTimeCopyWith<$Res>(_self.time!, (value) {
    return _then(_self.copyWith(time: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class PluginMessageAssistant implements PluginMessage {
  const PluginMessageAssistant({required this.id, required this.sessionID, required this.agent, required this.modelID, required this.providerID, required this.time, final  String? $type}): $type = $type ?? 'assistant';
  factory PluginMessageAssistant.fromJson(Map<String, dynamic> json) => _$PluginMessageAssistantFromJson(json);

@override final  String id;
@override final  String sessionID;
 final  String? agent;
 final  String? modelID;
 final  String? providerID;
@override final  PluginMessageTime? time;

@JsonKey(name: 'role')
final String $type;


/// Create a copy of PluginMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginMessageAssistantCopyWith<PluginMessageAssistant> get copyWith => _$PluginMessageAssistantCopyWithImpl<PluginMessageAssistant>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginMessageAssistantToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMessageAssistant&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.modelID, modelID) || other.modelID == modelID)&&(identical(other.providerID, providerID) || other.providerID == providerID)&&(identical(other.time, time) || other.time == time));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,agent,modelID,providerID,time);

@override
String toString() {
  return 'PluginMessage.assistant(id: $id, sessionID: $sessionID, agent: $agent, modelID: $modelID, providerID: $providerID, time: $time)';
}


}

/// @nodoc
abstract mixin class $PluginMessageAssistantCopyWith<$Res> implements $PluginMessageCopyWith<$Res> {
  factory $PluginMessageAssistantCopyWith(PluginMessageAssistant value, $Res Function(PluginMessageAssistant) _then) = _$PluginMessageAssistantCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String? agent, String? modelID, String? providerID, PluginMessageTime? time
});


@override $PluginMessageTimeCopyWith<$Res>? get time;

}
/// @nodoc
class _$PluginMessageAssistantCopyWithImpl<$Res>
    implements $PluginMessageAssistantCopyWith<$Res> {
  _$PluginMessageAssistantCopyWithImpl(this._self, this._then);

  final PluginMessageAssistant _self;
  final $Res Function(PluginMessageAssistant) _then;

/// Create a copy of PluginMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? agent = freezed,Object? modelID = freezed,Object? providerID = freezed,Object? time = freezed,}) {
  return _then(PluginMessageAssistant(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,modelID: freezed == modelID ? _self.modelID : modelID // ignore: cast_nullable_to_non_nullable
as String?,providerID: freezed == providerID ? _self.providerID : providerID // ignore: cast_nullable_to_non_nullable
as String?,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as PluginMessageTime?,
  ));
}

/// Create a copy of PluginMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginMessageTimeCopyWith<$Res>? get time {
    if (_self.time == null) {
    return null;
  }

  return $PluginMessageTimeCopyWith<$Res>(_self.time!, (value) {
    return _then(_self.copyWith(time: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class PluginMessageError implements PluginMessage {
  const PluginMessageError({required this.id, required this.sessionID, required this.agent, required this.modelID, required this.providerID, required this.errorName, required this.errorMessage, required this.time, final  String? $type}): $type = $type ?? 'error';
  factory PluginMessageError.fromJson(Map<String, dynamic> json) => _$PluginMessageErrorFromJson(json);

@override final  String id;
@override final  String sessionID;
 final  String? agent;
 final  String? modelID;
 final  String? providerID;
 final  String errorName;
 final  String errorMessage;
@override final  PluginMessageTime? time;

@JsonKey(name: 'role')
final String $type;


/// Create a copy of PluginMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginMessageErrorCopyWith<PluginMessageError> get copyWith => _$PluginMessageErrorCopyWithImpl<PluginMessageError>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginMessageErrorToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMessageError&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.modelID, modelID) || other.modelID == modelID)&&(identical(other.providerID, providerID) || other.providerID == providerID)&&(identical(other.errorName, errorName) || other.errorName == errorName)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.time, time) || other.time == time));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,agent,modelID,providerID,errorName,errorMessage,time);

@override
String toString() {
  return 'PluginMessage.error(id: $id, sessionID: $sessionID, agent: $agent, modelID: $modelID, providerID: $providerID, errorName: $errorName, errorMessage: $errorMessage, time: $time)';
}


}

/// @nodoc
abstract mixin class $PluginMessageErrorCopyWith<$Res> implements $PluginMessageCopyWith<$Res> {
  factory $PluginMessageErrorCopyWith(PluginMessageError value, $Res Function(PluginMessageError) _then) = _$PluginMessageErrorCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String? agent, String? modelID, String? providerID, String errorName, String errorMessage, PluginMessageTime? time
});


@override $PluginMessageTimeCopyWith<$Res>? get time;

}
/// @nodoc
class _$PluginMessageErrorCopyWithImpl<$Res>
    implements $PluginMessageErrorCopyWith<$Res> {
  _$PluginMessageErrorCopyWithImpl(this._self, this._then);

  final PluginMessageError _self;
  final $Res Function(PluginMessageError) _then;

/// Create a copy of PluginMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? agent = freezed,Object? modelID = freezed,Object? providerID = freezed,Object? errorName = null,Object? errorMessage = null,Object? time = freezed,}) {
  return _then(PluginMessageError(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,modelID: freezed == modelID ? _self.modelID : modelID // ignore: cast_nullable_to_non_nullable
as String?,providerID: freezed == providerID ? _self.providerID : providerID // ignore: cast_nullable_to_non_nullable
as String?,errorName: null == errorName ? _self.errorName : errorName // ignore: cast_nullable_to_non_nullable
as String,errorMessage: null == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as PluginMessageTime?,
  ));
}

/// Create a copy of PluginMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginMessageTimeCopyWith<$Res>? get time {
    if (_self.time == null) {
    return null;
  }

  return $PluginMessageTimeCopyWith<$Res>(_self.time!, (value) {
    return _then(_self.copyWith(time: value));
  });
}
}


/// @nodoc
mixin _$PluginMessageTime {

 int get created; int? get completed;
/// Create a copy of PluginMessageTime
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginMessageTimeCopyWith<PluginMessageTime> get copyWith => _$PluginMessageTimeCopyWithImpl<PluginMessageTime>(this as PluginMessageTime, _$identity);

  /// Serializes this PluginMessageTime to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMessageTime&&(identical(other.created, created) || other.created == created)&&(identical(other.completed, completed) || other.completed == completed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,created,completed);

@override
String toString() {
  return 'PluginMessageTime(created: $created, completed: $completed)';
}


}

/// @nodoc
abstract mixin class $PluginMessageTimeCopyWith<$Res>  {
  factory $PluginMessageTimeCopyWith(PluginMessageTime value, $Res Function(PluginMessageTime) _then) = _$PluginMessageTimeCopyWithImpl;
@useResult
$Res call({
 int created, int? completed
});




}
/// @nodoc
class _$PluginMessageTimeCopyWithImpl<$Res>
    implements $PluginMessageTimeCopyWith<$Res> {
  _$PluginMessageTimeCopyWithImpl(this._self, this._then);

  final PluginMessageTime _self;
  final $Res Function(PluginMessageTime) _then;

/// Create a copy of PluginMessageTime
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? created = null,Object? completed = freezed,}) {
  return _then(_self.copyWith(
created: null == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as int,completed: freezed == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _PluginMessageTime implements PluginMessageTime {
  const _PluginMessageTime({required this.created, required this.completed});
  factory _PluginMessageTime.fromJson(Map<String, dynamic> json) => _$PluginMessageTimeFromJson(json);

@override final  int created;
@override final  int? completed;

/// Create a copy of PluginMessageTime
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginMessageTimeCopyWith<_PluginMessageTime> get copyWith => __$PluginMessageTimeCopyWithImpl<_PluginMessageTime>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginMessageTimeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginMessageTime&&(identical(other.created, created) || other.created == created)&&(identical(other.completed, completed) || other.completed == completed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,created,completed);

@override
String toString() {
  return 'PluginMessageTime(created: $created, completed: $completed)';
}


}

/// @nodoc
abstract mixin class _$PluginMessageTimeCopyWith<$Res> implements $PluginMessageTimeCopyWith<$Res> {
  factory _$PluginMessageTimeCopyWith(_PluginMessageTime value, $Res Function(_PluginMessageTime) _then) = __$PluginMessageTimeCopyWithImpl;
@override @useResult
$Res call({
 int created, int? completed
});




}
/// @nodoc
class __$PluginMessageTimeCopyWithImpl<$Res>
    implements _$PluginMessageTimeCopyWith<$Res> {
  __$PluginMessageTimeCopyWithImpl(this._self, this._then);

  final _PluginMessageTime _self;
  final $Res Function(_PluginMessageTime) _then;

/// Create a copy of PluginMessageTime
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? created = null,Object? completed = freezed,}) {
  return _then(_PluginMessageTime(
created: null == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as int,completed: freezed == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
