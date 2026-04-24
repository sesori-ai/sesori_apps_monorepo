// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Message {

 String get role; String get id; String get sessionID; String? get parentID; String? get agent; String? get modelID; String? get providerID; double? get cost; MessageTokens? get tokens; MessageTime? get time; String? get finish; MessageError? get error;
/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageCopyWith<Message> get copyWith => _$MessageCopyWithImpl<Message>(this as Message, _$identity);

  /// Serializes this Message to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Message&&(identical(other.role, role) || other.role == role)&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.parentID, parentID) || other.parentID == parentID)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.modelID, modelID) || other.modelID == modelID)&&(identical(other.providerID, providerID) || other.providerID == providerID)&&(identical(other.cost, cost) || other.cost == cost)&&(identical(other.tokens, tokens) || other.tokens == tokens)&&(identical(other.time, time) || other.time == time)&&(identical(other.finish, finish) || other.finish == finish)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,role,id,sessionID,parentID,agent,modelID,providerID,cost,tokens,time,finish,error);

@override
String toString() {
  return 'Message(role: $role, id: $id, sessionID: $sessionID, parentID: $parentID, agent: $agent, modelID: $modelID, providerID: $providerID, cost: $cost, tokens: $tokens, time: $time, finish: $finish, error: $error)';
}


}

/// @nodoc
abstract mixin class $MessageCopyWith<$Res>  {
  factory $MessageCopyWith(Message value, $Res Function(Message) _then) = _$MessageCopyWithImpl;
@useResult
$Res call({
 String role, String id, String sessionID, String? parentID, String? agent, String? modelID, String? providerID, double? cost, MessageTokens? tokens, MessageTime? time, String? finish, MessageError? error
});


$MessageTokensCopyWith<$Res>? get tokens;$MessageTimeCopyWith<$Res>? get time;$MessageErrorCopyWith<$Res>? get error;

}
/// @nodoc
class _$MessageCopyWithImpl<$Res>
    implements $MessageCopyWith<$Res> {
  _$MessageCopyWithImpl(this._self, this._then);

  final Message _self;
  final $Res Function(Message) _then;

/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? role = null,Object? id = null,Object? sessionID = null,Object? parentID = freezed,Object? agent = freezed,Object? modelID = freezed,Object? providerID = freezed,Object? cost = freezed,Object? tokens = freezed,Object? time = freezed,Object? finish = freezed,Object? error = freezed,}) {
  return _then(_self.copyWith(
role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,parentID: freezed == parentID ? _self.parentID : parentID // ignore: cast_nullable_to_non_nullable
as String?,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,modelID: freezed == modelID ? _self.modelID : modelID // ignore: cast_nullable_to_non_nullable
as String?,providerID: freezed == providerID ? _self.providerID : providerID // ignore: cast_nullable_to_non_nullable
as String?,cost: freezed == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as double?,tokens: freezed == tokens ? _self.tokens : tokens // ignore: cast_nullable_to_non_nullable
as MessageTokens?,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as MessageTime?,finish: freezed == finish ? _self.finish : finish // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as MessageError?,
  ));
}
/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessageTokensCopyWith<$Res>? get tokens {
    if (_self.tokens == null) {
    return null;
  }

  return $MessageTokensCopyWith<$Res>(_self.tokens!, (value) {
    return _then(_self.copyWith(tokens: value));
  });
}/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessageTimeCopyWith<$Res>? get time {
    if (_self.time == null) {
    return null;
  }

  return $MessageTimeCopyWith<$Res>(_self.time!, (value) {
    return _then(_self.copyWith(time: value));
  });
}/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessageErrorCopyWith<$Res>? get error {
    if (_self.error == null) {
    return null;
  }

  return $MessageErrorCopyWith<$Res>(_self.error!, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _Message implements Message {
  const _Message({required this.role, required this.id, required this.sessionID, this.parentID, this.agent, this.modelID, this.providerID, this.cost, this.tokens, this.time, this.finish, this.error});
  factory _Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);

@override final  String role;
@override final  String id;
@override final  String sessionID;
@override final  String? parentID;
@override final  String? agent;
@override final  String? modelID;
@override final  String? providerID;
@override final  double? cost;
@override final  MessageTokens? tokens;
@override final  MessageTime? time;
@override final  String? finish;
@override final  MessageError? error;

/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageCopyWith<_Message> get copyWith => __$MessageCopyWithImpl<_Message>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Message&&(identical(other.role, role) || other.role == role)&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.parentID, parentID) || other.parentID == parentID)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.modelID, modelID) || other.modelID == modelID)&&(identical(other.providerID, providerID) || other.providerID == providerID)&&(identical(other.cost, cost) || other.cost == cost)&&(identical(other.tokens, tokens) || other.tokens == tokens)&&(identical(other.time, time) || other.time == time)&&(identical(other.finish, finish) || other.finish == finish)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,role,id,sessionID,parentID,agent,modelID,providerID,cost,tokens,time,finish,error);

