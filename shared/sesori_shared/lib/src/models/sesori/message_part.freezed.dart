// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message_part.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MessagePart {

 String get id; String get sessionID; String get messageID; MessagePartType get type; String? get text; String? get tool; ToolState? get state; String? get prompt; String? get description; String? get agent;
/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessagePartCopyWith<MessagePart> get copyWith => _$MessagePartCopyWithImpl<MessagePart>(this as MessagePart, _$identity);

  /// Serializes this MessagePart to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessagePart&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID)&&(identical(other.type, type) || other.type == type)&&(identical(other.text, text) || other.text == text)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.state, state) || other.state == state)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.description, description) || other.description == description)&&(identical(other.agent, agent) || other.agent == agent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID,type,text,tool,state,prompt,description,agent);

@override
String toString() {
  return 'MessagePart(id: $id, sessionID: $sessionID, messageID: $messageID, type: $type, text: $text, tool: $tool, state: $state, prompt: $prompt, description: $description, agent: $agent)';
}


}

/// @nodoc
abstract mixin class $MessagePartCopyWith<$Res>  {
  factory $MessagePartCopyWith(MessagePart value, $Res Function(MessagePart) _then) = _$MessagePartCopyWithImpl;
@useResult
$Res call({
 String id, String sessionID, String messageID, MessagePartType type, String? text, String? tool, ToolState? state, String? prompt, String? description, String? agent
});


$ToolStateCopyWith<$Res>? get state;

}
/// @nodoc
class _$MessagePartCopyWithImpl<$Res>
    implements $MessagePartCopyWith<$Res> {
  _$MessagePartCopyWithImpl(this._self, this._then);

  final MessagePart _self;
  final $Res Function(MessagePart) _then;

/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,Object? type = null,Object? text = freezed,Object? tool = freezed,Object? state = freezed,Object? prompt = freezed,Object? description = freezed,Object? agent = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as MessagePartType,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,tool: freezed == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as String?,state: freezed == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as ToolState?,prompt: freezed == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ToolStateCopyWith<$Res>? get state {
    if (_self.state == null) {
    return null;
  }

  return $ToolStateCopyWith<$Res>(_self.state!, (value) {
    return _then(_self.copyWith(state: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _MessagePart implements MessagePart {
  const _MessagePart({required this.id, required this.sessionID, required this.messageID, required this.type, this.text, this.tool, this.state, this.prompt, this.description, this.agent});
  factory _MessagePart.fromJson(Map<String, dynamic> json) => _$MessagePartFromJson(json);

@override final  String id;
@override final  String sessionID;
@override final  String messageID;
@override final  MessagePartType type;
@override final  String? text;
@override final  String? tool;
@override final  ToolState? state;
@override final  String? prompt;
@override final  String? description;
@override final  String? agent;

/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessagePartCopyWith<_MessagePart> get copyWith => __$MessagePartCopyWithImpl<_MessagePart>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessagePartToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessagePart&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID)&&(identical(other.type, type) || other.type == type)&&(identical(other.text, text) || other.text == text)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.state, state) || other.state == state)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.description, description) || other.description == description)&&(identical(other.agent, agent) || other.agent == agent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID,type,text,tool,state,prompt,description,agent);

@override
String toString() {
  return 'MessagePart(id: $id, sessionID: $sessionID, messageID: $messageID, type: $type, text: $text, tool: $tool, state: $state, prompt: $prompt, description: $description, agent: $agent)';
}


}

/// @nodoc
abstract mixin class _$MessagePartCopyWith<$Res> implements $MessagePartCopyWith<$Res> {
  factory _$MessagePartCopyWith(_MessagePart value, $Res Function(_MessagePart) _then) = __$MessagePartCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String messageID, MessagePartType type, String? text, String? tool, ToolState? state, String? prompt, String? description, String? agent
});


@override $ToolStateCopyWith<$Res>? get state;

}
/// @nodoc
class __$MessagePartCopyWithImpl<$Res>
    implements _$MessagePartCopyWith<$Res> {
  __$MessagePartCopyWithImpl(this._self, this._then);

  final _MessagePart _self;
  final $Res Function(_MessagePart) _then;

/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,Object? type = null,Object? text = freezed,Object? tool = freezed,Object? state = freezed,Object? prompt = freezed,Object? description = freezed,Object? agent = freezed,}) {
  return _then(_MessagePart(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as MessagePartType,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,tool: freezed == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as String?,state: freezed == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as ToolState?,prompt: freezed == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ToolStateCopyWith<$Res>? get state {
    if (_self.state == null) {
    return null;
  }

  return $ToolStateCopyWith<$Res>(_self.state!, (value) {
    return _then(_self.copyWith(state: value));
  });
}
}


/// @nodoc
mixin _$ToolState {

 String get status; String? get title; String? get output; String? get error;
/// Create a copy of ToolState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ToolStateCopyWith<ToolState> get copyWith => _$ToolStateCopyWithImpl<ToolState>(this as ToolState, _$identity);

  /// Serializes this ToolState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ToolState&&(identical(other.status, status) || other.status == status)&&(identical(other.title, title) || other.title == title)&&(identical(other.output, output) || other.output == output)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,title,output,error);

@override
String toString() {
  return 'ToolState(status: $status, title: $title, output: $output, error: $error)';
}


}

/// @nodoc
abstract mixin class $ToolStateCopyWith<$Res>  {
  factory $ToolStateCopyWith(ToolState value, $Res Function(ToolState) _then) = _$ToolStateCopyWithImpl;
@useResult
$Res call({
 String status, String? title, String? output, String? error
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
@JsonSerializable()

class _ToolState implements ToolState {
  const _ToolState({required this.status, this.title, this.output, this.error});
  factory _ToolState.fromJson(Map<String, dynamic> json) => _$ToolStateFromJson(json);

@override final  String status;
@override final  String? title;
@override final  String? output;
@override final  String? error;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ToolState&&(identical(other.status, status) || other.status == status)&&(identical(other.title, title) || other.title == title)&&(identical(other.output, output) || other.output == output)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,title,output,error);

@override
String toString() {
  return 'ToolState(status: $status, title: $title, output: $output, error: $error)';
}


}

/// @nodoc
abstract mixin class _$ToolStateCopyWith<$Res> implements $ToolStateCopyWith<$Res> {
  factory _$ToolStateCopyWith(_ToolState value, $Res Function(_ToolState) _then) = __$ToolStateCopyWithImpl;
@override @useResult
$Res call({
 String status, String? title, String? output, String? error
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
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? title = freezed,Object? output = freezed,Object? error = freezed,}) {
  return _then(_ToolState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,output: freezed == output ? _self.output : output // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
