// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message_part.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
MessagePart _$MessagePartFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'text':
          return MessagePartText.fromJson(
            json
          );
                case 'reasoning':
          return MessagePartReasoning.fromJson(
            json
          );
                case 'tool':
          return MessagePartTool.fromJson(
            json
          );
                case 'subtask':
          return MessagePartSubtask.fromJson(
            json
          );
                case 'step-start':
          return MessagePartStepStart.fromJson(
            json
          );
                case 'step-finish':
          return MessagePartStepFinish.fromJson(
            json
          );
                case 'file':
          return MessagePartFile.fromJson(
            json
          );
                case 'snapshot':
          return MessagePartSnapshot.fromJson(
            json
          );
                case 'patch':
          return MessagePartPatch.fromJson(
            json
          );
                case 'agent':
          return MessagePartAgent.fromJson(
            json
          );
                case 'retry':
          return MessagePartRetry.fromJson(
            json
          );
                case 'compaction':
          return MessagePartCompaction.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'MessagePart',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$MessagePart {

 String get id; String get sessionID; String get messageID;
/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessagePartCopyWith<MessagePart> get copyWith => _$MessagePartCopyWithImpl<MessagePart>(this as MessagePart, _$identity);

  /// Serializes this MessagePart to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MessagePart;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessagePart&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.sessionID, _this.sessionID) || other.sessionID == _this.sessionID)&&(identical(other.messageID, _this.messageID) || other.messageID == _this.messageID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MessagePart;
  return Object.hash(runtimeType,_this.id,_this.sessionID,_this.messageID);
}

@override
String toString() {
  final _this = this as MessagePart;
  return 'MessagePart(id: ${_this.id}, sessionID: ${_this.sessionID}, messageID: ${_this.messageID})';
}


}

/// @nodoc
abstract mixin class $MessagePartCopyWith<$Res>  {
  factory $MessagePartCopyWith(MessagePart value, $Res Function(MessagePart) _then) = _$MessagePartCopyWithImpl;
@useResult
$Res call({
 String id, String sessionID, String messageID
});




}
/// @nodoc
class _$MessagePartCopyWithImpl<$Res>
    implements $MessagePartCopyWith<$Res> {
  _$MessagePartCopyWithImpl(this._self, this._then);

  final MessagePart _self;
  final $Res Function(MessagePart) _then;

/// Create a copy of MessagePart
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
@JsonSerializable()

class MessagePartText extends MessagePart {
  const MessagePartText({required this.id, required this.sessionID, required this.messageID, this.text = "",  String? $type}): $type = $type ?? 'text',super._();
  factory MessagePartText.fromJson(Map<String, dynamic> json) => _$MessagePartTextFromJson(json);

@override final  String id;
@override final  String sessionID;
@override final  String messageID;
@JsonKey() final  String text;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessagePartTextCopyWith<MessagePartText> get copyWith => _$MessagePartTextCopyWithImpl<MessagePartText>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessagePartTextToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is MessagePartText&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID)&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,sessionID,messageID,text);
}

@override
String toString() {
    return 'MessagePart.text(id: $id, sessionID: $sessionID, messageID: $messageID, text: $text)';
}


}

/// @nodoc
abstract mixin class $MessagePartTextCopyWith<$Res> implements $MessagePartCopyWith<$Res> {
  factory $MessagePartTextCopyWith(MessagePartText value, $Res Function(MessagePartText) _then) = _$MessagePartTextCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String messageID, String text
});




}
/// @nodoc
class _$MessagePartTextCopyWithImpl<$Res>
    implements $MessagePartTextCopyWith<$Res> {
  _$MessagePartTextCopyWithImpl(this._self, this._then);

  final MessagePartText _self;
  final $Res Function(MessagePartText) _then;

/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,Object? text = null,}) {
  return _then(MessagePartText(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class MessagePartReasoning extends MessagePart {
  const MessagePartReasoning({required this.id, required this.sessionID, required this.messageID, this.text = "",  String? $type}): $type = $type ?? 'reasoning',super._();
  factory MessagePartReasoning.fromJson(Map<String, dynamic> json) => _$MessagePartReasoningFromJson(json);

@override final  String id;
@override final  String sessionID;
@override final  String messageID;
@JsonKey() final  String text;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessagePartReasoningCopyWith<MessagePartReasoning> get copyWith => _$MessagePartReasoningCopyWithImpl<MessagePartReasoning>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessagePartReasoningToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is MessagePartReasoning&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID)&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,sessionID,messageID,text);
}

@override
String toString() {
    return 'MessagePart.reasoning(id: $id, sessionID: $sessionID, messageID: $messageID, text: $text)';
}


}

/// @nodoc
abstract mixin class $MessagePartReasoningCopyWith<$Res> implements $MessagePartCopyWith<$Res> {
  factory $MessagePartReasoningCopyWith(MessagePartReasoning value, $Res Function(MessagePartReasoning) _then) = _$MessagePartReasoningCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String messageID, String text
});




}
/// @nodoc
class _$MessagePartReasoningCopyWithImpl<$Res>
    implements $MessagePartReasoningCopyWith<$Res> {
  _$MessagePartReasoningCopyWithImpl(this._self, this._then);

  final MessagePartReasoning _self;
  final $Res Function(MessagePartReasoning) _then;

/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,Object? text = null,}) {
  return _then(MessagePartReasoning(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class MessagePartTool extends MessagePart {
  const MessagePartTool({required this.id, required this.sessionID, required this.messageID, this.tool = "", this.state = const ToolState(status: ToolStatus.pending, title: null, shellCommand: null, output: null, error: null),  String? $type}): $type = $type ?? 'tool',super._();
  factory MessagePartTool.fromJson(Map<String, dynamic> json) => _$MessagePartToolFromJson(json);

@override final  String id;
@override final  String sessionID;
@override final  String messageID;
@JsonKey() final  String tool;
@JsonKey() final  ToolState state;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessagePartToolCopyWith<MessagePartTool> get copyWith => _$MessagePartToolCopyWithImpl<MessagePartTool>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessagePartToolToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is MessagePartTool&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.state, state) || other.state == state));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,sessionID,messageID,tool,state);
}

