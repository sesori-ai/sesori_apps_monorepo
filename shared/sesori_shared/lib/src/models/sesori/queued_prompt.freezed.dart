// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'queued_prompt.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$QueuedSessionPrompt {

/// The prompt id: client-supplied `SendPromptRequest.promptId`, or a
/// bridge-generated fallback for clients that predate it.
 String get id;/// User-visible prompt text. Null for an attachment-only prompt — never
/// an empty string.
 String? get text;/// Bare slash-command name for a command send, without the leading `/`.
/// Null for a plain prompt.
 String? get command;/// Number of file attachments carried by the prompt.
 int get attachmentCount;/// Bridge acceptance time in milliseconds since the Unix epoch.
 int get createdAt;
/// Create a copy of QueuedSessionPrompt
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QueuedSessionPromptCopyWith<QueuedSessionPrompt> get copyWith => _$QueuedSessionPromptCopyWithImpl<QueuedSessionPrompt>(this as QueuedSessionPrompt, _$identity);

  /// Serializes this QueuedSessionPrompt to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QueuedSessionPrompt&&(identical(other.id, id) || other.id == id)&&(identical(other.text, text) || other.text == text)&&(identical(other.command, command) || other.command == command)&&(identical(other.attachmentCount, attachmentCount) || other.attachmentCount == attachmentCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,text,command,attachmentCount,createdAt);

