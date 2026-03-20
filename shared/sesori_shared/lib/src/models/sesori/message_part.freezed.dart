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

 String get id; String get sessionID; String get messageID; String get type;// text / reasoning
 String? get text;// tool
 String? get tool; String? get callID; ToolState? get state;// file
 String? get mime; String? get url; String? get filename;// step-finish
 double? get cost; String? get reason;// subtask
 String? get prompt; String? get description; String? get agent;// snapshot / step-start
 String? get snapshot;// time (for text, reasoning, tool)
 PartTime? get time;
/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessagePartCopyWith<MessagePart> get copyWith => _$MessagePartCopyWithImpl<MessagePart>(this as MessagePart, _$identity);

  /// Serializes this MessagePart to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessagePart&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID)&&(identical(other.type, type) || other.type == type)&&(identical(other.text, text) || other.text == text)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.callID, callID) || other.callID == callID)&&(identical(other.state, state) || other.state == state)&&(identical(other.mime, mime) || other.mime == mime)&&(identical(other.url, url) || other.url == url)&&(identical(other.filename, filename) || other.filename == filename)&&(identical(other.cost, cost) || other.cost == cost)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.description, description) || other.description == description)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.snapshot, snapshot) || other.snapshot == snapshot)&&(identical(other.time, time) || other.time == time));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID,type,text,tool,callID,state,mime,url,filename,cost,reason,prompt,description,agent,snapshot,time);

@override
String toString() {
  return 'MessagePart(id: $id, sessionID: $sessionID, messageID: $messageID, type: $type, text: $text, tool: $tool, callID: $callID, state: $state, mime: $mime, url: $url, filename: $filename, cost: $cost, reason: $reason, prompt: $prompt, description: $description, agent: $agent, snapshot: $snapshot, time: $time)';
}


}

/// @nodoc
abstract mixin class $MessagePartCopyWith<$Res>  {
  factory $MessagePartCopyWith(MessagePart value, $Res Function(MessagePart) _then) = _$MessagePartCopyWithImpl;
@useResult
$Res call({
 String id, String sessionID, String messageID, String type, String? text, String? tool, String? callID, ToolState? state, String? mime, String? url, String? filename, double? cost, String? reason, String? prompt, String? description, String? agent, String? snapshot, PartTime? time
});


$ToolStateCopyWith<$Res>? get state;$PartTimeCopyWith<$Res>? get time;

}
/// @nodoc
class _$MessagePartCopyWithImpl<$Res>
    implements $MessagePartCopyWith<$Res> {
  _$MessagePartCopyWithImpl(this._self, this._then);

  final MessagePart _self;
  final $Res Function(MessagePart) _then;

/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,Object? type = null,Object? text = freezed,Object? tool = freezed,Object? callID = freezed,Object? state = freezed,Object? mime = freezed,Object? url = freezed,Object? filename = freezed,Object? cost = freezed,Object? reason = freezed,Object? prompt = freezed,Object? description = freezed,Object? agent = freezed,Object? snapshot = freezed,Object? time = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,tool: freezed == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as String?,callID: freezed == callID ? _self.callID : callID // ignore: cast_nullable_to_non_nullable
as String?,state: freezed == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as ToolState?,mime: freezed == mime ? _self.mime : mime // ignore: cast_nullable_to_non_nullable
as String?,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,filename: freezed == filename ? _self.filename : filename // ignore: cast_nullable_to_non_nullable
as String?,cost: freezed == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as double?,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,prompt: freezed == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,snapshot: freezed == snapshot ? _self.snapshot : snapshot // ignore: cast_nullable_to_non_nullable
as String?,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as PartTime?,
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
$PartTimeCopyWith<$Res>? get time {
    if (_self.time == null) {
    return null;
  }

  return $PartTimeCopyWith<$Res>(_self.time!, (value) {
    return _then(_self.copyWith(time: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _MessagePart implements MessagePart {
  const _MessagePart({required this.id, required this.sessionID, required this.messageID, required this.type, this.text, this.tool, this.callID, this.state, this.mime, this.url, this.filename, this.cost, this.reason, this.prompt, this.description, this.agent, this.snapshot, this.time});
  factory _MessagePart.fromJson(Map<String, dynamic> json) => _$MessagePartFromJson(json);

@override final  String id;
@override final  String sessionID;
@override final  String messageID;
@override final  String type;
// text / reasoning
@override final  String? text;
// tool
@override final  String? tool;
@override final  String? callID;
@override final  ToolState? state;
// file
@override final  String? mime;
@override final  String? url;
@override final  String? filename;
// step-finish
@override final  double? cost;
@override final  String? reason;
// subtask
@override final  String? prompt;
@override final  String? description;
@override final  String? agent;
// snapshot / step-start
@override final  String? snapshot;
// time (for text, reasoning, tool)
@override final  PartTime? time;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessagePart&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID)&&(identical(other.type, type) || other.type == type)&&(identical(other.text, text) || other.text == text)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.callID, callID) || other.callID == callID)&&(identical(other.state, state) || other.state == state)&&(identical(other.mime, mime) || other.mime == mime)&&(identical(other.url, url) || other.url == url)&&(identical(other.filename, filename) || other.filename == filename)&&(identical(other.cost, cost) || other.cost == cost)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.description, description) || other.description == description)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.snapshot, snapshot) || other.snapshot == snapshot)&&(identical(other.time, time) || other.time == time));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,messageID,type,text,tool,callID,state,mime,url,filename,cost,reason,prompt,description,agent,snapshot,time);