@override
String toString() {
    return 'MessagePart.tool(id: $id, sessionID: $sessionID, messageID: $messageID, tool: $tool, state: $state)';
}


}

/// @nodoc
abstract mixin class $MessagePartToolCopyWith<$Res> implements $MessagePartCopyWith<$Res> {
  factory $MessagePartToolCopyWith(MessagePartTool value, $Res Function(MessagePartTool) _then) = _$MessagePartToolCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String messageID, String tool, ToolState state
});


$ToolStateCopyWith<$Res> get state;

}
/// @nodoc
class _$MessagePartToolCopyWithImpl<$Res>
    implements $MessagePartToolCopyWith<$Res> {
  _$MessagePartToolCopyWithImpl(this._self, this._then);

  final MessagePartTool _self;
  final $Res Function(MessagePartTool) _then;

/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,Object? tool = null,Object? state = null,}) {
  return _then(MessagePartTool(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,tool: null == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as ToolState,
  ));
}

/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ToolStateCopyWith<$Res> get state {
  
  return $ToolStateCopyWith<$Res>(_self.state, (value) {
    return _then(_self.copyWith(state: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class MessagePartSubtask extends MessagePart {
  const MessagePartSubtask({required this.id, required this.sessionID, required this.messageID, this.prompt = "", this.description = "", this.agent = "", required this.taskState, required this.childSessionID,  String? $type}): $type = $type ?? 'subtask',super._();
  factory MessagePartSubtask.fromJson(Map<String, dynamic> json) => _$MessagePartSubtaskFromJson(json);

@override final  String id;
@override final  String sessionID;
@override final  String messageID;
@JsonKey() final  String prompt;
@JsonKey() final  String description;
@JsonKey() final  String agent;
/// The subtask's own lifecycle, authoritative for its inline status. Null
/// when the backend reports none, leaving consumers to infer it.
 final  ToolState? taskState;
/// The session hosting this subtask's work, when the backend exposes one
/// and the bridge could resolve it. Null leaves consumers to their own
/// association, so a part is never withheld for an unresolved reference.
 final  String? childSessionID;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessagePartSubtaskCopyWith<MessagePartSubtask> get copyWith => _$MessagePartSubtaskCopyWithImpl<MessagePartSubtask>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessagePartSubtaskToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is MessagePartSubtask&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.description, description) || other.description == description)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.taskState, taskState) || other.taskState == taskState)&&(identical(other.childSessionID, childSessionID) || other.childSessionID == childSessionID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,sessionID,messageID,prompt,description,agent,taskState,childSessionID);
}

@override
String toString() {
    return 'MessagePart.subtask(id: $id, sessionID: $sessionID, messageID: $messageID, prompt: $prompt, description: $description, agent: $agent, taskState: $taskState, childSessionID: $childSessionID)';
}


}

/// @nodoc
abstract mixin class $MessagePartSubtaskCopyWith<$Res> implements $MessagePartCopyWith<$Res> {
  factory $MessagePartSubtaskCopyWith(MessagePartSubtask value, $Res Function(MessagePartSubtask) _then) = _$MessagePartSubtaskCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String messageID, String prompt, String description, String agent, ToolState? taskState, String? childSessionID
});


$ToolStateCopyWith<$Res>? get taskState;

}
/// @nodoc
class _$MessagePartSubtaskCopyWithImpl<$Res>
    implements $MessagePartSubtaskCopyWith<$Res> {
  _$MessagePartSubtaskCopyWithImpl(this._self, this._then);

  final MessagePartSubtask _self;
  final $Res Function(MessagePartSubtask) _then;

/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,Object? prompt = null,Object? description = null,Object? agent = null,Object? taskState = freezed,Object? childSessionID = freezed,}) {
  return _then(MessagePartSubtask(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,agent: null == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String,taskState: freezed == taskState ? _self.taskState : taskState // ignore: cast_nullable_to_non_nullable
as ToolState?,childSessionID: freezed == childSessionID ? _self.childSessionID : childSessionID // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ToolStateCopyWith<$Res>? get taskState {
    if (_self.taskState == null) {
    return null;
  }

  return $ToolStateCopyWith<$Res>(_self.taskState!, (value) {
    return _then(_self.copyWith(taskState: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class MessagePartStepStart extends MessagePart {
  const MessagePartStepStart({required this.id, required this.sessionID, required this.messageID,  String? $type}): $type = $type ?? 'step-start',super._();
  factory MessagePartStepStart.fromJson(Map<String, dynamic> json) => _$MessagePartStepStartFromJson(json);

@override final  String id;
@override final  String sessionID;
@override final  String messageID;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessagePartStepStartCopyWith<MessagePartStepStart> get copyWith => _$MessagePartStepStartCopyWithImpl<MessagePartStepStart>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessagePartStepStartToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is MessagePartStepStart&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,sessionID,messageID);
}

@override
String toString() {
    return 'MessagePart.stepStart(id: $id, sessionID: $sessionID, messageID: $messageID)';
}


}

/// @nodoc
abstract mixin class $MessagePartStepStartCopyWith<$Res> implements $MessagePartCopyWith<$Res> {
  factory $MessagePartStepStartCopyWith(MessagePartStepStart value, $Res Function(MessagePartStepStart) _then) = _$MessagePartStepStartCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String messageID
});




}
/// @nodoc
class _$MessagePartStepStartCopyWithImpl<$Res>
    implements $MessagePartStepStartCopyWith<$Res> {
  _$MessagePartStepStartCopyWithImpl(this._self, this._then);

  final MessagePartStepStart _self;
  final $Res Function(MessagePartStepStart) _then;

/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,}) {
  return _then(MessagePartStepStart(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class MessagePartStepFinish extends MessagePart {
  const MessagePartStepFinish({required this.id, required this.sessionID, required this.messageID,  String? $type}): $type = $type ?? 'step-finish',super._();
  factory MessagePartStepFinish.fromJson(Map<String, dynamic> json) => _$MessagePartStepFinishFromJson(json);

@override final  String id;
@override final  String sessionID;
@override final  String messageID;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessagePartStepFinishCopyWith<MessagePartStepFinish> get copyWith => _$MessagePartStepFinishCopyWithImpl<MessagePartStepFinish>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessagePartStepFinishToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is MessagePartStepFinish&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,sessionID,messageID);
}

@override
String toString() {
    return 'MessagePart.stepFinish(id: $id, sessionID: $sessionID, messageID: $messageID)';
}


}

/// @nodoc
abstract mixin class $MessagePartStepFinishCopyWith<$Res> implements $MessagePartCopyWith<$Res> {
  factory $MessagePartStepFinishCopyWith(MessagePartStepFinish value, $Res Function(MessagePartStepFinish) _then) = _$MessagePartStepFinishCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String messageID
});




}
/// @nodoc
class _$MessagePartStepFinishCopyWithImpl<$Res>
    implements $MessagePartStepFinishCopyWith<$Res> {
  _$MessagePartStepFinishCopyWithImpl(this._self, this._then);

  final MessagePartStepFinish _self;
  final $Res Function(MessagePartStepFinish) _then;

/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,}) {
  return _then(MessagePartStepFinish(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class MessagePartFile extends MessagePart {
  const MessagePartFile({required this.id, required this.sessionID, required this.messageID, @JsonKey(fromJson: _messageAttachmentFromJson) this.attachment = const MessageAttachment.unknown(),  String? $type}): $type = $type ?? 'file',super._();
  factory MessagePartFile.fromJson(Map<String, dynamic> json) => _$MessagePartFileFromJson(json);

@override final  String id;
@override final  String sessionID;
@override final  String messageID;
@JsonKey(fromJson: _messageAttachmentFromJson) final  MessageAttachment attachment;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessagePartFileCopyWith<MessagePartFile> get copyWith => _$MessagePartFileCopyWithImpl<MessagePartFile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessagePartFileToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is MessagePartFile&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID)&&(identical(other.attachment, attachment) || other.attachment == attachment));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,sessionID,messageID,attachment);
}

