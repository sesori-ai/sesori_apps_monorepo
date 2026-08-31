// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
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
  return _then(PluginMessageWithParts(
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
  const _PluginMessageWithParts({required this.info, required  List<PluginMessagePart> parts}): _parts = parts;
  

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

 String get id; String get sessionID; String get messageID;
/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginMessagePartCopyWith<PluginMessagePart> get copyWith => _$PluginMessagePartCopyWithImpl<PluginMessagePart>(this as PluginMessagePart, _$identity);

  /// Serializes this PluginMessagePart to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMessagePart&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID);

@override
String toString() {
  return 'PluginMessagePart(id: $id, sessionID: $sessionID, messageID: $messageID)';
}


}

/// @nodoc
abstract mixin class $PluginMessagePartCopyWith<$Res>  {
  factory $PluginMessagePartCopyWith(PluginMessagePart value, $Res Function(PluginMessagePart) _then) = _$PluginMessagePartCopyWithImpl;
@useResult
$Res call({
 String id, String sessionID, String messageID
});




}
/// @nodoc
class _$PluginMessagePartCopyWithImpl<$Res>
    implements $PluginMessagePartCopyWith<$Res> {
  _$PluginMessagePartCopyWithImpl(this._self, this._then);

  final PluginMessagePart _self;
  final $Res Function(PluginMessagePart) _then;

/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable(createFactory: false)

class PluginMessagePartText extends PluginMessagePart {
  const PluginMessagePartText({required this.id, required this.sessionID, required this.messageID, @JsonKey(includeToJson: true) required this.text,  String? $type}): $type = $type ?? 'text',super._();
  

@override final  String id;
@override final  String sessionID;
@override final  String messageID;
@JsonKey(includeToJson: true) final  String text;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginMessagePartTextCopyWith<PluginMessagePartText> get copyWith => _$PluginMessagePartTextCopyWithImpl<PluginMessagePartText>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginMessagePartTextToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMessagePartText&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID)&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID,text);

@override
String toString() {
  return 'PluginMessagePart.text(id: $id, sessionID: $sessionID, messageID: $messageID, text: $text)';
}


}

/// @nodoc
abstract mixin class $PluginMessagePartTextCopyWith<$Res> implements $PluginMessagePartCopyWith<$Res> {
  factory $PluginMessagePartTextCopyWith(PluginMessagePartText value, $Res Function(PluginMessagePartText) _then) = _$PluginMessagePartTextCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String messageID,@JsonKey(includeToJson: true) String text
});




}
/// @nodoc
class _$PluginMessagePartTextCopyWithImpl<$Res>
    implements $PluginMessagePartTextCopyWith<$Res> {
  _$PluginMessagePartTextCopyWithImpl(this._self, this._then);

  final PluginMessagePartText _self;
  final $Res Function(PluginMessagePartText) _then;

/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,Object? text = null,}) {
  return _then(PluginMessagePartText(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createFactory: false)

class PluginMessagePartReasoning extends PluginMessagePart {
  const PluginMessagePartReasoning({required this.id, required this.sessionID, required this.messageID, @JsonKey(includeToJson: true) required this.text,  String? $type}): $type = $type ?? 'reasoning',super._();
  

@override final  String id;
@override final  String sessionID;
@override final  String messageID;
@JsonKey(includeToJson: true) final  String text;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginMessagePartReasoningCopyWith<PluginMessagePartReasoning> get copyWith => _$PluginMessagePartReasoningCopyWithImpl<PluginMessagePartReasoning>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginMessagePartReasoningToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMessagePartReasoning&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID)&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID,text);

@override
String toString() {
  return 'PluginMessagePart.reasoning(id: $id, sessionID: $sessionID, messageID: $messageID, text: $text)';
}


}

/// @nodoc
abstract mixin class $PluginMessagePartReasoningCopyWith<$Res> implements $PluginMessagePartCopyWith<$Res> {
  factory $PluginMessagePartReasoningCopyWith(PluginMessagePartReasoning value, $Res Function(PluginMessagePartReasoning) _then) = _$PluginMessagePartReasoningCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String messageID,@JsonKey(includeToJson: true) String text
});




}
/// @nodoc
class _$PluginMessagePartReasoningCopyWithImpl<$Res>
    implements $PluginMessagePartReasoningCopyWith<$Res> {
  _$PluginMessagePartReasoningCopyWithImpl(this._self, this._then);

  final PluginMessagePartReasoning _self;
  final $Res Function(PluginMessagePartReasoning) _then;

/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,Object? text = null,}) {
  return _then(PluginMessagePartReasoning(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createFactory: false)

class PluginMessagePartTool extends PluginMessagePart {
  const PluginMessagePartTool({required this.id, required this.sessionID, required this.messageID, @JsonKey(includeToJson: true) required this.tool, @JsonKey(includeToJson: true) required this.state,  String? $type}): $type = $type ?? 'tool',super._();
  

@override final  String id;
@override final  String sessionID;
@override final  String messageID;
@JsonKey(includeToJson: true) final  String? tool;
@JsonKey(includeToJson: true) final  PluginToolState state;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginMessagePartToolCopyWith<PluginMessagePartTool> get copyWith => _$PluginMessagePartToolCopyWithImpl<PluginMessagePartTool>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginMessagePartToolToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMessagePartTool&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.state, state) || other.state == state));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID,tool,state);