@override
String toString() {
  return 'MessagePart(id: $id, sessionID: $sessionID, messageID: $messageID, type: $type, text: $text, tool: $tool, callID: $callID, state: $state, mime: $mime, url: $url, filename: $filename, cost: $cost, reason: $reason, prompt: $prompt, description: $description, agent: $agent, snapshot: $snapshot, time: $time)';
}


}

/// @nodoc
abstract mixin class _$MessagePartCopyWith<$Res> implements $MessagePartCopyWith<$Res> {
  factory _$MessagePartCopyWith(_MessagePart value, $Res Function(_MessagePart) _then) = __$MessagePartCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String messageID, String type, String? text, String? tool, String? callID, ToolState? state, String? mime, String? url, String? filename, double? cost, String? reason, String? prompt, String? description, String? agent, String? snapshot, PartTime? time
});


@override $ToolStateCopyWith<$Res>? get state;@override $PartTimeCopyWith<$Res>? get time;

}
/// @nodoc
class __$MessagePartCopyWithImpl<$Res>
    implements _$MessagePartCopyWith<$Res> {
  __$MessagePartCopyWithImpl(this._self, this._then);

  final _MessagePart _self;
  final $Res Function(_MessagePart) _then;

/// Create a copy of MessagePart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? messageID = null,Object? type = null,Object? text = freezed,Object? tool = freezed,Object? callID = freezed,Object? state = freezed,Object? mime = freezed,Object? url = freezed,Object? filename = freezed,Object? cost = freezed,Object? reason = freezed,Object? prompt = freezed,Object? description = freezed,Object? agent = freezed,Object? snapshot = freezed,Object? time = freezed,}) {
  return _then(_MessagePart(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,tool: freezed == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as String?,callID: freezed == callID ? _self.callID : callID // ignore: cast_nullable_to_non_nullable
as String?,state: freezed == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as ToolState?,mime: freezed == mime ? _self.mime : mime // ignore: cast_nullable_to_non_nullable
as String?,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,filename: freezed == filename ? _self.filename : filename // ignore: cast_nullable_to_non_nullable
as String?,cost: freezed == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as double?,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,prompt: freezed == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,snapshot: freezed == snapshot ? _self.snapshot : snapshot // ignore: cast_nullable_to_non_nullable
as String?,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as PartTime?,
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
$PartTimeCopyWith<$Res>? get time {
    if (_self.time == null) {
    return null;
  }

  return $PartTimeCopyWith<$Res>(_self.time!, (value) {
    return _then(_self.copyWith(time: value));
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


/// @nodoc
mixin _$PartTime {

 int? get start; int? get end;
/// Create a copy of PartTime
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PartTimeCopyWith<PartTime> get copyWith => _$PartTimeCopyWithImpl<PartTime>(this as PartTime, _$identity);

  /// Serializes this PartTime to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PartTime&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,start,end);

@override
String toString() {
  return 'PartTime(start: $start, end: $end)';
}


}

/// @nodoc
abstract mixin class $PartTimeCopyWith<$Res>  {
  factory $PartTimeCopyWith(PartTime value, $Res Function(PartTime) _then) = _$PartTimeCopyWithImpl;
@useResult
$Res call({
 int? start, int? end
});




}
/// @nodoc
class _$PartTimeCopyWithImpl<$Res>
    implements $PartTimeCopyWith<$Res> {
  _$PartTimeCopyWithImpl(this._self, this._then);

  final PartTime _self;
  final $Res Function(PartTime) _then;

/// Create a copy of PartTime
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? start = freezed,Object? end = freezed,}) {
  return _then(_self.copyWith(
start: freezed == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as int?,end: freezed == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _PartTime implements PartTime {
  const _PartTime({this.start, this.end});
  factory _PartTime.fromJson(Map<String, dynamic> json) => _$PartTimeFromJson(json);

@override final  int? start;
@override final  int? end;

/// Create a copy of PartTime
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PartTimeCopyWith<_PartTime> get copyWith => __$PartTimeCopyWithImpl<_PartTime>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PartTimeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PartTime&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,start,end);

@override
String toString() {
  return 'PartTime(start: $start, end: $end)';
}


}

/// @nodoc
abstract mixin class _$PartTimeCopyWith<$Res> implements $PartTimeCopyWith<$Res> {
  factory _$PartTimeCopyWith(_PartTime value, $Res Function(_PartTime) _then) = __$PartTimeCopyWithImpl;
@override @useResult
$Res call({
 int? start, int? end
});




}
/// @nodoc
class __$PartTimeCopyWithImpl<$Res>
    implements _$PartTimeCopyWith<$Res> {
  __$PartTimeCopyWithImpl(this._self, this._then);

  final _PartTime _self;
  final $Res Function(_PartTime) _then;

/// Create a copy of PartTime
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? start = freezed,Object? end = freezed,}) {
  return _then(_PartTime(
start: freezed == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as int?,end: freezed == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