@override
String toString() {
    return 'MessagePart.file(id: $id, sessionID: $sessionID, messageID: $messageID, attachment: $attachment)';
}


}

/// @nodoc
abstract mixin class $MessagePartFileCopyWith<$Res> implements $MessagePartCopyWith<$Res> {
  factory $MessagePartFileCopyWith(MessagePartFile value, $Res Function(MessagePartFile) _then) = _$MessagePartFileCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String messageID,@JsonKey(fromJson: _messageAttachmentFromJson) MessageAttachment attachment
});


$MessageAttachmentCopyWith<$Res> get attachment;

}
/// @nodoc
class _$MessagePartFileCopyWithImpl<$Res>
    implements $MessagePartFileCopyWith<$Res> {
  _$MessagePartFileCopyWithImpl(this._self, this._then);

  final MessagePartFile _self;
  final $Res Function(MessagePartFile) _then;

/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,Object? attachment = null,}) {
  return _then(MessagePartFile(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,attachment: null == attachment ? _self.attachment : attachment // ignore: cast_nullable_to_non_nullable
as MessageAttachment,
  ));
}

/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessageAttachmentCopyWith<$Res> get attachment {
  
  return $MessageAttachmentCopyWith<$Res>(_self.attachment, (value) {
    return _then(_self.copyWith(attachment: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class MessagePartSnapshot extends MessagePart {
  const MessagePartSnapshot({required this.id, required this.sessionID, required this.messageID,  String? $type}): $type = $type ?? 'snapshot',super._();
  factory MessagePartSnapshot.fromJson(Map<String, dynamic> json) => _$MessagePartSnapshotFromJson(json);

@override final  String id;
@override final  String sessionID;
@override final  String messageID;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessagePartSnapshotCopyWith<MessagePartSnapshot> get copyWith => _$MessagePartSnapshotCopyWithImpl<MessagePartSnapshot>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessagePartSnapshotToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is MessagePartSnapshot&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,sessionID,messageID);
}

@override
String toString() {
    return 'MessagePart.snapshot(id: $id, sessionID: $sessionID, messageID: $messageID)';
}


}

/// @nodoc
abstract mixin class $MessagePartSnapshotCopyWith<$Res> implements $MessagePartCopyWith<$Res> {
  factory $MessagePartSnapshotCopyWith(MessagePartSnapshot value, $Res Function(MessagePartSnapshot) _then) = _$MessagePartSnapshotCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String messageID
});




}
/// @nodoc
class _$MessagePartSnapshotCopyWithImpl<$Res>
    implements $MessagePartSnapshotCopyWith<$Res> {
  _$MessagePartSnapshotCopyWithImpl(this._self, this._then);

  final MessagePartSnapshot _self;
  final $Res Function(MessagePartSnapshot) _then;

/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,}) {
  return _then(MessagePartSnapshot(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class MessagePartPatch extends MessagePart {
  const MessagePartPatch({required this.id, required this.sessionID, required this.messageID,  String? $type}): $type = $type ?? 'patch',super._();
  factory MessagePartPatch.fromJson(Map<String, dynamic> json) => _$MessagePartPatchFromJson(json);

@override final  String id;
@override final  String sessionID;
@override final  String messageID;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessagePartPatchCopyWith<MessagePartPatch> get copyWith => _$MessagePartPatchCopyWithImpl<MessagePartPatch>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessagePartPatchToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is MessagePartPatch&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,sessionID,messageID);
}

@override
String toString() {
    return 'MessagePart.patch(id: $id, sessionID: $sessionID, messageID: $messageID)';
}


}

/// @nodoc
abstract mixin class $MessagePartPatchCopyWith<$Res> implements $MessagePartCopyWith<$Res> {
  factory $MessagePartPatchCopyWith(MessagePartPatch value, $Res Function(MessagePartPatch) _then) = _$MessagePartPatchCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String messageID
});




}
/// @nodoc
class _$MessagePartPatchCopyWithImpl<$Res>
    implements $MessagePartPatchCopyWith<$Res> {
  _$MessagePartPatchCopyWithImpl(this._self, this._then);

  final MessagePartPatch _self;
  final $Res Function(MessagePartPatch) _then;

/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,}) {
  return _then(MessagePartPatch(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class MessagePartAgent extends MessagePart {
  const MessagePartAgent({required this.id, required this.sessionID, required this.messageID, this.agentName = "",  String? $type}): $type = $type ?? 'agent',super._();
  factory MessagePartAgent.fromJson(Map<String, dynamic> json) => _$MessagePartAgentFromJson(json);

@override final  String id;
@override final  String sessionID;
@override final  String messageID;
@JsonKey() final  String agentName;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessagePartAgentCopyWith<MessagePartAgent> get copyWith => _$MessagePartAgentCopyWithImpl<MessagePartAgent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessagePartAgentToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is MessagePartAgent&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID)&&(identical(other.agentName, agentName) || other.agentName == agentName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,sessionID,messageID,agentName);
}

@override
String toString() {
    return 'MessagePart.agent(id: $id, sessionID: $sessionID, messageID: $messageID, agentName: $agentName)';
}


}

/// @nodoc
abstract mixin class $MessagePartAgentCopyWith<$Res> implements $MessagePartCopyWith<$Res> {
  factory $MessagePartAgentCopyWith(MessagePartAgent value, $Res Function(MessagePartAgent) _then) = _$MessagePartAgentCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String messageID, String agentName
});




}
/// @nodoc
class _$MessagePartAgentCopyWithImpl<$Res>
    implements $MessagePartAgentCopyWith<$Res> {
  _$MessagePartAgentCopyWithImpl(this._self, this._then);

  final MessagePartAgent _self;
  final $Res Function(MessagePartAgent) _then;

/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,Object? agentName = null,}) {
  return _then(MessagePartAgent(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,agentName: null == agentName ? _self.agentName : agentName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class MessagePartRetry extends MessagePart {
  const MessagePartRetry({required this.id, required this.sessionID, required this.messageID, this.attempt = 0, this.retryError = "",  String? $type}): $type = $type ?? 'retry',super._();
  factory MessagePartRetry.fromJson(Map<String, dynamic> json) => _$MessagePartRetryFromJson(json);

@override final  String id;
@override final  String sessionID;
@override final  String messageID;
@JsonKey() final  int attempt;
@JsonKey() final  String retryError;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessagePartRetryCopyWith<MessagePartRetry> get copyWith => _$MessagePartRetryCopyWithImpl<MessagePartRetry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessagePartRetryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is MessagePartRetry&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID)&&(identical(other.attempt, attempt) || other.attempt == attempt)&&(identical(other.retryError, retryError) || other.retryError == retryError));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,sessionID,messageID,attempt,retryError);
}

