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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessagePart&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID);

@override
String toString() {
  return 'MessagePart(id: $id, sessionID: $sessionID, messageID: $messageID)';
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
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID,text);

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
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID,text);

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
  const MessagePartTool({required this.id, required this.sessionID, required this.messageID, this.tool = "", this.state = const ToolState(status: ToolStatus.pending, title: null, output: null, error: null),  String? $type}): $type = $type ?? 'tool',super._();
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
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID,tool,state);

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
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID,prompt,description,agent,taskState,childSessionID);

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
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID);

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
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID);

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
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID,attachment);

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
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID);

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
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID);

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
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID,agentName);

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
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID,attempt,retryError);

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
  const MessagePartCompaction({required this.id, required this.sessionID, required this.messageID,  String? $type}): $type = $type ?? 'compaction',super._();
  factory MessagePartCompaction.fromJson(Map<String, dynamic> json) => _$MessagePartCompactionFromJson(json);

@override final  String id;
@override final  String sessionID;
@override final  String messageID;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessagePartCompaction&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID);

@override
String toString() {
  return 'MessagePart.compaction(id: $id, sessionID: $sessionID, messageID: $messageID)';
}


}

/// @nodoc
abstract mixin class $MessagePartCompactionCopyWith<$Res> implements $MessagePartCopyWith<$Res> {
  factory $MessagePartCompactionCopyWith(MessagePartCompaction value, $Res Function(MessagePartCompaction) _then) = _$MessagePartCompactionCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String messageID
});




}
/// @nodoc
class _$MessagePartCompactionCopyWithImpl<$Res>
    implements $MessagePartCompactionCopyWith<$Res> {
  _$MessagePartCompactionCopyWithImpl(this._self, this._then);

  final MessagePartCompaction _self;
  final $Res Function(MessagePartCompaction) _then;

/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,}) {
  return _then(MessagePartCompaction(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,
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
int get hashCode => Object.hash(runtimeType,mime,base64,filename);



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
int get hashCode => Object.hash(runtimeType,mime,url,filename);



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
int get hashCode => Object.hash(runtimeType,attachmentId,bridgeId,mime,filename,byteLength);



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
int get hashCode => Object.hash(runtimeType,mime,filename);



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





/// @nodoc
mixin _$ToolState {

@JsonKey(unknownEnumValue: ToolStatus.unknown) ToolStatus get status; String? get title; String? get output; String? get error;@JsonKey(fromJson: _messageAttachmentsFromJson) List<MessageAttachment> get attachments;
/// Create a copy of ToolState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ToolStateCopyWith<ToolState> get copyWith => _$ToolStateCopyWithImpl<ToolState>(this as ToolState, _$identity);

  /// Serializes this ToolState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ToolState&&(identical(other.status, status) || other.status == status)&&(identical(other.title, title) || other.title == title)&&(identical(other.output, output) || other.output == output)&&(identical(other.error, error) || other.error == error)&&const DeepCollectionEquality().equals(other.attachments, attachments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,title,output,error,const DeepCollectionEquality().hash(attachments));

@override
String toString() {
  return 'ToolState(status: $status, title: $title, output: $output, error: $error, attachments: $attachments)';
}


}

/// @nodoc
abstract mixin class $ToolStateCopyWith<$Res>  {
  factory $ToolStateCopyWith(ToolState value, $Res Function(ToolState) _then) = _$ToolStateCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: ToolStatus.unknown) ToolStatus status, String? title, String? output, String? error,@JsonKey(fromJson: _messageAttachmentsFromJson) List<MessageAttachment> attachments
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
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? title = freezed,Object? output = freezed,Object? error = freezed,Object? attachments = null,}) {
  return _then(ToolState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ToolStatus,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,output: freezed == output ? _self.output : output // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,attachments: null == attachments ? _self.attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<MessageAttachment>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _ToolState implements ToolState {
  const _ToolState({@JsonKey(unknownEnumValue: ToolStatus.unknown) required this.status, required this.title, required this.output, required this.error, @JsonKey(fromJson: _messageAttachmentsFromJson)  List<MessageAttachment> attachments = const <MessageAttachment>[]}): _attachments = attachments;
  factory _ToolState.fromJson(Map<String, dynamic> json) => _$ToolStateFromJson(json);

@override@JsonKey(unknownEnumValue: ToolStatus.unknown) final  ToolStatus status;
@override final  String? title;
@override final  String? output;
@override final  String? error;
 final  List<MessageAttachment> _attachments;
@override@JsonKey(fromJson: _messageAttachmentsFromJson) List<MessageAttachment> get attachments {
  if (_attachments is EqualUnmodifiableListView) return _attachments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_attachments);
}


/// Create a copy of ToolState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ToolStateCopyWith<_ToolState> get copyWith => __$ToolStateCopyWithImpl<_ToolState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ToolStateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ToolState&&(identical(other.status, status) || other.status == status)&&(identical(other.title, title) || other.title == title)&&(identical(other.output, output) || other.output == output)&&(identical(other.error, error) || other.error == error)&&const DeepCollectionEquality().equals(other._attachments, _attachments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,title,output,error,const DeepCollectionEquality().hash(_attachments));

@override
String toString() {
  return 'ToolState(status: $status, title: $title, output: $output, error: $error, attachments: $attachments)';
}


}

/// @nodoc
abstract mixin class _$ToolStateCopyWith<$Res> implements $ToolStateCopyWith<$Res> {
  factory _$ToolStateCopyWith(_ToolState value, $Res Function(_ToolState) _then) = __$ToolStateCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: ToolStatus.unknown) ToolStatus status, String? title, String? output, String? error,@JsonKey(fromJson: _messageAttachmentsFromJson) List<MessageAttachment> attachments
});




}
/// @nodoc
class __$ToolStateCopyWithImpl<$Res>
    implements _$ToolStateCopyWith<$Res> {
  __$ToolStateCopyWithImpl(this._self, this._then);

  final _ToolState _self;
  final $Res Function(_ToolState) _then;

/// Create a copy of ToolState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? title = freezed,Object? output = freezed,Object? error = freezed,Object? attachments = null,}) {
  return _then(_ToolState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ToolStatus,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,output: freezed == output ? _self.output : output // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,attachments: null == attachments ? _self._attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<MessageAttachment>,
  ));
}


}

// dart format on
