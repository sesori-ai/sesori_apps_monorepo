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

 String get id; String get sessionID; String get messageID; MessagePartType get type; String? get text; String? get tool; ToolState? get state; String? get prompt; String? get description; String? get agent; String? get agentName; int? get attempt; String? get retryError;@JsonKey(fromJson: _messageAttachmentFromJson) MessageAttachment? get attachment;
/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessagePartCopyWith<MessagePart> get copyWith => _$MessagePartCopyWithImpl<MessagePart>(this as MessagePart, _$identity);

  /// Serializes this MessagePart to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessagePart&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID)&&(identical(other.type, type) || other.type == type)&&(identical(other.text, text) || other.text == text)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.state, state) || other.state == state)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.description, description) || other.description == description)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.agentName, agentName) || other.agentName == agentName)&&(identical(other.attempt, attempt) || other.attempt == attempt)&&(identical(other.retryError, retryError) || other.retryError == retryError)&&(identical(other.attachment, attachment) || other.attachment == attachment));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID,type,text,tool,state,prompt,description,agent,agentName,attempt,retryError,attachment);

@override
String toString() {
  return 'MessagePart(id: $id, sessionID: $sessionID, messageID: $messageID, type: $type, text: $text, tool: $tool, state: $state, prompt: $prompt, description: $description, agent: $agent, agentName: $agentName, attempt: $attempt, retryError: $retryError, attachment: $attachment)';
}


}

/// @nodoc
abstract mixin class $MessagePartCopyWith<$Res>  {
  factory $MessagePartCopyWith(MessagePart value, $Res Function(MessagePart) _then) = _$MessagePartCopyWithImpl;
@useResult
$Res call({
 String id, String sessionID, String messageID, MessagePartType type, String? text, String? tool, ToolState? state, String? prompt, String? description, String? agent, String? agentName, int? attempt, String? retryError,@JsonKey(fromJson: _messageAttachmentFromJson) MessageAttachment? attachment
});


$ToolStateCopyWith<$Res>? get state;$MessageAttachmentCopyWith<$Res>? get attachment;

}
/// @nodoc
class _$MessagePartCopyWithImpl<$Res>
    implements $MessagePartCopyWith<$Res> {
  _$MessagePartCopyWithImpl(this._self, this._then);

  final MessagePart _self;
  final $Res Function(MessagePart) _then;

/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,Object? type = null,Object? text = freezed,Object? tool = freezed,Object? state = freezed,Object? prompt = freezed,Object? description = freezed,Object? agent = freezed,Object? agentName = freezed,Object? attempt = freezed,Object? retryError = freezed,Object? attachment = freezed,}) {
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
as String?,agentName: freezed == agentName ? _self.agentName : agentName // ignore: cast_nullable_to_non_nullable
as String?,attempt: freezed == attempt ? _self.attempt : attempt // ignore: cast_nullable_to_non_nullable
as int?,retryError: freezed == retryError ? _self.retryError : retryError // ignore: cast_nullable_to_non_nullable
as String?,attachment: freezed == attachment ? _self.attachment : attachment // ignore: cast_nullable_to_non_nullable
as MessageAttachment?,
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
}/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessageAttachmentCopyWith<$Res>? get attachment {
    if (_self.attachment == null) {
    return null;
  }

  return $MessageAttachmentCopyWith<$Res>(_self.attachment!, (value) {
    return _then(_self.copyWith(attachment: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _MessagePart implements MessagePart {
  const _MessagePart({required this.id, required this.sessionID, required this.messageID, required this.type, required this.text, required this.tool, required this.state, required this.prompt, required this.description, required this.agent, required this.agentName, required this.attempt, required this.retryError, @JsonKey(fromJson: _messageAttachmentFromJson) required this.attachment});
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
@override final  String? agentName;
@override final  int? attempt;
@override final  String? retryError;
@override@JsonKey(fromJson: _messageAttachmentFromJson) final  MessageAttachment? attachment;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessagePart&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID)&&(identical(other.type, type) || other.type == type)&&(identical(other.text, text) || other.text == text)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.state, state) || other.state == state)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.description, description) || other.description == description)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.agentName, agentName) || other.agentName == agentName)&&(identical(other.attempt, attempt) || other.attempt == attempt)&&(identical(other.retryError, retryError) || other.retryError == retryError)&&(identical(other.attachment, attachment) || other.attachment == attachment));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID,type,text,tool,state,prompt,description,agent,agentName,attempt,retryError,attachment);