@override
String toString() {
    return 'MessagePart.retry(id: $id, sessionID: $sessionID, messageID: $messageID, attempt: $attempt, retryError: $retryError)';
}


}

/// @nodoc
abstract mixin class $MessagePartRetryCopyWith<$Res> implements $MessagePartCopyWith<$Res> {
  factory $MessagePartRetryCopyWith(MessagePartRetry value, $Res Function(MessagePartRetry) _then) = _$MessagePartRetryCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String messageID, int attempt, String retryError
});




}
/// @nodoc
class _$MessagePartRetryCopyWithImpl<$Res>
    implements $MessagePartRetryCopyWith<$Res> {
  _$MessagePartRetryCopyWithImpl(this._self, this._then);

  final MessagePartRetry _self;
  final $Res Function(MessagePartRetry) _then;

/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,Object? attempt = null,Object? retryError = null,}) {
  return _then(MessagePartRetry(
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
@JsonSerializable()

class MessagePartCompaction extends MessagePart {
  const MessagePartCompaction({required this.id, required this.sessionID, required this.messageID, this.state = const CompactionState.completed(summary: null, freedTokens: null, trigger: null),  String? $type}): $type = $type ?? 'compaction',super._();
  factory MessagePartCompaction.fromJson(Map<String, dynamic> json) => _$MessagePartCompactionFromJson(json);

@override final  String id;
@override final  String sessionID;
@override final  String messageID;
@JsonKey() final  CompactionState state;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessagePartCompactionCopyWith<MessagePartCompaction> get copyWith => _$MessagePartCompactionCopyWithImpl<MessagePartCompaction>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessagePartCompactionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is MessagePartCompaction&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID)&&(identical(other.state, state) || other.state == state));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,sessionID,messageID,state);
}

@override
String toString() {
    return 'MessagePart.compaction(id: $id, sessionID: $sessionID, messageID: $messageID, state: $state)';
}


}

/// @nodoc
abstract mixin class $MessagePartCompactionCopyWith<$Res> implements $MessagePartCopyWith<$Res> {
  factory $MessagePartCompactionCopyWith(MessagePartCompaction value, $Res Function(MessagePartCompaction) _then) = _$MessagePartCompactionCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String messageID, CompactionState state
});


$CompactionStateCopyWith<$Res> get state;

}
/// @nodoc
class _$MessagePartCompactionCopyWithImpl<$Res>
    implements $MessagePartCompactionCopyWith<$Res> {
  _$MessagePartCompactionCopyWithImpl(this._self, this._then);

  final MessagePartCompaction _self;
  final $Res Function(MessagePartCompaction) _then;

/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,Object? state = null,}) {
  return _then(MessagePartCompaction(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as CompactionState,
  ));
}

/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CompactionStateCopyWith<$Res> get state {
  
  return $CompactionStateCopyWith<$Res>(_self.state, (value) {
    return _then(_self.copyWith(state: value));
  });
}
}