@override
String toString() {
  return 'PluginMessagePart.tool(id: $id, sessionID: $sessionID, messageID: $messageID, tool: $tool, state: $state)';
}


}

/// @nodoc
abstract mixin class $PluginMessagePartToolCopyWith<$Res> implements $PluginMessagePartCopyWith<$Res> {
  factory $PluginMessagePartToolCopyWith(PluginMessagePartTool value, $Res Function(PluginMessagePartTool) _then) = _$PluginMessagePartToolCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String messageID,@JsonKey(includeToJson: true) String? tool,@JsonKey(includeToJson: true) PluginToolState state
});


$PluginToolStateCopyWith<$Res> get state;

}
/// @nodoc
class _$PluginMessagePartToolCopyWithImpl<$Res>
    implements $PluginMessagePartToolCopyWith<$Res> {
  _$PluginMessagePartToolCopyWithImpl(this._self, this._then);

  final PluginMessagePartTool _self;
  final $Res Function(PluginMessagePartTool) _then;

/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,Object? tool = freezed,Object? state = null,}) {
  return _then(PluginMessagePartTool(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,tool: freezed == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as String?,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as PluginToolState,
  ));
}

/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginToolStateCopyWith<$Res> get state {
  
  return $PluginToolStateCopyWith<$Res>(_self.state, (value) {
    return _then(_self.copyWith(state: value));
  });
}
}

/// @nodoc
@JsonSerializable(createFactory: false)

class PluginMessagePartSubtask extends PluginMessagePart {
  const PluginMessagePartSubtask({required this.id, required this.sessionID, required this.messageID, required this.prompt, required this.description, required this.agent,  String? $type}): $type = $type ?? 'subtask',super._();
  

@override final  String id;
@override final  String sessionID;
@override final  String messageID;
 final  String prompt;
 final  String description;
 final  String agent;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginMessagePartSubtaskCopyWith<PluginMessagePartSubtask> get copyWith => _$PluginMessagePartSubtaskCopyWithImpl<PluginMessagePartSubtask>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginMessagePartSubtaskToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMessagePartSubtask&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.description, description) || other.description == description)&&(identical(other.agent, agent) || other.agent == agent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID,prompt,description,agent);

@override
String toString() {
  return 'PluginMessagePart.subtask(id: $id, sessionID: $sessionID, messageID: $messageID, prompt: $prompt, description: $description, agent: $agent)';
}


}

/// @nodoc
abstract mixin class $PluginMessagePartSubtaskCopyWith<$Res> implements $PluginMessagePartCopyWith<$Res> {
  factory $PluginMessagePartSubtaskCopyWith(PluginMessagePartSubtask value, $Res Function(PluginMessagePartSubtask) _then) = _$PluginMessagePartSubtaskCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String messageID, String prompt, String description, String agent
});




}
/// @nodoc
class _$PluginMessagePartSubtaskCopyWithImpl<$Res>
    implements $PluginMessagePartSubtaskCopyWith<$Res> {
  _$PluginMessagePartSubtaskCopyWithImpl(this._self, this._then);

  final PluginMessagePartSubtask _self;
  final $Res Function(PluginMessagePartSubtask) _then;

/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,Object? prompt = null,Object? description = null,Object? agent = null,}) {
  return _then(PluginMessagePartSubtask(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,agent: null == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createFactory: false)

class PluginMessagePartStepStart extends PluginMessagePart {
  const PluginMessagePartStepStart({required this.id, required this.sessionID, required this.messageID,  String? $type}): $type = $type ?? 'step-start',super._();
  

@override final  String id;
@override final  String sessionID;
@override final  String messageID;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginMessagePartStepStartCopyWith<PluginMessagePartStepStart> get copyWith => _$PluginMessagePartStepStartCopyWithImpl<PluginMessagePartStepStart>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginMessagePartStepStartToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMessagePartStepStart&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID);

@override
String toString() {
  return 'PluginMessagePart.stepStart(id: $id, sessionID: $sessionID, messageID: $messageID)';
}


}

/// @nodoc
abstract mixin class $PluginMessagePartStepStartCopyWith<$Res> implements $PluginMessagePartCopyWith<$Res> {
  factory $PluginMessagePartStepStartCopyWith(PluginMessagePartStepStart value, $Res Function(PluginMessagePartStepStart) _then) = _$PluginMessagePartStepStartCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String messageID
});




}
/// @nodoc
class _$PluginMessagePartStepStartCopyWithImpl<$Res>
    implements $PluginMessagePartStepStartCopyWith<$Res> {
  _$PluginMessagePartStepStartCopyWithImpl(this._self, this._then);

  final PluginMessagePartStepStart _self;
  final $Res Function(PluginMessagePartStepStart) _then;

/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,}) {
  return _then(PluginMessagePartStepStart(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createFactory: false)

class PluginMessagePartStepFinish extends PluginMessagePart {
  const PluginMessagePartStepFinish({required this.id, required this.sessionID, required this.messageID,  String? $type}): $type = $type ?? 'step-finish',super._();
  

@override final  String id;
@override final  String sessionID;
@override final  String messageID;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginMessagePartStepFinishCopyWith<PluginMessagePartStepFinish> get copyWith => _$PluginMessagePartStepFinishCopyWithImpl<PluginMessagePartStepFinish>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginMessagePartStepFinishToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMessagePartStepFinish&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID);

@override
String toString() {
  return 'PluginMessagePart.stepFinish(id: $id, sessionID: $sessionID, messageID: $messageID)';
}


}

/// @nodoc
abstract mixin class $PluginMessagePartStepFinishCopyWith<$Res> implements $PluginMessagePartCopyWith<$Res> {
  factory $PluginMessagePartStepFinishCopyWith(PluginMessagePartStepFinish value, $Res Function(PluginMessagePartStepFinish) _then) = _$PluginMessagePartStepFinishCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String messageID
});




}
/// @nodoc
class _$PluginMessagePartStepFinishCopyWithImpl<$Res>
    implements $PluginMessagePartStepFinishCopyWith<$Res> {
  _$PluginMessagePartStepFinishCopyWithImpl(this._self, this._then);

  final PluginMessagePartStepFinish _self;
  final $Res Function(PluginMessagePartStepFinish) _then;

/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,}) {
  return _then(PluginMessagePartStepFinish(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createFactory: false)

class PluginMessagePartFile extends PluginMessagePart {
  const PluginMessagePartFile({required this.id, required this.sessionID, required this.messageID, @JsonKey(includeToJson: true) required this.attachment,  String? $type}): $type = $type ?? 'file',super._();
  

@override final  String id;
@override final  String sessionID;
@override final  String messageID;
@JsonKey(includeToJson: true) final  PluginMessageAttachment attachment;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginMessagePartFileCopyWith<PluginMessagePartFile> get copyWith => _$PluginMessagePartFileCopyWithImpl<PluginMessagePartFile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginMessagePartFileToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMessagePartFile&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID)&&(identical(other.attachment, attachment) || other.attachment == attachment));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID,attachment);