@override
String toString() {
  return 'QueuedSessionPrompt(id: $id, text: $text, command: $command, attachmentCount: $attachmentCount, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $QueuedSessionPromptCopyWith<$Res>  {
  factory $QueuedSessionPromptCopyWith(QueuedSessionPrompt value, $Res Function(QueuedSessionPrompt) _then) = _$QueuedSessionPromptCopyWithImpl;
@useResult
$Res call({
 String id, String? text, String? command, int attachmentCount, int createdAt
});




}
/// @nodoc
class _$QueuedSessionPromptCopyWithImpl<$Res>
    implements $QueuedSessionPromptCopyWith<$Res> {
  _$QueuedSessionPromptCopyWithImpl(this._self, this._then);

  final QueuedSessionPrompt _self;
  final $Res Function(QueuedSessionPrompt) _then;

/// Create a copy of QueuedSessionPrompt
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? text = freezed,Object? command = freezed,Object? attachmentCount = null,Object? createdAt = null,}) {
  return _then(QueuedSessionPrompt(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,command: freezed == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String?,attachmentCount: null == attachmentCount ? _self.attachmentCount : attachmentCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _QueuedSessionPrompt implements QueuedSessionPrompt {
  const _QueuedSessionPrompt({required this.id, required this.text, required this.command, this.attachmentCount = 0, required this.createdAt});
  factory _QueuedSessionPrompt.fromJson(Map<String, dynamic> json) => _$QueuedSessionPromptFromJson(json);

/// The prompt id: client-supplied `SendPromptRequest.promptId`, or a
/// bridge-generated fallback for clients that predate it.
@override final  String id;
/// User-visible prompt text. Null for an attachment-only prompt — never
/// an empty string.
@override final  String? text;
/// Bare slash-command name for a command send, without the leading `/`.
/// Null for a plain prompt.
@override final  String? command;
/// Number of file attachments carried by the prompt.
@override@JsonKey() final  int attachmentCount;
/// Bridge acceptance time in milliseconds since the Unix epoch.
@override final  int createdAt;

/// Create a copy of QueuedSessionPrompt
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QueuedSessionPromptCopyWith<_QueuedSessionPrompt> get copyWith => __$QueuedSessionPromptCopyWithImpl<_QueuedSessionPrompt>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QueuedSessionPromptToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QueuedSessionPrompt&&(identical(other.id, id) || other.id == id)&&(identical(other.text, text) || other.text == text)&&(identical(other.command, command) || other.command == command)&&(identical(other.attachmentCount, attachmentCount) || other.attachmentCount == attachmentCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,text,command,attachmentCount,createdAt);

@override
String toString() {
  return 'QueuedSessionPrompt(id: $id, text: $text, command: $command, attachmentCount: $attachmentCount, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$QueuedSessionPromptCopyWith<$Res> implements $QueuedSessionPromptCopyWith<$Res> {
  factory _$QueuedSessionPromptCopyWith(_QueuedSessionPrompt value, $Res Function(_QueuedSessionPrompt) _then) = __$QueuedSessionPromptCopyWithImpl;
@override @useResult
$Res call({
 String id, String? text, String? command, int attachmentCount, int createdAt
});




}
/// @nodoc
class __$QueuedSessionPromptCopyWithImpl<$Res>
    implements _$QueuedSessionPromptCopyWith<$Res> {
  __$QueuedSessionPromptCopyWithImpl(this._self, this._then);

  final _QueuedSessionPrompt _self;
  final $Res Function(_QueuedSessionPrompt) _then;

/// Create a copy of QueuedSessionPrompt
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? text = freezed,Object? command = freezed,Object? attachmentCount = null,Object? createdAt = null,}) {
  return _then(_QueuedSessionPrompt(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,command: freezed == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String?,attachmentCount: null == attachmentCount ? _self.attachmentCount : attachmentCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$QueuedPromptResponse {

 List<QueuedSessionPrompt> get data;
/// Create a copy of QueuedPromptResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QueuedPromptResponseCopyWith<QueuedPromptResponse> get copyWith => _$QueuedPromptResponseCopyWithImpl<QueuedPromptResponse>(this as QueuedPromptResponse, _$identity);

  /// Serializes this QueuedPromptResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QueuedPromptResponse&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'QueuedPromptResponse(data: $data)';
}


}

/// @nodoc
abstract mixin class $QueuedPromptResponseCopyWith<$Res>  {
  factory $QueuedPromptResponseCopyWith(QueuedPromptResponse value, $Res Function(QueuedPromptResponse) _then) = _$QueuedPromptResponseCopyWithImpl;
@useResult
$Res call({
 List<QueuedSessionPrompt> data
});




}
/// @nodoc
class _$QueuedPromptResponseCopyWithImpl<$Res>
    implements $QueuedPromptResponseCopyWith<$Res> {
  _$QueuedPromptResponseCopyWithImpl(this._self, this._then);

  final QueuedPromptResponse _self;
  final $Res Function(QueuedPromptResponse) _then;

/// Create a copy of QueuedPromptResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(QueuedPromptResponse(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<QueuedSessionPrompt>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _QueuedPromptResponse implements QueuedPromptResponse {
  const _QueuedPromptResponse({required  List<QueuedSessionPrompt> data}): _data = data;
  factory _QueuedPromptResponse.fromJson(Map<String, dynamic> json) => _$QueuedPromptResponseFromJson(json);

 final  List<QueuedSessionPrompt> _data;
@override List<QueuedSessionPrompt> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of QueuedPromptResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QueuedPromptResponseCopyWith<_QueuedPromptResponse> get copyWith => __$QueuedPromptResponseCopyWithImpl<_QueuedPromptResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QueuedPromptResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QueuedPromptResponse&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'QueuedPromptResponse(data: $data)';
}


}

/// @nodoc
abstract mixin class _$QueuedPromptResponseCopyWith<$Res> implements $QueuedPromptResponseCopyWith<$Res> {
  factory _$QueuedPromptResponseCopyWith(_QueuedPromptResponse value, $Res Function(_QueuedPromptResponse) _then) = __$QueuedPromptResponseCopyWithImpl;
@override @useResult
$Res call({
 List<QueuedSessionPrompt> data
});




}
/// @nodoc
class __$QueuedPromptResponseCopyWithImpl<$Res>
    implements _$QueuedPromptResponseCopyWith<$Res> {
  __$QueuedPromptResponseCopyWithImpl(this._self, this._then);

  final _QueuedPromptResponse _self;
  final $Res Function(_QueuedPromptResponse) _then;

/// Create a copy of QueuedPromptResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_QueuedPromptResponse(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<QueuedSessionPrompt>,
  ));
}


}


/// @nodoc
mixin _$CancelQueuedPromptRequest {

 String get sessionId; String get promptId;
/// Create a copy of CancelQueuedPromptRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CancelQueuedPromptRequestCopyWith<CancelQueuedPromptRequest> get copyWith => _$CancelQueuedPromptRequestCopyWithImpl<CancelQueuedPromptRequest>(this as CancelQueuedPromptRequest, _$identity);

  /// Serializes this CancelQueuedPromptRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CancelQueuedPromptRequest&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.promptId, promptId) || other.promptId == promptId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,promptId);

@override
String toString() {
  return 'CancelQueuedPromptRequest(sessionId: $sessionId, promptId: $promptId)';
}


}

/// @nodoc
abstract mixin class $CancelQueuedPromptRequestCopyWith<$Res>  {
  factory $CancelQueuedPromptRequestCopyWith(CancelQueuedPromptRequest value, $Res Function(CancelQueuedPromptRequest) _then) = _$CancelQueuedPromptRequestCopyWithImpl;
@useResult
$Res call({
 String sessionId, String promptId
});




}
/// @nodoc
class _$CancelQueuedPromptRequestCopyWithImpl<$Res>
    implements $CancelQueuedPromptRequestCopyWith<$Res> {
  _$CancelQueuedPromptRequestCopyWithImpl(this._self, this._then);

  final CancelQueuedPromptRequest _self;
  final $Res Function(CancelQueuedPromptRequest) _then;

/// Create a copy of CancelQueuedPromptRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? promptId = null,}) {
  return _then(CancelQueuedPromptRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,promptId: null == promptId ? _self.promptId : promptId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _CancelQueuedPromptRequest implements CancelQueuedPromptRequest {
  const _CancelQueuedPromptRequest({required this.sessionId, required this.promptId});
  factory _CancelQueuedPromptRequest.fromJson(Map<String, dynamic> json) => _$CancelQueuedPromptRequestFromJson(json);

@override final  String sessionId;
@override final  String promptId;

/// Create a copy of CancelQueuedPromptRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CancelQueuedPromptRequestCopyWith<_CancelQueuedPromptRequest> get copyWith => __$CancelQueuedPromptRequestCopyWithImpl<_CancelQueuedPromptRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CancelQueuedPromptRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CancelQueuedPromptRequest&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.promptId, promptId) || other.promptId == promptId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,promptId);

@override
String toString() {
  return 'CancelQueuedPromptRequest(sessionId: $sessionId, promptId: $promptId)';
}


}

/// @nodoc
abstract mixin class _$CancelQueuedPromptRequestCopyWith<$Res> implements $CancelQueuedPromptRequestCopyWith<$Res> {
  factory _$CancelQueuedPromptRequestCopyWith(_CancelQueuedPromptRequest value, $Res Function(_CancelQueuedPromptRequest) _then) = __$CancelQueuedPromptRequestCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, String promptId
});




}
/// @nodoc
class __$CancelQueuedPromptRequestCopyWithImpl<$Res>
    implements _$CancelQueuedPromptRequestCopyWith<$Res> {
  __$CancelQueuedPromptRequestCopyWithImpl(this._self, this._then);

  final _CancelQueuedPromptRequest _self;
  final $Res Function(_CancelQueuedPromptRequest) _then;

/// Create a copy of CancelQueuedPromptRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? promptId = null,}) {
  return _then(_CancelQueuedPromptRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,promptId: null == promptId ? _self.promptId : promptId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