CompactionState _$CompactionStateFromJson(
  Map<String, dynamic> json
) {
        switch (json['status']) {
                  case 'running':
          return CompactionStateRunning.fromJson(
            json
          );
                case 'failed':
          return CompactionStateFailed.fromJson(
            json
          );
        
          default:
            return CompactionStateCompleted.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$CompactionState {



  /// Serializes this CompactionState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CompactionState);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'CompactionState()';
}


}

/// @nodoc
class $CompactionStateCopyWith<$Res>  {
$CompactionStateCopyWith(CompactionState _, $Res Function(CompactionState) __);
}



/// @nodoc
@JsonSerializable()

class CompactionStateRunning implements CompactionState {
  const CompactionStateRunning({required this.summary,  String? $type}): $type = $type ?? 'running';
  factory CompactionStateRunning.fromJson(Map<String, dynamic> json) => _$CompactionStateRunningFromJson(json);

 final  String? summary;

@JsonKey(name: 'status')
final String $type;


/// Create a copy of CompactionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CompactionStateRunningCopyWith<CompactionStateRunning> get copyWith => _$CompactionStateRunningCopyWithImpl<CompactionStateRunning>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CompactionStateRunningToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CompactionStateRunning&&(identical(other.summary, summary) || other.summary == summary));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,summary);
}

@override
String toString() {
    return 'CompactionState.running(summary: $summary)';
}


}

/// @nodoc
abstract mixin class $CompactionStateRunningCopyWith<$Res> implements $CompactionStateCopyWith<$Res> {
  factory $CompactionStateRunningCopyWith(CompactionStateRunning value, $Res Function(CompactionStateRunning) _then) = _$CompactionStateRunningCopyWithImpl;
@useResult
$Res call({
 String? summary
});




}
/// @nodoc
class _$CompactionStateRunningCopyWithImpl<$Res>
    implements $CompactionStateRunningCopyWith<$Res> {
  _$CompactionStateRunningCopyWithImpl(this._self, this._then);

  final CompactionStateRunning _self;
  final $Res Function(CompactionStateRunning) _then;

/// Create a copy of CompactionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? summary = freezed,}) {
  return _then(CompactionStateRunning(
summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class CompactionStateCompleted implements CompactionState {
  const CompactionStateCompleted({required this.summary, required this.freedTokens, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) required this.trigger,  String? $type}): $type = $type ?? 'completed';
  factory CompactionStateCompleted.fromJson(Map<String, dynamic> json) => _$CompactionStateCompletedFromJson(json);

 final  String? summary;
 final  int? freedTokens;
@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) final  CompactionTrigger? trigger;

@JsonKey(name: 'status')
final String $type;


/// Create a copy of CompactionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CompactionStateCompletedCopyWith<CompactionStateCompleted> get copyWith => _$CompactionStateCompletedCopyWithImpl<CompactionStateCompleted>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CompactionStateCompletedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CompactionStateCompleted&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.freedTokens, freedTokens) || other.freedTokens == freedTokens)&&(identical(other.trigger, trigger) || other.trigger == trigger));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,summary,freedTokens,trigger);
}

@override
String toString() {
    return 'CompactionState.completed(summary: $summary, freedTokens: $freedTokens, trigger: $trigger)';
}


}

/// @nodoc
abstract mixin class $CompactionStateCompletedCopyWith<$Res> implements $CompactionStateCopyWith<$Res> {
  factory $CompactionStateCompletedCopyWith(CompactionStateCompleted value, $Res Function(CompactionStateCompleted) _then) = _$CompactionStateCompletedCopyWithImpl;
@useResult
$Res call({
 String? summary, int? freedTokens,@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) CompactionTrigger? trigger
});




}
/// @nodoc
class _$CompactionStateCompletedCopyWithImpl<$Res>
    implements $CompactionStateCompletedCopyWith<$Res> {
  _$CompactionStateCompletedCopyWithImpl(this._self, this._then);

  final CompactionStateCompleted _self;
  final $Res Function(CompactionStateCompleted) _then;

/// Create a copy of CompactionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? summary = freezed,Object? freedTokens = freezed,Object? trigger = freezed,}) {
  return _then(CompactionStateCompleted(
summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String?,freedTokens: freezed == freedTokens ? _self.freedTokens : freedTokens // ignore: cast_nullable_to_non_nullable
as int?,trigger: freezed == trigger ? _self.trigger : trigger // ignore: cast_nullable_to_non_nullable
as CompactionTrigger?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class CompactionStateFailed implements CompactionState {
  const CompactionStateFailed({@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) required this.reason,  String? $type}): $type = $type ?? 'failed';
  factory CompactionStateFailed.fromJson(Map<String, dynamic> json) => _$CompactionStateFailedFromJson(json);

@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) final  CompactionFailureReason? reason;

@JsonKey(name: 'status')
final String $type;


/// Create a copy of CompactionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CompactionStateFailedCopyWith<CompactionStateFailed> get copyWith => _$CompactionStateFailedCopyWithImpl<CompactionStateFailed>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CompactionStateFailedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CompactionStateFailed&&(identical(other.reason, reason) || other.reason == reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,reason);
}

@override
String toString() {
    return 'CompactionState.failed(reason: $reason)';
}


}

/// @nodoc
abstract mixin class $CompactionStateFailedCopyWith<$Res> implements $CompactionStateCopyWith<$Res> {
  factory $CompactionStateFailedCopyWith(CompactionStateFailed value, $Res Function(CompactionStateFailed) _then) = _$CompactionStateFailedCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) CompactionFailureReason? reason
});




}
/// @nodoc
class _$CompactionStateFailedCopyWithImpl<$Res>
    implements $CompactionStateFailedCopyWith<$Res> {
  _$CompactionStateFailedCopyWithImpl(this._self, this._then);

  final CompactionStateFailed _self;
  final $Res Function(CompactionStateFailed) _then;

/// Create a copy of CompactionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reason = freezed,}) {
  return _then(CompactionStateFailed(
reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as CompactionFailureReason?,
  ));
}


}