@override
String toString() {
  return 'PluginMessagePart.file(id: $id, sessionID: $sessionID, messageID: $messageID, attachment: $attachment)';
}


}

/// @nodoc
abstract mixin class $PluginMessagePartFileCopyWith<$Res> implements $PluginMessagePartCopyWith<$Res> {
  factory $PluginMessagePartFileCopyWith(PluginMessagePartFile value, $Res Function(PluginMessagePartFile) _then) = _$PluginMessagePartFileCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String messageID,@JsonKey(includeToJson: true) PluginMessageAttachment attachment
});


$PluginMessageAttachmentCopyWith<$Res> get attachment;

}
/// @nodoc
class _$PluginMessagePartFileCopyWithImpl<$Res>
    implements $PluginMessagePartFileCopyWith<$Res> {
  _$PluginMessagePartFileCopyWithImpl(this._self, this._then);

  final PluginMessagePartFile _self;
  final $Res Function(PluginMessagePartFile) _then;

/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,Object? attachment = null,}) {
  return _then(PluginMessagePartFile(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,attachment: null == attachment ? _self.attachment : attachment // ignore: cast_nullable_to_non_nullable
as PluginMessageAttachment,
  ));
}

/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginMessageAttachmentCopyWith<$Res> get attachment {
  
  return $PluginMessageAttachmentCopyWith<$Res>(_self.attachment, (value) {
    return _then(_self.copyWith(attachment: value));
  });
}
}

/// @nodoc
@JsonSerializable(createFactory: false)

class PluginMessagePartSnapshot extends PluginMessagePart {
  const PluginMessagePartSnapshot({required this.id, required this.sessionID, required this.messageID,  String? $type}): $type = $type ?? 'snapshot',super._();
  

@override final  String id;
@override final  String sessionID;
@override final  String messageID;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginMessagePartSnapshotCopyWith<PluginMessagePartSnapshot> get copyWith => _$PluginMessagePartSnapshotCopyWithImpl<PluginMessagePartSnapshot>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginMessagePartSnapshotToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMessagePartSnapshot&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID);

@override
String toString() {
  return 'PluginMessagePart.snapshot(id: $id, sessionID: $sessionID, messageID: $messageID)';
}


}