@override
String toString() {
  return 'Message(role: $role, id: $id, sessionID: $sessionID, parentID: $parentID, agent: $agent, modelID: $modelID, providerID: $providerID, cost: $cost, tokens: $tokens, time: $time, finish: $finish, error: $error)';
}


}

/// @nodoc
abstract mixin class _$MessageCopyWith<$Res> implements $MessageCopyWith<$Res> {
  factory _$MessageCopyWith(_Message value, $Res Function(_Message) _then) = __$MessageCopyWithImpl;
@override @useResult
$Res call({
 String role, String id, String sessionID, String? parentID, String? agent, String? modelID, String? providerID, double? cost, MessageTokens? tokens, MessageTime? time, String? finish, MessageError? error
});


@override $MessageTokensCopyWith<$Res>? get tokens;@override $MessageTimeCopyWith<$Res>? get time;@override $MessageErrorCopyWith<$Res>? get error;

}
/// @nodoc
class __$MessageCopyWithImpl<$Res>
    implements _$MessageCopyWith<$Res> {
  __$MessageCopyWithImpl(this._self, this._then);

  final _Message _self;
  final $Res Function(_Message) _then;

/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? role = null,Object? id = null,Object? sessionID = null,Object? parentID = freezed,Object? agent = freezed,Object? modelID = freezed,Object? providerID = freezed,Object? cost = freezed,Object? tokens = freezed,Object? time = freezed,Object? finish = freezed,Object? error = freezed,}) {
  return _then(_Message(
role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,parentID: freezed == parentID ? _self.parentID : parentID // ignore: cast_nullable_to_non_nullable
as String?,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,modelID: freezed == modelID ? _self.modelID : modelID // ignore: cast_nullable_to_non_nullable
as String?,providerID: freezed == providerID ? _self.providerID : providerID // ignore: cast_nullable_to_non_nullable
as String?,cost: freezed == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as double?,tokens: freezed == tokens ? _self.tokens : tokens // ignore: cast_nullable_to_non_nullable
as MessageTokens?,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as MessageTime?,finish: freezed == finish ? _self.finish : finish // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as MessageError?,
  ));
}