MessageAttachment _$MessageAttachmentFromJson(
  Map<String, dynamic> json
) {
        switch (json['source']) {
                  case 'inline_image':
          return MessageAttachmentInlineImage.fromJson(
            json
          );
                case 'remote_url':
          return MessageAttachmentRemoteUrl.fromJson(
            json
          );
                case 'stored_image':
          return MessageAttachmentStoredImage.fromJson(
            json
          );
                case 'metadata':
          return MessageAttachmentMetadata.fromJson(
            json
          );
        
          default:
            return MessageAttachmentUnknown.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$MessageAttachment {



  /// Serializes this MessageAttachment to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageAttachment);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}

/// @nodoc
class $MessageAttachmentCopyWith<$Res>  {
$MessageAttachmentCopyWith(MessageAttachment _, $Res Function(MessageAttachment) __);
}



/// @nodoc
@JsonSerializable()

class MessageAttachmentInlineImage implements MessageAttachment {
  const MessageAttachmentInlineImage({required this.mime, required this.base64, required this.filename,  String? $type}): $type = $type ?? 'inline_image';
  factory MessageAttachmentInlineImage.fromJson(Map<String, dynamic> json) => _$MessageAttachmentInlineImageFromJson(json);

 final  String mime;
 final  String base64;
 final  String? filename;

@JsonKey(name: 'source')
final String $type;


/// Create a copy of MessageAttachment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageAttachmentInlineImageCopyWith<MessageAttachmentInlineImage> get copyWith => _$MessageAttachmentInlineImageCopyWithImpl<MessageAttachmentInlineImage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageAttachmentInlineImageToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageAttachmentInlineImage&&(identical(other.mime, mime) || other.mime == mime)&&(identical(other.base64, base64) || other.base64 == base64)&&(identical(other.filename, filename) || other.filename == filename));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,mime,base64,filename);
}



}

/// @nodoc
abstract mixin class $MessageAttachmentInlineImageCopyWith<$Res> implements $MessageAttachmentCopyWith<$Res> {
  factory $MessageAttachmentInlineImageCopyWith(MessageAttachmentInlineImage value, $Res Function(MessageAttachmentInlineImage) _then) = _$MessageAttachmentInlineImageCopyWithImpl;
@useResult
$Res call({
 String mime, String base64, String? filename
});




}
/// @nodoc
class _$MessageAttachmentInlineImageCopyWithImpl<$Res>
    implements $MessageAttachmentInlineImageCopyWith<$Res> {
  _$MessageAttachmentInlineImageCopyWithImpl(this._self, this._then);

  final MessageAttachmentInlineImage _self;
  final $Res Function(MessageAttachmentInlineImage) _then;

/// Create a copy of MessageAttachment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? mime = null,Object? base64 = null,Object? filename = freezed,}) {
  return _then(MessageAttachmentInlineImage(
mime: null == mime ? _self.mime : mime // ignore: cast_nullable_to_non_nullable
as String,base64: null == base64 ? _self.base64 : base64 // ignore: cast_nullable_to_non_nullable
as String,filename: freezed == filename ? _self.filename : filename // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class MessageAttachmentRemoteUrl implements MessageAttachment {
  const MessageAttachmentRemoteUrl({required this.mime, required this.url, required this.filename,  String? $type}): $type = $type ?? 'remote_url';
  factory MessageAttachmentRemoteUrl.fromJson(Map<String, dynamic> json) => _$MessageAttachmentRemoteUrlFromJson(json);

 final  String mime;
 final  String url;
 final  String? filename;

@JsonKey(name: 'source')
final String $type;


/// Create a copy of MessageAttachment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageAttachmentRemoteUrlCopyWith<MessageAttachmentRemoteUrl> get copyWith => _$MessageAttachmentRemoteUrlCopyWithImpl<MessageAttachmentRemoteUrl>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageAttachmentRemoteUrlToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageAttachmentRemoteUrl&&(identical(other.mime, mime) || other.mime == mime)&&(identical(other.url, url) || other.url == url)&&(identical(other.filename, filename) || other.filename == filename));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,mime,url,filename);
}



}

/// @nodoc
abstract mixin class $MessageAttachmentRemoteUrlCopyWith<$Res> implements $MessageAttachmentCopyWith<$Res> {
  factory $MessageAttachmentRemoteUrlCopyWith(MessageAttachmentRemoteUrl value, $Res Function(MessageAttachmentRemoteUrl) _then) = _$MessageAttachmentRemoteUrlCopyWithImpl;
@useResult
$Res call({
 String mime, String url, String? filename
});




}
/// @nodoc
class _$MessageAttachmentRemoteUrlCopyWithImpl<$Res>
    implements $MessageAttachmentRemoteUrlCopyWith<$Res> {
  _$MessageAttachmentRemoteUrlCopyWithImpl(this._self, this._then);

  final MessageAttachmentRemoteUrl _self;
  final $Res Function(MessageAttachmentRemoteUrl) _then;

/// Create a copy of MessageAttachment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? mime = null,Object? url = null,Object? filename = freezed,}) {
  return _then(MessageAttachmentRemoteUrl(
mime: null == mime ? _self.mime : mime // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,filename: freezed == filename ? _self.filename : filename // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class MessageAttachmentStoredImage implements MessageAttachment {
  const MessageAttachmentStoredImage({required this.attachmentId, required this.bridgeId, required this.mime, required this.filename, required this.byteLength,  String? $type}): $type = $type ?? 'stored_image';
  factory MessageAttachmentStoredImage.fromJson(Map<String, dynamic> json) => _$MessageAttachmentStoredImageFromJson(json);

 final  String attachmentId;
 final  String bridgeId;
 final  String mime;
 final  String? filename;
 final  int byteLength;

@JsonKey(name: 'source')
final String $type;


/// Create a copy of MessageAttachment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageAttachmentStoredImageCopyWith<MessageAttachmentStoredImage> get copyWith => _$MessageAttachmentStoredImageCopyWithImpl<MessageAttachmentStoredImage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageAttachmentStoredImageToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageAttachmentStoredImage&&(identical(other.attachmentId, attachmentId) || other.attachmentId == attachmentId)&&(identical(other.bridgeId, bridgeId) || other.bridgeId == bridgeId)&&(identical(other.mime, mime) || other.mime == mime)&&(identical(other.filename, filename) || other.filename == filename)&&(identical(other.byteLength, byteLength) || other.byteLength == byteLength));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,attachmentId,bridgeId,mime,filename,byteLength);
}



}

/// @nodoc
abstract mixin class $MessageAttachmentStoredImageCopyWith<$Res> implements $MessageAttachmentCopyWith<$Res> {
  factory $MessageAttachmentStoredImageCopyWith(MessageAttachmentStoredImage value, $Res Function(MessageAttachmentStoredImage) _then) = _$MessageAttachmentStoredImageCopyWithImpl;
@useResult
$Res call({
 String attachmentId, String bridgeId, String mime, String? filename, int byteLength
});




}
/// @nodoc
class _$MessageAttachmentStoredImageCopyWithImpl<$Res>
    implements $MessageAttachmentStoredImageCopyWith<$Res> {
  _$MessageAttachmentStoredImageCopyWithImpl(this._self, this._then);

  final MessageAttachmentStoredImage _self;
  final $Res Function(MessageAttachmentStoredImage) _then;

/// Create a copy of MessageAttachment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? attachmentId = null,Object? bridgeId = null,Object? mime = null,Object? filename = freezed,Object? byteLength = null,}) {
  return _then(MessageAttachmentStoredImage(
attachmentId: null == attachmentId ? _self.attachmentId : attachmentId // ignore: cast_nullable_to_non_nullable
as String,bridgeId: null == bridgeId ? _self.bridgeId : bridgeId // ignore: cast_nullable_to_non_nullable
as String,mime: null == mime ? _self.mime : mime // ignore: cast_nullable_to_non_nullable
as String,filename: freezed == filename ? _self.filename : filename // ignore: cast_nullable_to_non_nullable
as String?,byteLength: null == byteLength ? _self.byteLength : byteLength // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
@JsonSerializable()

class MessageAttachmentMetadata implements MessageAttachment {
  const MessageAttachmentMetadata({required this.mime, required this.filename,  String? $type}): $type = $type ?? 'metadata';
  factory MessageAttachmentMetadata.fromJson(Map<String, dynamic> json) => _$MessageAttachmentMetadataFromJson(json);

 final  String mime;
 final  String? filename;

@JsonKey(name: 'source')
final String $type;


/// Create a copy of MessageAttachment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageAttachmentMetadataCopyWith<MessageAttachmentMetadata> get copyWith => _$MessageAttachmentMetadataCopyWithImpl<MessageAttachmentMetadata>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageAttachmentMetadataToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageAttachmentMetadata&&(identical(other.mime, mime) || other.mime == mime)&&(identical(other.filename, filename) || other.filename == filename));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,mime,filename);
}



}

/// @nodoc
abstract mixin class $MessageAttachmentMetadataCopyWith<$Res> implements $MessageAttachmentCopyWith<$Res> {
  factory $MessageAttachmentMetadataCopyWith(MessageAttachmentMetadata value, $Res Function(MessageAttachmentMetadata) _then) = _$MessageAttachmentMetadataCopyWithImpl;
@useResult
$Res call({
 String mime, String? filename
});




}
/// @nodoc
class _$MessageAttachmentMetadataCopyWithImpl<$Res>
    implements $MessageAttachmentMetadataCopyWith<$Res> {
  _$MessageAttachmentMetadataCopyWithImpl(this._self, this._then);

  final MessageAttachmentMetadata _self;
  final $Res Function(MessageAttachmentMetadata) _then;

/// Create a copy of MessageAttachment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? mime = null,Object? filename = freezed,}) {
  return _then(MessageAttachmentMetadata(
mime: null == mime ? _self.mime : mime // ignore: cast_nullable_to_non_nullable
as String,filename: freezed == filename ? _self.filename : filename // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class MessageAttachmentUnknown implements MessageAttachment {
  const MessageAttachmentUnknown({ String? $type}): $type = $type ?? 'unknown';
  factory MessageAttachmentUnknown.fromJson(Map<String, dynamic> json) => _$MessageAttachmentUnknownFromJson(json);



@JsonKey(name: 'source')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$MessageAttachmentUnknownToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageAttachmentUnknown);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}




ToolState _$ToolStateFromJson(
  Map<String, dynamic> json
) {
        switch (json['form']) {
                  case 'summary':
          return ToolStateSummary.fromJson(
            json
          );
        
          default:
            return ToolStateFull.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$ToolState {

@JsonKey(unknownEnumValue: ToolStatus.unknown) ToolStatus get status; String? get title; String? get shellCommand;@JsonKey(fromJson: _messageAttachmentsFromJson) List<MessageAttachment> get attachments;
/// Create a copy of ToolState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ToolStateCopyWith<ToolState> get copyWith => _$ToolStateCopyWithImpl<ToolState>(this as ToolState, _$identity);

  /// Serializes this ToolState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ToolState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ToolState&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.shellCommand, _this.shellCommand) || other.shellCommand == _this.shellCommand)&&const DeepCollectionEquality().equals(other.attachments, _this.attachments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ToolState;
  return Object.hash(runtimeType,_this.status,_this.title,_this.shellCommand,const DeepCollectionEquality().hash(_this.attachments));
}

@override
String toString() {
  final _this = this as ToolState;
  return 'ToolState(status: ${_this.status}, title: ${_this.title}, shellCommand: ${_this.shellCommand}, attachments: ${_this.attachments})';
}


}

/// @nodoc
abstract mixin class $ToolStateCopyWith<$Res>  {
  factory $ToolStateCopyWith(ToolState value, $Res Function(ToolState) _then) = _$ToolStateCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: ToolStatus.unknown) ToolStatus status, String? title, String? shellCommand,@JsonKey(fromJson: _messageAttachmentsFromJson) List<MessageAttachment> attachments
});




}
/// @nodoc
class _$ToolStateCopyWithImpl<$Res>
    implements $ToolStateCopyWith<$Res> {
  _$ToolStateCopyWithImpl(this._self, this._then);

  final ToolState _self;
  final $Res Function(ToolState) _then;

/// Create a copy of ToolState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? title = freezed,Object? shellCommand = freezed,Object? attachments = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ToolStatus,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,shellCommand: freezed == shellCommand ? _self.shellCommand : shellCommand // ignore: cast_nullable_to_non_nullable
as String?,attachments: null == attachments ? _self.attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<MessageAttachment>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class ToolStateFull implements ToolState {
  const ToolStateFull({@JsonKey(unknownEnumValue: ToolStatus.unknown) required this.status, required this.title, required this.shellCommand, required this.output, required this.error, @JsonKey(fromJson: _messageAttachmentsFromJson)  List<MessageAttachment> attachments = const <MessageAttachment>[],  String? $type}): _attachments = attachments,$type = $type ?? 'full';
  factory ToolStateFull.fromJson(Map<String, dynamic> json) => _$ToolStateFullFromJson(json);

@override@JsonKey(unknownEnumValue: ToolStatus.unknown) final  ToolStatus status;
@override final  String? title;
@override final  String? shellCommand;
 final  String? output;
 final  String? error;
 final  List<MessageAttachment> _attachments;
@override@JsonKey(fromJson: _messageAttachmentsFromJson) List<MessageAttachment> get attachments {
  if (_attachments is EqualUnmodifiableListView) return _attachments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_attachments);
}


@JsonKey(name: 'form')
final String $type;


/// Create a copy of ToolState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ToolStateFullCopyWith<ToolStateFull> get copyWith => _$ToolStateFullCopyWithImpl<ToolStateFull>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ToolStateFullToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ToolStateFull&&(identical(other.status, status) || other.status == status)&&(identical(other.title, title) || other.title == title)&&(identical(other.shellCommand, shellCommand) || other.shellCommand == shellCommand)&&(identical(other.output, output) || other.output == output)&&(identical(other.error, error) || other.error == error)&&const DeepCollectionEquality().equals(other.attachments, _attachments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,status,title,shellCommand,output,error,const DeepCollectionEquality().hash(_attachments));
}

@override
String toString() {
    return 'ToolState(status: $status, title: $title, shellCommand: $shellCommand, output: $output, error: $error, attachments: $attachments)';
}


}

/// @nodoc
abstract mixin class $ToolStateFullCopyWith<$Res> implements $ToolStateCopyWith<$Res> {
  factory $ToolStateFullCopyWith(ToolStateFull value, $Res Function(ToolStateFull) _then) = _$ToolStateFullCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: ToolStatus.unknown) ToolStatus status, String? title, String? shellCommand, String? output, String? error,@JsonKey(fromJson: _messageAttachmentsFromJson) List<MessageAttachment> attachments
});




}
/// @nodoc
class _$ToolStateFullCopyWithImpl<$Res>
    implements $ToolStateFullCopyWith<$Res> {
  _$ToolStateFullCopyWithImpl(this._self, this._then);

  final ToolStateFull _self;
  final $Res Function(ToolStateFull) _then;

/// Create a copy of ToolState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? title = freezed,Object? shellCommand = freezed,Object? output = freezed,Object? error = freezed,Object? attachments = null,}) {
  return _then(ToolStateFull(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ToolStatus,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,shellCommand: freezed == shellCommand ? _self.shellCommand : shellCommand // ignore: cast_nullable_to_non_nullable
as String?,output: freezed == output ? _self.output : output // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,attachments: null == attachments ? _self._attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<MessageAttachment>,
  ));
}


}

