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

 String get id; String get sessionID; String get messageID; String get type;// text / reasoning
 String? get text;// tool
 String? get tool; PluginToolState? get state;// subtask
 String? get prompt; String? get description; String? get agent;
/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginMessagePartCopyWith<PluginMessagePart> get copyWith => _$PluginMessagePartCopyWithImpl<PluginMessagePart>(this as PluginMessagePart, _$identity);

  /// Serializes this PluginMessagePart to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMessagePart&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID)&&(identical(other.type, type) || other.type == type)&&(identical(other.text, text) || other.text == text)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.state, state) || other.state == state)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.description, description) || other.description == description)&&(identical(other.agent, agent) || other.agent == agent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID,type,text,tool,state,prompt,description,agent);

@override
String toString() {
  return 'PluginMessagePart(id: $id, sessionID: $sessionID, messageID: $messageID, type: $type, text: $text, tool: $tool, state: $state, prompt: $prompt, description: $description, agent: $agent)';
}


}

/// @nodoc
abstract mixin class $PluginMessagePartCopyWith<$Res>  {
  factory $PluginMessagePartCopyWith(PluginMessagePart value, $Res Function(PluginMessagePart) _then) = _$PluginMessagePartCopyWithImpl;
@useResult
$Res call({
 String id, String sessionID, String messageID, String type, String? text, String? tool, PluginToolState? state, String? prompt, String? description, String? agent
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,Object? type = null,Object? text = freezed,Object? tool = freezed,Object? state = freezed,Object? prompt = freezed,Object? description = freezed,Object? agent = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,tool: freezed == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as String?,state: freezed == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as PluginToolState?,prompt: freezed == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
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
  const _PluginMessagePart({required this.id, required this.sessionID, required this.messageID, required this.type, required this.text, required this.tool, required this.state, required this.prompt, required this.description, required this.agent});
  

@override final  String id;
@override final  String sessionID;
@override final  String messageID;
@override final  String type;
// text / reasoning
@override final  String? text;
// tool
@override final  String? tool;
@override final  PluginToolState? state;
// subtask
@override final  String? prompt;
@override final  String? description;
@override final  String? agent;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginMessagePart&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID)&&(identical(other.type, type) || other.type == type)&&(identical(other.text, text) || other.text == text)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.state, state) || other.state == state)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.description, description) || other.description == description)&&(identical(other.agent, agent) || other.agent == agent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID,type,text,tool,state,prompt,description,agent);

@override
String toString() {
  return 'PluginMessagePart(id: $id, sessionID: $sessionID, messageID: $messageID, type: $type, text: $text, tool: $tool, state: $state, prompt: $prompt, description: $description, agent: $agent)';
}


}

/// @nodoc
abstract mixin class _$PluginMessagePartCopyWith<$Res> implements $PluginMessagePartCopyWith<$Res> {
  factory _$PluginMessagePartCopyWith(_PluginMessagePart value, $Res Function(_PluginMessagePart) _then) = __$PluginMessagePartCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String messageID, String type, String? text, String? tool, PluginToolState? state, String? prompt, String? description, String? agent
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,Object? type = null,Object? text = freezed,Object? tool = freezed,Object? state = freezed,Object? prompt = freezed,Object? description = freezed,Object? agent = freezed,}) {
  return _then(_PluginMessagePart(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,tool: freezed == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as String?,state: freezed == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as PluginToolState?,prompt: freezed == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
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

 String get status; String? get title; String? get output; String? get error;
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
 String status, String? title, String? output, String? error
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
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
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
  

@override final  String status;
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
 String status, String? title, String? output, String? error
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
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,output: freezed == output ? _self.output : output // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$PluginMessage {

 String get role; String get id; String get sessionID; String? get agent; String? get modelID; String? get providerID;
/// Create a copy of PluginMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginMessageCopyWith<PluginMessage> get copyWith => _$PluginMessageCopyWithImpl<PluginMessage>(this as PluginMessage, _$identity);

  /// Serializes this PluginMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMessage&&(identical(other.role, role) || other.role == role)&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.modelID, modelID) || other.modelID == modelID)&&(identical(other.providerID, providerID) || other.providerID == providerID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,role,id,sessionID,agent,modelID,providerID);

@override
String toString() {
  return 'PluginMessage(role: $role, id: $id, sessionID: $sessionID, agent: $agent, modelID: $modelID, providerID: $providerID)';
}


}

/// @nodoc
abstract mixin class $PluginMessageCopyWith<$Res>  {
  factory $PluginMessageCopyWith(PluginMessage value, $Res Function(PluginMessage) _then) = _$PluginMessageCopyWithImpl;
@useResult
$Res call({
 String role, String id, String sessionID, String? agent, String? modelID, String? providerID
});




}
/// @nodoc
class _$PluginMessageCopyWithImpl<$Res>
    implements $PluginMessageCopyWith<$Res> {
  _$PluginMessageCopyWithImpl(this._self, this._then);

  final PluginMessage _self;
  final $Res Function(PluginMessage) _then;

/// Create a copy of PluginMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? role = null,Object? id = null,Object? sessionID = null,Object? agent = freezed,Object? modelID = freezed,Object? providerID = freezed,}) {
  return _then(_self.copyWith(
role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,modelID: freezed == modelID ? _self.modelID : modelID // ignore: cast_nullable_to_non_nullable
as String?,providerID: freezed == providerID ? _self.providerID : providerID // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createFactory: false)

class _PluginMessage implements PluginMessage {
  const _PluginMessage({required this.role, required this.id, required this.sessionID, required this.agent, required this.modelID, required this.providerID});
  

@override final  String role;
@override final  String id;
@override final  String sessionID;
@override final  String? agent;
@override final  String? modelID;
@override final  String? providerID;

/// Create a copy of PluginMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginMessageCopyWith<_PluginMessage> get copyWith => __$PluginMessageCopyWithImpl<_PluginMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginMessage&&(identical(other.role, role) || other.role == role)&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.modelID, modelID) || other.modelID == modelID)&&(identical(other.providerID, providerID) || other.providerID == providerID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,role,id,sessionID,agent,modelID,providerID);

@override
String toString() {
  return 'PluginMessage(role: $role, id: $id, sessionID: $sessionID, agent: $agent, modelID: $modelID, providerID: $providerID)';
}


}

/// @nodoc
abstract mixin class _$PluginMessageCopyWith<$Res> implements $PluginMessageCopyWith<$Res> {
  factory _$PluginMessageCopyWith(_PluginMessage value, $Res Function(_PluginMessage) _then) = __$PluginMessageCopyWithImpl;
@override @useResult
$Res call({
 String role, String id, String sessionID, String? agent, String? modelID, String? providerID
});




}
/// @nodoc
class __$PluginMessageCopyWithImpl<$Res>
    implements _$PluginMessageCopyWith<$Res> {
  __$PluginMessageCopyWithImpl(this._self, this._then);

  final _PluginMessage _self;
  final $Res Function(_PluginMessage) _then;

/// Create a copy of PluginMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? role = null,Object? id = null,Object? sessionID = null,Object? agent = freezed,Object? modelID = freezed,Object? providerID = freezed,}) {
  return _then(_PluginMessage(
role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,modelID: freezed == modelID ? _self.modelID : modelID // ignore: cast_nullable_to_non_nullable
as String?,providerID: freezed == providerID ? _self.providerID : providerID // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