/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessageTokensCopyWith<$Res>? get tokens {
    if (_self.tokens == null) {
    return null;
  }

  return $MessageTokensCopyWith<$Res>(_self.tokens!, (value) {
    return _then(_self.copyWith(tokens: value));
  });
}/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessageTimeCopyWith<$Res>? get time {
    if (_self.time == null) {
    return null;
  }

  return $MessageTimeCopyWith<$Res>(_self.time!, (value) {
    return _then(_self.copyWith(time: value));
  });
}/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessageErrorCopyWith<$Res>? get error {
    if (_self.error == null) {
    return null;
  }

  return $MessageErrorCopyWith<$Res>(_self.error!, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}


/// @nodoc
mixin _$MessageError {

 String get name; MessageErrorData get data;
/// Create a copy of MessageError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageErrorCopyWith<MessageError> get copyWith => _$MessageErrorCopyWithImpl<MessageError>(this as MessageError, _$identity);

  /// Serializes this MessageError to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageError&&(identical(other.name, name) || other.name == name)&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,data);

@override
String toString() {
  return 'MessageError(name: $name, data: $data)';
}


}

/// @nodoc
abstract mixin class $MessageErrorCopyWith<$Res>  {
  factory $MessageErrorCopyWith(MessageError value, $Res Function(MessageError) _then) = _$MessageErrorCopyWithImpl;
@useResult
$Res call({
 String name, MessageErrorData data
});


$MessageErrorDataCopyWith<$Res> get data;

}
/// @nodoc
class _$MessageErrorCopyWithImpl<$Res>
    implements $MessageErrorCopyWith<$Res> {
  _$MessageErrorCopyWithImpl(this._self, this._then);

  final MessageError _self;
  final $Res Function(MessageError) _then;

/// Create a copy of MessageError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? data = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as MessageErrorData,
  ));
}
/// Create a copy of MessageError
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessageErrorDataCopyWith<$Res> get data {
  
  return $MessageErrorDataCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _MessageError implements MessageError {
  const _MessageError({required this.name, required this.data});
  factory _MessageError.fromJson(Map<String, dynamic> json) => _$MessageErrorFromJson(json);

@override final  String name;
@override final  MessageErrorData data;

/// Create a copy of MessageError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageErrorCopyWith<_MessageError> get copyWith => __$MessageErrorCopyWithImpl<_MessageError>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageErrorToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageError&&(identical(other.name, name) || other.name == name)&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,data);

@override
String toString() {
  return 'MessageError(name: $name, data: $data)';
}


}

/// @nodoc
abstract mixin class _$MessageErrorCopyWith<$Res> implements $MessageErrorCopyWith<$Res> {
  factory _$MessageErrorCopyWith(_MessageError value, $Res Function(_MessageError) _then) = __$MessageErrorCopyWithImpl;
@override @useResult
$Res call({
 String name, MessageErrorData data
});


@override $MessageErrorDataCopyWith<$Res> get data;

}
/// @nodoc
class __$MessageErrorCopyWithImpl<$Res>
    implements _$MessageErrorCopyWith<$Res> {
  __$MessageErrorCopyWithImpl(this._self, this._then);

  final _MessageError _self;
  final $Res Function(_MessageError) _then;

/// Create a copy of MessageError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? data = null,}) {
  return _then(_MessageError(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as MessageErrorData,
  ));
}

/// Create a copy of MessageError
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessageErrorDataCopyWith<$Res> get data {
  
  return $MessageErrorDataCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// @nodoc
mixin _$MessageErrorData {

 String get message; String? get responseBody; int? get statusCode; bool? get isRetryable; Map<String, String>? get metadata;
/// Create a copy of MessageErrorData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageErrorDataCopyWith<MessageErrorData> get copyWith => _$MessageErrorDataCopyWithImpl<MessageErrorData>(this as MessageErrorData, _$identity);

  /// Serializes this MessageErrorData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageErrorData&&(identical(other.message, message) || other.message == message)&&(identical(other.responseBody, responseBody) || other.responseBody == responseBody)&&(identical(other.statusCode, statusCode) || other.statusCode == statusCode)&&(identical(other.isRetryable, isRetryable) || other.isRetryable == isRetryable)&&const DeepCollectionEquality().equals(other.metadata, metadata));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,message,responseBody,statusCode,isRetryable,const DeepCollectionEquality().hash(metadata));

@override
String toString() {
  return 'MessageErrorData(message: $message, responseBody: $responseBody, statusCode: $statusCode, isRetryable: $isRetryable, metadata: $metadata)';
}


}

/// @nodoc
abstract mixin class $MessageErrorDataCopyWith<$Res>  {
  factory $MessageErrorDataCopyWith(MessageErrorData value, $Res Function(MessageErrorData) _then) = _$MessageErrorDataCopyWithImpl;
@useResult
$Res call({
 String message, String? responseBody, int? statusCode, bool? isRetryable, Map<String, String>? metadata
});




}
/// @nodoc
class _$MessageErrorDataCopyWithImpl<$Res>
    implements $MessageErrorDataCopyWith<$Res> {
  _$MessageErrorDataCopyWithImpl(this._self, this._then);

  final MessageErrorData _self;
  final $Res Function(MessageErrorData) _then;

/// Create a copy of MessageErrorData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? message = null,Object? responseBody = freezed,Object? statusCode = freezed,Object? isRetryable = freezed,Object? metadata = freezed,}) {
  return _then(_self.copyWith(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,responseBody: freezed == responseBody ? _self.responseBody : responseBody // ignore: cast_nullable_to_non_nullable
as String?,statusCode: freezed == statusCode ? _self.statusCode : statusCode // ignore: cast_nullable_to_non_nullable
as int?,isRetryable: freezed == isRetryable ? _self.isRetryable : isRetryable // ignore: cast_nullable_to_non_nullable
as bool?,metadata: freezed == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _MessageErrorData implements MessageErrorData {
  const _MessageErrorData({required this.message, this.responseBody, this.statusCode, this.isRetryable, final  Map<String, String>? metadata}): _metadata = metadata;
  factory _MessageErrorData.fromJson(Map<String, dynamic> json) => _$MessageErrorDataFromJson(json);

@override final  String message;
@override final  String? responseBody;
@override final  int? statusCode;
@override final  bool? isRetryable;
 final  Map<String, String>? _metadata;
@override Map<String, String>? get metadata {
  final value = _metadata;
  if (value == null) return null;
  if (_metadata is EqualUnmodifiableMapView) return _metadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


/// Create a copy of MessageErrorData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageErrorDataCopyWith<_MessageErrorData> get copyWith => __$MessageErrorDataCopyWithImpl<_MessageErrorData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageErrorDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageErrorData&&(identical(other.message, message) || other.message == message)&&(identical(other.responseBody, responseBody) || other.responseBody == responseBody)&&(identical(other.statusCode, statusCode) || other.statusCode == statusCode)&&(identical(other.isRetryable, isRetryable) || other.isRetryable == isRetryable)&&const DeepCollectionEquality().equals(other._metadata, _metadata));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,message,responseBody,statusCode,isRetryable,const DeepCollectionEquality().hash(_metadata));

@override
String toString() {
  return 'MessageErrorData(message: $message, responseBody: $responseBody, statusCode: $statusCode, isRetryable: $isRetryable, metadata: $metadata)';
}


}

/// @nodoc
abstract mixin class _$MessageErrorDataCopyWith<$Res> implements $MessageErrorDataCopyWith<$Res> {
  factory _$MessageErrorDataCopyWith(_MessageErrorData value, $Res Function(_MessageErrorData) _then) = __$MessageErrorDataCopyWithImpl;
@override @useResult
$Res call({
 String message, String? responseBody, int? statusCode, bool? isRetryable, Map<String, String>? metadata
});




}
/// @nodoc
class __$MessageErrorDataCopyWithImpl<$Res>
    implements _$MessageErrorDataCopyWith<$Res> {
  __$MessageErrorDataCopyWithImpl(this._self, this._then);

  final _MessageErrorData _self;
  final $Res Function(_MessageErrorData) _then;

/// Create a copy of MessageErrorData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? message = null,Object? responseBody = freezed,Object? statusCode = freezed,Object? isRetryable = freezed,Object? metadata = freezed,}) {
  return _then(_MessageErrorData(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,responseBody: freezed == responseBody ? _self.responseBody : responseBody // ignore: cast_nullable_to_non_nullable
as String?,statusCode: freezed == statusCode ? _self.statusCode : statusCode // ignore: cast_nullable_to_non_nullable
as int?,isRetryable: freezed == isRetryable ? _self.isRetryable : isRetryable // ignore: cast_nullable_to_non_nullable
as bool?,metadata: freezed == metadata ? _self._metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,
  ));
}


}


/// @nodoc
mixin _$MessageTime {

 int get created; int? get completed;
/// Create a copy of MessageTime
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageTimeCopyWith<MessageTime> get copyWith => _$MessageTimeCopyWithImpl<MessageTime>(this as MessageTime, _$identity);

  /// Serializes this MessageTime to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageTime&&(identical(other.created, created) || other.created == created)&&(identical(other.completed, completed) || other.completed == completed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,created,completed);

@override
String toString() {
  return 'MessageTime(created: $created, completed: $completed)';
}


}

/// @nodoc
abstract mixin class $MessageTimeCopyWith<$Res>  {
  factory $MessageTimeCopyWith(MessageTime value, $Res Function(MessageTime) _then) = _$MessageTimeCopyWithImpl;
@useResult
$Res call({
 int created, int? completed
});




}
/// @nodoc
class _$MessageTimeCopyWithImpl<$Res>
    implements $MessageTimeCopyWith<$Res> {
  _$MessageTimeCopyWithImpl(this._self, this._then);

  final MessageTime _self;
  final $Res Function(MessageTime) _then;

/// Create a copy of MessageTime
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

class _MessageTime implements MessageTime {
  const _MessageTime({required this.created, this.completed});
  factory _MessageTime.fromJson(Map<String, dynamic> json) => _$MessageTimeFromJson(json);

@override final  int created;
@override final  int? completed;

/// Create a copy of MessageTime
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageTimeCopyWith<_MessageTime> get copyWith => __$MessageTimeCopyWithImpl<_MessageTime>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageTimeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageTime&&(identical(other.created, created) || other.created == created)&&(identical(other.completed, completed) || other.completed == completed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,created,completed);

@override
String toString() {
  return 'MessageTime(created: $created, completed: $completed)';
}


}

/// @nodoc
abstract mixin class _$MessageTimeCopyWith<$Res> implements $MessageTimeCopyWith<$Res> {
  factory _$MessageTimeCopyWith(_MessageTime value, $Res Function(_MessageTime) _then) = __$MessageTimeCopyWithImpl;
@override @useResult
$Res call({
 int created, int? completed
});




}
/// @nodoc
class __$MessageTimeCopyWithImpl<$Res>
    implements _$MessageTimeCopyWith<$Res> {
  __$MessageTimeCopyWithImpl(this._self, this._then);

  final _MessageTime _self;
  final $Res Function(_MessageTime) _then;

/// Create a copy of MessageTime
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? created = null,Object? completed = freezed,}) {
  return _then(_MessageTime(
created: null == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as int,completed: freezed == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$MessageTokens {

 int get input; int get output; int get reasoning; TokenCache? get cache;
/// Create a copy of MessageTokens
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageTokensCopyWith<MessageTokens> get copyWith => _$MessageTokensCopyWithImpl<MessageTokens>(this as MessageTokens, _$identity);

  /// Serializes this MessageTokens to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageTokens&&(identical(other.input, input) || other.input == input)&&(identical(other.output, output) || other.output == output)&&(identical(other.reasoning, reasoning) || other.reasoning == reasoning)&&(identical(other.cache, cache) || other.cache == cache));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,input,output,reasoning,cache);

@override
String toString() {
  return 'MessageTokens(input: $input, output: $output, reasoning: $reasoning, cache: $cache)';
}


}

/// @nodoc
abstract mixin class $MessageTokensCopyWith<$Res>  {
  factory $MessageTokensCopyWith(MessageTokens value, $Res Function(MessageTokens) _then) = _$MessageTokensCopyWithImpl;
@useResult
$Res call({
 int input, int output, int reasoning, TokenCache? cache
});


$TokenCacheCopyWith<$Res>? get cache;

}
/// @nodoc
class _$MessageTokensCopyWithImpl<$Res>
    implements $MessageTokensCopyWith<$Res> {
  _$MessageTokensCopyWithImpl(this._self, this._then);

  final MessageTokens _self;
  final $Res Function(MessageTokens) _then;

/// Create a copy of MessageTokens
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? input = null,Object? output = null,Object? reasoning = null,Object? cache = freezed,}) {
  return _then(_self.copyWith(
input: null == input ? _self.input : input // ignore: cast_nullable_to_non_nullable
as int,output: null == output ? _self.output : output // ignore: cast_nullable_to_non_nullable
as int,reasoning: null == reasoning ? _self.reasoning : reasoning // ignore: cast_nullable_to_non_nullable
as int,cache: freezed == cache ? _self.cache : cache // ignore: cast_nullable_to_non_nullable
as TokenCache?,
  ));
}
/// Create a copy of MessageTokens
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TokenCacheCopyWith<$Res>? get cache {
    if (_self.cache == null) {
    return null;
  }

  return $TokenCacheCopyWith<$Res>(_self.cache!, (value) {
    return _then(_self.copyWith(cache: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _MessageTokens implements MessageTokens {
  const _MessageTokens({this.input = 0, this.output = 0, this.reasoning = 0, this.cache});
  factory _MessageTokens.fromJson(Map<String, dynamic> json) => _$MessageTokensFromJson(json);

@override@JsonKey() final  int input;
@override@JsonKey() final  int output;
@override@JsonKey() final  int reasoning;
@override final  TokenCache? cache;

/// Create a copy of MessageTokens
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageTokensCopyWith<_MessageTokens> get copyWith => __$MessageTokensCopyWithImpl<_MessageTokens>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageTokensToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageTokens&&(identical(other.input, input) || other.input == input)&&(identical(other.output, output) || other.output == output)&&(identical(other.reasoning, reasoning) || other.reasoning == reasoning)&&(identical(other.cache, cache) || other.cache == cache));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,input,output,reasoning,cache);

@override
String toString() {
  return 'MessageTokens(input: $input, output: $output, reasoning: $reasoning, cache: $cache)';
}


}

/// @nodoc
abstract mixin class _$MessageTokensCopyWith<$Res> implements $MessageTokensCopyWith<$Res> {
  factory _$MessageTokensCopyWith(_MessageTokens value, $Res Function(_MessageTokens) _then) = __$MessageTokensCopyWithImpl;
@override @useResult
$Res call({
 int input, int output, int reasoning, TokenCache? cache
});


@override $TokenCacheCopyWith<$Res>? get cache;

}
/// @nodoc
class __$MessageTokensCopyWithImpl<$Res>
    implements _$MessageTokensCopyWith<$Res> {
  __$MessageTokensCopyWithImpl(this._self, this._then);

  final _MessageTokens _self;
  final $Res Function(_MessageTokens) _then;

/// Create a copy of MessageTokens
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? input = null,Object? output = null,Object? reasoning = null,Object? cache = freezed,}) {
  return _then(_MessageTokens(
input: null == input ? _self.input : input // ignore: cast_nullable_to_non_nullable
as int,output: null == output ? _self.output : output // ignore: cast_nullable_to_non_nullable
as int,reasoning: null == reasoning ? _self.reasoning : reasoning // ignore: cast_nullable_to_non_nullable
as int,cache: freezed == cache ? _self.cache : cache // ignore: cast_nullable_to_non_nullable
as TokenCache?,
  ));
}

/// Create a copy of MessageTokens
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TokenCacheCopyWith<$Res>? get cache {
    if (_self.cache == null) {
    return null;
  }

  return $TokenCacheCopyWith<$Res>(_self.cache!, (value) {
    return _then(_self.copyWith(cache: value));
  });
}
}


/// @nodoc
mixin _$TokenCache {

 int get read; int get write;
/// Create a copy of TokenCache
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TokenCacheCopyWith<TokenCache> get copyWith => _$TokenCacheCopyWithImpl<TokenCache>(this as TokenCache, _$identity);

  /// Serializes this TokenCache to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TokenCache&&(identical(other.read, read) || other.read == read)&&(identical(other.write, write) || other.write == write));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,read,write);

@override
String toString() {
  return 'TokenCache(read: $read, write: $write)';
}


}

/// @nodoc
abstract mixin class $TokenCacheCopyWith<$Res>  {
  factory $TokenCacheCopyWith(TokenCache value, $Res Function(TokenCache) _then) = _$TokenCacheCopyWithImpl;
@useResult
$Res call({
 int read, int write
});




}
/// @nodoc
class _$TokenCacheCopyWithImpl<$Res>
    implements $TokenCacheCopyWith<$Res> {
  _$TokenCacheCopyWithImpl(this._self, this._then);

  final TokenCache _self;
  final $Res Function(TokenCache) _then;

/// Create a copy of TokenCache
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? read = null,Object? write = null,}) {
  return _then(_self.copyWith(
read: null == read ? _self.read : read // ignore: cast_nullable_to_non_nullable
as int,write: null == write ? _self.write : write // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _TokenCache implements TokenCache {
  const _TokenCache({this.read = 0, this.write = 0});
  factory _TokenCache.fromJson(Map<String, dynamic> json) => _$TokenCacheFromJson(json);

@override@JsonKey() final  int read;
@override@JsonKey() final  int write;

/// Create a copy of TokenCache
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TokenCacheCopyWith<_TokenCache> get copyWith => __$TokenCacheCopyWithImpl<_TokenCache>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TokenCacheToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TokenCache&&(identical(other.read, read) || other.read == read)&&(identical(other.write, write) || other.write == write));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,read,write);

@override
String toString() {
  return 'TokenCache(read: $read, write: $write)';
}


}

/// @nodoc
abstract mixin class _$TokenCacheCopyWith<$Res> implements $TokenCacheCopyWith<$Res> {
  factory _$TokenCacheCopyWith(_TokenCache value, $Res Function(_TokenCache) _then) = __$TokenCacheCopyWithImpl;
@override @useResult
$Res call({
 int read, int write
});




}
/// @nodoc
class __$TokenCacheCopyWithImpl<$Res>
    implements _$TokenCacheCopyWith<$Res> {
  __$TokenCacheCopyWithImpl(this._self, this._then);

  final _TokenCache _self;
  final $Res Function(_TokenCache) _then;

/// Create a copy of TokenCache
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? read = null,Object? write = null,}) {
  return _then(_TokenCache(
read: null == read ? _self.read : read // ignore: cast_nullable_to_non_nullable
as int,write: null == write ? _self.write : write // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