/// @nodoc
@JsonSerializable()

class ToolStateSummary implements ToolState {
  const ToolStateSummary({@JsonKey(unknownEnumValue: ToolStatus.unknown) required this.status, required this.title, required this.shellCommand, @JsonKey(fromJson: _messageAttachmentsFromJson) required  List<MessageAttachment> attachments,  String? $type}): _attachments = attachments,$type = $type ?? 'summary';
  factory ToolStateSummary.fromJson(Map<String, dynamic> json) => _$ToolStateSummaryFromJson(json);

@override@JsonKey(unknownEnumValue: ToolStatus.unknown) final  ToolStatus status;
@override final  String? title;
@override final  String? shellCommand;
 final  List<MessageAttachment> _attachments;
@override@JsonKey(fromJson: _messageAttachmentsFromJson) List<MessageAttachment> get attachments {
  if (_attachments is EqualUnmodifiableListView) return _attachments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_attachments);
}


@JsonKey(name: 'form')
final String $type;


/// Create a copy of ToolState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ToolStateSummaryCopyWith<ToolStateSummary> get copyWith => _$ToolStateSummaryCopyWithImpl<ToolStateSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ToolStateSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ToolStateSummary&&(identical(other.status, status) || other.status == status)&&(identical(other.title, title) || other.title == title)&&(identical(other.shellCommand, shellCommand) || other.shellCommand == shellCommand)&&const DeepCollectionEquality().equals(other.attachments, _attachments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,status,title,shellCommand,const DeepCollectionEquality().hash(_attachments));
}