/// @nodoc
abstract mixin class $PluginMessagePartSnapshotCopyWith<$Res> implements $PluginMessagePartCopyWith<$Res> {
  factory $PluginMessagePartSnapshotCopyWith(PluginMessagePartSnapshot value, $Res Function(PluginMessagePartSnapshot) _then) = _$PluginMessagePartSnapshotCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String messageID
});




}
/// @nodoc
class _$PluginMessagePartSnapshotCopyWithImpl<$Res>
    implements $PluginMessagePartSnapshotCopyWith<$Res> {
  _$PluginMessagePartSnapshotCopyWithImpl(this._self, this._then);

  final PluginMessagePartSnapshot _self;
  final $Res Function(PluginMessagePartSnapshot) _then;

/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,}) {
  return _then(PluginMessagePartSnapshot(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createFactory: false)

class PluginMessagePartPatch extends PluginMessagePart {
  const PluginMessagePartPatch({required this.id, required this.sessionID, required this.messageID,  String? $type}): $type = $type ?? 'patch',super._();
  

@override final  String id;
@override final  String sessionID;
@override final  String messageID;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginMessagePartPatchCopyWith<PluginMessagePartPatch> get copyWith => _$PluginMessagePartPatchCopyWithImpl<PluginMessagePartPatch>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginMessagePartPatchToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMessagePartPatch&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID);

@override
String toString() {
  return 'PluginMessagePart.patch(id: $id, sessionID: $sessionID, messageID: $messageID)';
}


}

/// @nodoc
abstract mixin class $PluginMessagePartPatchCopyWith<$Res> implements $PluginMessagePartCopyWith<$Res> {
  factory $PluginMessagePartPatchCopyWith(PluginMessagePartPatch value, $Res Function(PluginMessagePartPatch) _then) = _$PluginMessagePartPatchCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String messageID
});




}
/// @nodoc
class _$PluginMessagePartPatchCopyWithImpl<$Res>
    implements $PluginMessagePartPatchCopyWith<$Res> {
  _$PluginMessagePartPatchCopyWithImpl(this._self, this._then);

  final PluginMessagePartPatch _self;
  final $Res Function(PluginMessagePartPatch) _then;

/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,}) {
  return _then(PluginMessagePartPatch(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createFactory: false)

class PluginMessagePartAgent extends PluginMessagePart {
  const PluginMessagePartAgent({required this.id, required this.sessionID, required this.messageID, @JsonKey(includeToJson: true) required this.agentName,  String? $type}): $type = $type ?? 'agent',super._();
  

@override final  String id;
@override final  String sessionID;
@override final  String messageID;
@JsonKey(includeToJson: true) final  String agentName;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginMessagePartAgentCopyWith<PluginMessagePartAgent> get copyWith => _$PluginMessagePartAgentCopyWithImpl<PluginMessagePartAgent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginMessagePartAgentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMessagePartAgent&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID)&&(identical(other.agentName, agentName) || other.agentName == agentName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID,agentName);

@override
String toString() {
  return 'PluginMessagePart.agent(id: $id, sessionID: $sessionID, messageID: $messageID, agentName: $agentName)';
}


}

/// @nodoc
abstract mixin class $PluginMessagePartAgentCopyWith<$Res> implements $PluginMessagePartCopyWith<$Res> {
  factory $PluginMessagePartAgentCopyWith(PluginMessagePartAgent value, $Res Function(PluginMessagePartAgent) _then) = _$PluginMessagePartAgentCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String messageID,@JsonKey(includeToJson: true) String agentName
});




}
/// @nodoc
class _$PluginMessagePartAgentCopyWithImpl<$Res>
    implements $PluginMessagePartAgentCopyWith<$Res> {
  _$PluginMessagePartAgentCopyWithImpl(this._self, this._then);

  final PluginMessagePartAgent _self;
  final $Res Function(PluginMessagePartAgent) _then;

/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,Object? agentName = null,}) {
  return _then(PluginMessagePartAgent(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,agentName: null == agentName ? _self.agentName : agentName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createFactory: false)

class PluginMessagePartRetry extends PluginMessagePart {
  const PluginMessagePartRetry({required this.id, required this.sessionID, required this.messageID, @JsonKey(includeToJson: true) required this.attempt, @JsonKey(includeToJson: true) required this.retryError,  String? $type}): $type = $type ?? 'retry',super._();
  

@override final  String id;
@override final  String sessionID;
@override final  String messageID;
@JsonKey(includeToJson: true) final  int attempt;
@JsonKey(includeToJson: true) final  String retryError;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginMessagePartRetryCopyWith<PluginMessagePartRetry> get copyWith => _$PluginMessagePartRetryCopyWithImpl<PluginMessagePartRetry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginMessagePartRetryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMessagePartRetry&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID)&&(identical(other.attempt, attempt) || other.attempt == attempt)&&(identical(other.retryError, retryError) || other.retryError == retryError));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID,attempt,retryError);

@override
String toString() {
  return 'PluginMessagePart.retry(id: $id, sessionID: $sessionID, messageID: $messageID, attempt: $attempt, retryError: $retryError)';
}


}