@override
String toString() {
  return 'MessagePart(id: $id, sessionID: $sessionID, messageID: $messageID, type: $type, text: $text, tool: $tool, state: $state, prompt: $prompt, description: $description, agent: $agent, agentName: $agentName, attempt: $attempt, retryError: $retryError, attachment: $attachment)';
}


}

/// @nodoc
abstract mixin class _$MessagePartCopyWith<$Res> implements $MessagePartCopyWith<$Res> {
  factory _$MessagePartCopyWith(_MessagePart value, $Res Function(_MessagePart) _then) = __$MessagePartCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String messageID, MessagePartType type, String? text, String? tool, ToolState? state, String? prompt, String? description, String? agent, String? agentName, int? attempt, String? retryError,@JsonKey(fromJson: _messageAttachmentFromJson) MessageAttachment? attachment
});


@override $ToolStateCopyWith<$Res>? get state;@override $MessageAttachmentCopyWith<$Res>? get attachment;

}
/// @nodoc
class __$MessagePartCopyWithImpl<$Res>
    implements _$MessagePartCopyWith<$Res> {
  __$MessagePartCopyWithImpl(this._self, this._then);

  final _MessagePart _self;
  final $Res Function(_MessagePart) _then;

/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,Object? type = null,Object? text = freezed,Object? tool = freezed,Object? state = freezed,Object? prompt = freezed,Object? description = freezed,Object? agent = freezed,Object? agentName = freezed,Object? attempt = freezed,Object? retryError = freezed,Object? attachment = freezed,}) {
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
as String?,agentName: freezed == agentName ? _self.agentName : agentName // ignore: cast_nullable_to_non_nullable
as String?,attempt: freezed == attempt ? _self.attempt : attempt // ignore: cast_nullable_to_non_nullable
as int?,retryError: freezed == retryError ? _self.retryError : retryError // ignore: cast_nullable_to_non_nullable
as String?,attachment: freezed == attachment ? _self.attachment : attachment // ignore: cast_nullable_to_non_nullable
as MessageAttachment?,
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
}/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessageAttachmentCopyWith<$Res>? get attachment {
    if (_self.attachment == null) {
    return null;
  }

  return $MessageAttachmentCopyWith<$Res>(_self.attachment!, (value) {
    return _then(_self.copyWith(attachment: value));
  });
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
  const MessageAttachmentInlineImage({required this.mime, required this.base64, required this.filename, final  String? $type}): $type = $type ?? 'inline_image';
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
  const MessageAttachmentRemoteUrl({required this.mime, required this.url, required this.filename, final  String? $type}): $type = $type ?? 'remote_url';
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

class MessageAttachmentMetadata implements MessageAttachment {
  const MessageAttachmentMetadata({required this.mime, required this.filename, final  String? $type}): $type = $type ?? 'metadata';
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
  const MessageAttachmentUnknown({final  String? $type}): $type = $type ?? 'unknown';
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

@JsonKey(unknownEnumValue: ToolStatus.unknown) ToolStatus get status; String? get title; String? get output; String? get error;// COMPATIBILITY 2026-07-30 (v1.6.1): Older bridges omit attachments, which means the tool returned none. Remove @Default and require attachments after the minimum supported bridge sends it.
@JsonKey(fromJson: _messageAttachmentsFromJson) List<MessageAttachment> get attachments;
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
  return _then(_self.copyWith(
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
  const _ToolState({@JsonKey(unknownEnumValue: ToolStatus.unknown) required this.status, required this.title, required this.output, required this.error, @JsonKey(fromJson: _messageAttachmentsFromJson) final  List<MessageAttachment> attachments = const <MessageAttachment>[]}): _attachments = attachments;
  factory _ToolState.fromJson(Map<String, dynamic> json) => _$ToolStateFromJson(json);

@override@JsonKey(unknownEnumValue: ToolStatus.unknown) final  ToolStatus status;
@override final  String? title;
@override final  String? output;
@override final  String? error;
// COMPATIBILITY 2026-07-30 (v1.6.1): Older bridges omit attachments, which means the tool returned none. Remove @Default and require attachments after the minimum supported bridge sends it.
 final  List<MessageAttachment> _attachments;
// COMPATIBILITY 2026-07-30 (v1.6.1): Older bridges omit attachments, which means the tool returned none. Remove @Default and require attachments after the minimum supported bridge sends it.
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