@override
String toString() {
    return 'ToolState.summary(status: $status, title: $title, shellCommand: $shellCommand, attachments: $attachments)';
}


}

/// @nodoc
abstract mixin class $ToolStateSummaryCopyWith<$Res> implements $ToolStateCopyWith<$Res> {
  factory $ToolStateSummaryCopyWith(ToolStateSummary value, $Res Function(ToolStateSummary) _then) = _$ToolStateSummaryCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: ToolStatus.unknown) ToolStatus status, String? title, String? shellCommand,@JsonKey(fromJson: _messageAttachmentsFromJson) List<MessageAttachment> attachments
});




}
/// @nodoc
class _$ToolStateSummaryCopyWithImpl<$Res>
    implements $ToolStateSummaryCopyWith<$Res> {
  _$ToolStateSummaryCopyWithImpl(this._self, this._then);

  final ToolStateSummary _self;
  final $Res Function(ToolStateSummary) _then;

/// Create a copy of ToolState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? title = freezed,Object? shellCommand = freezed,Object? attachments = null,}) {
  return _then(ToolStateSummary(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ToolStatus,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,shellCommand: freezed == shellCommand ? _self.shellCommand : shellCommand // ignore: cast_nullable_to_non_nullable
as String?,attachments: null == attachments ? _self._attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<MessageAttachment>,
  ));
}


}

// dart format on