/// @nodoc
abstract mixin class $PluginMessagePartRetryCopyWith<$Res> implements $PluginMessagePartCopyWith<$Res> {
  factory $PluginMessagePartRetryCopyWith(PluginMessagePartRetry value, $Res Function(PluginMessagePartRetry) _then) = _$PluginMessagePartRetryCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String messageID,@JsonKey(includeToJson: true) int attempt,@JsonKey(includeToJson: true) String retryError
});




}
/// @nodoc
class _$PluginMessagePartRetryCopyWithImpl<$Res>
    implements $PluginMessagePartRetryCopyWith<$Res> {
  _$PluginMessagePartRetryCopyWithImpl(this._self, this._then);

  final PluginMessagePartRetry _self;
  final $Res Function(PluginMessagePartRetry) _then;

/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,Object? attempt = null,Object? retryError = null,}) {
  return _then(PluginMessagePartRetry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,attempt: null == attempt ? _self.attempt : attempt // ignore: cast_nullable_to_non_nullable
as int,retryError: null == retryError ? _self.retryError : retryError // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createFactory: false)

class PluginMessagePartCompaction extends PluginMessagePart {
  const PluginMessagePartCompaction({required this.id, required this.sessionID, required this.messageID,  String? $type}): $type = $type ?? 'compaction',super._();
  

@override final  String id;
@override final  String sessionID;
@override final  String messageID;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginMessagePartCompactionCopyWith<PluginMessagePartCompaction> get copyWith => _$PluginMessagePartCompactionCopyWithImpl<PluginMessagePartCompaction>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginMessagePartCompactionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMessagePartCompaction&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID);

@override
String toString() {
  return 'PluginMessagePart.compaction(id: $id, sessionID: $sessionID, messageID: $messageID)';
}


}

/// @nodoc
abstract mixin class $PluginMessagePartCompactionCopyWith<$Res> implements $PluginMessagePartCopyWith<$Res> {
  factory $PluginMessagePartCompactionCopyWith(PluginMessagePartCompaction value, $Res Function(PluginMessagePartCompaction) _then) = _$PluginMessagePartCompactionCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String messageID
});




}
/// @nodoc
class _$PluginMessagePartCompactionCopyWithImpl<$Res>
    implements $PluginMessagePartCompactionCopyWith<$Res> {
  _$PluginMessagePartCompactionCopyWithImpl(this._self, this._then);

  final PluginMessagePartCompaction _self;
  final $Res Function(PluginMessagePartCompaction) _then;

/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,}) {
  return _then(PluginMessagePartCompaction(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createFactory: false)

class PluginMessagePartUnknown extends PluginMessagePart {
  const PluginMessagePartUnknown({required this.id, required this.sessionID, required this.messageID,  String? $type}): $type = $type ?? 'unknown',super._();
  

@override final  String id;
@override final  String sessionID;
@override final  String messageID;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginMessagePartUnknownCopyWith<PluginMessagePartUnknown> get copyWith => _$PluginMessagePartUnknownCopyWithImpl<PluginMessagePartUnknown>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginMessagePartUnknownToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMessagePartUnknown&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID);

@override
String toString() {
  return 'PluginMessagePart.unknown(id: $id, sessionID: $sessionID, messageID: $messageID)';
}


}

/// @nodoc
abstract mixin class $PluginMessagePartUnknownCopyWith<$Res> implements $PluginMessagePartCopyWith<$Res> {
  factory $PluginMessagePartUnknownCopyWith(PluginMessagePartUnknown value, $Res Function(PluginMessagePartUnknown) _then) = _$PluginMessagePartUnknownCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String messageID
});




}
/// @nodoc
class _$PluginMessagePartUnknownCopyWithImpl<$Res>
    implements $PluginMessagePartUnknownCopyWith<$Res> {
  _$PluginMessagePartUnknownCopyWithImpl(this._self, this._then);

  final PluginMessagePartUnknown _self;
  final $Res Function(PluginMessagePartUnknown) _then;

/// Create a copy of PluginMessagePart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,}) {
  return _then(PluginMessagePartUnknown(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$PluginMessageAttachment {

 String get mime; String? get filename;
/// Create a copy of PluginMessageAttachment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginMessageAttachmentCopyWith<PluginMessageAttachment> get copyWith => _$PluginMessageAttachmentCopyWithImpl<PluginMessageAttachment>(this as PluginMessageAttachment, _$identity);

  /// Serializes this PluginMessageAttachment to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMessageAttachment&&(identical(other.mime, mime) || other.mime == mime)&&(identical(other.filename, filename) || other.filename == filename));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,mime,filename);



}

/// @nodoc
abstract mixin class $PluginMessageAttachmentCopyWith<$Res>  {
  factory $PluginMessageAttachmentCopyWith(PluginMessageAttachment value, $Res Function(PluginMessageAttachment) _then) = _$PluginMessageAttachmentCopyWithImpl;
@useResult
$Res call({
 String mime, String? filename
});




}
/// @nodoc
class _$PluginMessageAttachmentCopyWithImpl<$Res>
    implements $PluginMessageAttachmentCopyWith<$Res> {
  _$PluginMessageAttachmentCopyWithImpl(this._self, this._then);

  final PluginMessageAttachment _self;
  final $Res Function(PluginMessageAttachment) _then;

/// Create a copy of PluginMessageAttachment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? mime = null,Object? filename = freezed,}) {
  return _then(_self.copyWith(
mime: null == mime ? _self.mime : mime // ignore: cast_nullable_to_non_nullable
as String,filename: freezed == filename ? _self.filename : filename // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createFactory: false)

class PluginMessageAttachmentInlineImage implements PluginMessageAttachment {
  const PluginMessageAttachmentInlineImage({required this.mime, required this.base64, required this.filename,  String? $type}): $type = $type ?? 'inline_image';
  

@override final  String mime;
 final  String base64;
@override final  String? filename;

@JsonKey(name: 'source')
final String $type;


/// Create a copy of PluginMessageAttachment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginMessageAttachmentInlineImageCopyWith<PluginMessageAttachmentInlineImage> get copyWith => _$PluginMessageAttachmentInlineImageCopyWithImpl<PluginMessageAttachmentInlineImage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginMessageAttachmentInlineImageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMessageAttachmentInlineImage&&(identical(other.mime, mime) || other.mime == mime)&&(identical(other.base64, base64) || other.base64 == base64)&&(identical(other.filename, filename) || other.filename == filename));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,mime,base64,filename);



}

/// @nodoc
abstract mixin class $PluginMessageAttachmentInlineImageCopyWith<$Res> implements $PluginMessageAttachmentCopyWith<$Res> {
  factory $PluginMessageAttachmentInlineImageCopyWith(PluginMessageAttachmentInlineImage value, $Res Function(PluginMessageAttachmentInlineImage) _then) = _$PluginMessageAttachmentInlineImageCopyWithImpl;
@override @useResult
$Res call({
 String mime, String base64, String? filename
});




}
/// @nodoc
class _$PluginMessageAttachmentInlineImageCopyWithImpl<$Res>
    implements $PluginMessageAttachmentInlineImageCopyWith<$Res> {
  _$PluginMessageAttachmentInlineImageCopyWithImpl(this._self, this._then);

  final PluginMessageAttachmentInlineImage _self;
  final $Res Function(PluginMessageAttachmentInlineImage) _then;

/// Create a copy of PluginMessageAttachment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mime = null,Object? base64 = null,Object? filename = freezed,}) {
  return _then(PluginMessageAttachmentInlineImage(
mime: null == mime ? _self.mime : mime // ignore: cast_nullable_to_non_nullable
as String,base64: null == base64 ? _self.base64 : base64 // ignore: cast_nullable_to_non_nullable
as String,filename: freezed == filename ? _self.filename : filename // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable(createFactory: false)

class PluginMessageAttachmentRemoteUrl implements PluginMessageAttachment {
  const PluginMessageAttachmentRemoteUrl({required this.mime, required this.url, required this.filename,  String? $type}): $type = $type ?? 'remote_url';
  

@override final  String mime;
 final  Uri url;
@override final  String? filename;

@JsonKey(name: 'source')
final String $type;


/// Create a copy of PluginMessageAttachment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginMessageAttachmentRemoteUrlCopyWith<PluginMessageAttachmentRemoteUrl> get copyWith => _$PluginMessageAttachmentRemoteUrlCopyWithImpl<PluginMessageAttachmentRemoteUrl>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginMessageAttachmentRemoteUrlToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMessageAttachmentRemoteUrl&&(identical(other.mime, mime) || other.mime == mime)&&(identical(other.url, url) || other.url == url)&&(identical(other.filename, filename) || other.filename == filename));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,mime,url,filename);



}

/// @nodoc
abstract mixin class $PluginMessageAttachmentRemoteUrlCopyWith<$Res> implements $PluginMessageAttachmentCopyWith<$Res> {
  factory $PluginMessageAttachmentRemoteUrlCopyWith(PluginMessageAttachmentRemoteUrl value, $Res Function(PluginMessageAttachmentRemoteUrl) _then) = _$PluginMessageAttachmentRemoteUrlCopyWithImpl;
@override @useResult
$Res call({
 String mime, Uri url, String? filename
});




}
/// @nodoc
class _$PluginMessageAttachmentRemoteUrlCopyWithImpl<$Res>
    implements $PluginMessageAttachmentRemoteUrlCopyWith<$Res> {
  _$PluginMessageAttachmentRemoteUrlCopyWithImpl(this._self, this._then);

  final PluginMessageAttachmentRemoteUrl _self;
  final $Res Function(PluginMessageAttachmentRemoteUrl) _then;

/// Create a copy of PluginMessageAttachment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mime = null,Object? url = null,Object? filename = freezed,}) {
  return _then(PluginMessageAttachmentRemoteUrl(
mime: null == mime ? _self.mime : mime // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as Uri,filename: freezed == filename ? _self.filename : filename // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable(createFactory: false)

class PluginMessageAttachmentMetadata implements PluginMessageAttachment {
  const PluginMessageAttachmentMetadata({required this.mime, required this.filename,  String? $type}): $type = $type ?? 'metadata';
  

@override final  String mime;
@override final  String? filename;

@JsonKey(name: 'source')
final String $type;


/// Create a copy of PluginMessageAttachment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginMessageAttachmentMetadataCopyWith<PluginMessageAttachmentMetadata> get copyWith => _$PluginMessageAttachmentMetadataCopyWithImpl<PluginMessageAttachmentMetadata>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginMessageAttachmentMetadataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMessageAttachmentMetadata&&(identical(other.mime, mime) || other.mime == mime)&&(identical(other.filename, filename) || other.filename == filename));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,mime,filename);



}

/// @nodoc
abstract mixin class $PluginMessageAttachmentMetadataCopyWith<$Res> implements $PluginMessageAttachmentCopyWith<$Res> {
  factory $PluginMessageAttachmentMetadataCopyWith(PluginMessageAttachmentMetadata value, $Res Function(PluginMessageAttachmentMetadata) _then) = _$PluginMessageAttachmentMetadataCopyWithImpl;
@override @useResult
$Res call({
 String mime, String? filename
});




}
/// @nodoc
class _$PluginMessageAttachmentMetadataCopyWithImpl<$Res>
    implements $PluginMessageAttachmentMetadataCopyWith<$Res> {
  _$PluginMessageAttachmentMetadataCopyWithImpl(this._self, this._then);

  final PluginMessageAttachmentMetadata _self;
  final $Res Function(PluginMessageAttachmentMetadata) _then;

/// Create a copy of PluginMessageAttachment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mime = null,Object? filename = freezed,}) {
  return _then(PluginMessageAttachmentMetadata(
mime: null == mime ? _self.mime : mime // ignore: cast_nullable_to_non_nullable
as String,filename: freezed == filename ? _self.filename : filename // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$PluginToolState {

 PluginToolStatus get status; String? get title; String? get output; String? get error; List<PluginMessageAttachment> get attachments;
/// Create a copy of PluginToolState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginToolStateCopyWith<PluginToolState> get copyWith => _$PluginToolStateCopyWithImpl<PluginToolState>(this as PluginToolState, _$identity);

  /// Serializes this PluginToolState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginToolState&&(identical(other.status, status) || other.status == status)&&(identical(other.title, title) || other.title == title)&&(identical(other.output, output) || other.output == output)&&(identical(other.error, error) || other.error == error)&&const DeepCollectionEquality().equals(other.attachments, attachments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,title,output,error,const DeepCollectionEquality().hash(attachments));

@override
String toString() {
  return 'PluginToolState(status: $status, title: $title, output: $output, error: $error, attachments: $attachments)';
}


}

/// @nodoc
abstract mixin class $PluginToolStateCopyWith<$Res>  {
  factory $PluginToolStateCopyWith(PluginToolState value, $Res Function(PluginToolState) _then) = _$PluginToolStateCopyWithImpl;
@useResult
$Res call({
 PluginToolStatus status, String? title, String? output, String? error, List<PluginMessageAttachment> attachments
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
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? title = freezed,Object? output = freezed,Object? error = freezed,Object? attachments = null,}) {
  return _then(PluginToolState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PluginToolStatus,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,output: freezed == output ? _self.output : output // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,attachments: null == attachments ? _self.attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<PluginMessageAttachment>,
  ));
}

}



/// @nodoc
@JsonSerializable(createFactory: false)

class _PluginToolState implements PluginToolState {
  const _PluginToolState({required this.status, required this.title, required this.output, required this.error, required  List<PluginMessageAttachment> attachments}): _attachments = attachments;
  

@override final  PluginToolStatus status;
@override final  String? title;
@override final  String? output;
@override final  String? error;
 final  List<PluginMessageAttachment> _attachments;
@override List<PluginMessageAttachment> get attachments {
  if (_attachments is EqualUnmodifiableListView) return _attachments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_attachments);
}


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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginToolState&&(identical(other.status, status) || other.status == status)&&(identical(other.title, title) || other.title == title)&&(identical(other.output, output) || other.output == output)&&(identical(other.error, error) || other.error == error)&&const DeepCollectionEquality().equals(other._attachments, _attachments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,title,output,error,const DeepCollectionEquality().hash(_attachments));

@override
String toString() {
  return 'PluginToolState(status: $status, title: $title, output: $output, error: $error, attachments: $attachments)';
}


}

/// @nodoc
abstract mixin class _$PluginToolStateCopyWith<$Res> implements $PluginToolStateCopyWith<$Res> {
  factory _$PluginToolStateCopyWith(_PluginToolState value, $Res Function(_PluginToolState) _then) = __$PluginToolStateCopyWithImpl;
@override @useResult
$Res call({
 PluginToolStatus status, String? title, String? output, String? error, List<PluginMessageAttachment> attachments
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
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? title = freezed,Object? output = freezed,Object? error = freezed,Object? attachments = null,}) {
  return _then(_PluginToolState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PluginToolStatus,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,output: freezed == output ? _self.output : output // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,attachments: null == attachments ? _self._attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<PluginMessageAttachment>,
  ));
}


}

/// @nodoc
mixin _$PluginMessage {

 String get id; String get sessionID; String? get agent; PluginMessageTime? get time;
/// Create a copy of PluginMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginMessageCopyWith<PluginMessage> get copyWith => _$PluginMessageCopyWithImpl<PluginMessage>(this as PluginMessage, _$identity);

  /// Serializes this PluginMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.time, time) || other.time == time));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,agent,time);

@override
String toString() {
  return 'PluginMessage(id: $id, sessionID: $sessionID, agent: $agent, time: $time)';
}


}

/// @nodoc
abstract mixin class $PluginMessageCopyWith<$Res>  {
  factory $PluginMessageCopyWith(PluginMessage value, $Res Function(PluginMessage) _then) = _$PluginMessageCopyWithImpl;
@useResult
$Res call({
 String id, String sessionID, String? agent, PluginMessageTime? time
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sessionID = null,Object? agent = freezed,Object? time = freezed,}) {
  return _then(_self.copyWith(
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
@JsonSerializable(createFactory: false)

class PluginMessageUser implements PluginMessage {
  const PluginMessageUser({required this.id, required this.sessionID, required this.agent, required this.time, required this.promptId,  String? $type}): $type = $type ?? 'user';
  

@override final  String id;
@override final  String sessionID;
@override final  String? agent;
@override final  PluginMessageTime? time;
/// The `sendPrompt`/`sendCommand` prompt id this message fulfilled, when
/// known. Attached on the live event that consumes a queued prompt so
/// clients can swap the queued bubble for this message atomically.
/// History reads that cannot reconstruct it carry null.
 final  String? promptId;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMessageUser&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.time, time) || other.time == time)&&(identical(other.promptId, promptId) || other.promptId == promptId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,agent,time,promptId);

@override
String toString() {
  return 'PluginMessage.user(id: $id, sessionID: $sessionID, agent: $agent, time: $time, promptId: $promptId)';
}


}

/// @nodoc
abstract mixin class $PluginMessageUserCopyWith<$Res> implements $PluginMessageCopyWith<$Res> {
  factory $PluginMessageUserCopyWith(PluginMessageUser value, $Res Function(PluginMessageUser) _then) = _$PluginMessageUserCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String? agent, PluginMessageTime? time, String? promptId
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? agent = freezed,Object? time = freezed,Object? promptId = freezed,}) {
  return _then(PluginMessageUser(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as PluginMessageTime?,promptId: freezed == promptId ? _self.promptId : promptId // ignore: cast_nullable_to_non_nullable
as String?,
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
@JsonSerializable(createFactory: false)

class PluginMessageAssistant implements PluginMessage {
  const PluginMessageAssistant({required this.id, required this.sessionID, required this.agent, required this.modelID, required this.providerID, required this.variant, required this.sender, required this.time,  String? $type}): $type = $type ?? 'assistant';
  

@override final  String id;
@override final  String sessionID;
@override final  String? agent;
 final  String? modelID;
 final  String? providerID;
 final  String? variant;
 final  PluginMessageSender sender;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMessageAssistant&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.modelID, modelID) || other.modelID == modelID)&&(identical(other.providerID, providerID) || other.providerID == providerID)&&(identical(other.variant, variant) || other.variant == variant)&&(identical(other.sender, sender) || other.sender == sender)&&(identical(other.time, time) || other.time == time));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,agent,modelID,providerID,variant,sender,time);

@override
String toString() {
  return 'PluginMessage.assistant(id: $id, sessionID: $sessionID, agent: $agent, modelID: $modelID, providerID: $providerID, variant: $variant, sender: $sender, time: $time)';
}


}

/// @nodoc
abstract mixin class $PluginMessageAssistantCopyWith<$Res> implements $PluginMessageCopyWith<$Res> {
  factory $PluginMessageAssistantCopyWith(PluginMessageAssistant value, $Res Function(PluginMessageAssistant) _then) = _$PluginMessageAssistantCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String? agent, String? modelID, String? providerID, String? variant, PluginMessageSender sender, PluginMessageTime? time
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? agent = freezed,Object? modelID = freezed,Object? providerID = freezed,Object? variant = freezed,Object? sender = null,Object? time = freezed,}) {
  return _then(PluginMessageAssistant(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,modelID: freezed == modelID ? _self.modelID : modelID // ignore: cast_nullable_to_non_nullable
as String?,providerID: freezed == providerID ? _self.providerID : providerID // ignore: cast_nullable_to_non_nullable
as String?,variant: freezed == variant ? _self.variant : variant // ignore: cast_nullable_to_non_nullable
as String?,sender: null == sender ? _self.sender : sender // ignore: cast_nullable_to_non_nullable
as PluginMessageSender,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
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
@JsonSerializable(createFactory: false)

class PluginMessageError implements PluginMessage {
  const PluginMessageError({required this.id, required this.sessionID, required this.agent, required this.modelID, required this.providerID, required this.variant, required this.errorName, required this.errorMessage, required this.time,  String? $type}): $type = $type ?? 'error';
  

@override final  String id;
@override final  String sessionID;
@override final  String? agent;
 final  String? modelID;
 final  String? providerID;
 final  String? variant;
 final  String errorName;
/// Backend-provided error text must be preserved verbatim when present.
/// A plugin may synthesize a fallback only when its backend supplied no text.
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMessageError&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.modelID, modelID) || other.modelID == modelID)&&(identical(other.providerID, providerID) || other.providerID == providerID)&&(identical(other.variant, variant) || other.variant == variant)&&(identical(other.errorName, errorName) || other.errorName == errorName)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.time, time) || other.time == time));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,agent,modelID,providerID,variant,errorName,errorMessage,time);

@override
String toString() {
  return 'PluginMessage.error(id: $id, sessionID: $sessionID, agent: $agent, modelID: $modelID, providerID: $providerID, variant: $variant, errorName: $errorName, errorMessage: $errorMessage, time: $time)';
}


}

/// @nodoc
abstract mixin class $PluginMessageErrorCopyWith<$Res> implements $PluginMessageCopyWith<$Res> {
  factory $PluginMessageErrorCopyWith(PluginMessageError value, $Res Function(PluginMessageError) _then) = _$PluginMessageErrorCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String? agent, String? modelID, String? providerID, String? variant, String errorName, String errorMessage, PluginMessageTime? time
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? agent = freezed,Object? modelID = freezed,Object? providerID = freezed,Object? variant = freezed,Object? errorName = null,Object? errorMessage = null,Object? time = freezed,}) {
  return _then(PluginMessageError(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,modelID: freezed == modelID ? _self.modelID : modelID // ignore: cast_nullable_to_non_nullable
as String?,providerID: freezed == providerID ? _self.providerID : providerID // ignore: cast_nullable_to_non_nullable
as String?,variant: freezed == variant ? _self.variant : variant // ignore: cast_nullable_to_non_nullable
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
  return _then(PluginMessageTime(
created: null == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as int,completed: freezed == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}



/// @nodoc
@JsonSerializable(createFactory: false)

class _PluginMessageTime implements PluginMessageTime {
  const _PluginMessageTime({required this.created, required this.completed});
  

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
