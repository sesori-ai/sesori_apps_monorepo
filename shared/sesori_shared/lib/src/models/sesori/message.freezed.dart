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
Message _$MessageFromJson(
  Map<String, dynamic> json
) {
        switch (json['role']) {
                  case 'user':
          return MessageUser.fromJson(
            json
          );
                case 'assistant':
          return MessageAssistant.fromJson(
            json
          );
                case 'error':
          return MessageError.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'role',
  'Message',
  'Invalid union type "${json['role']}"!'
);
        }
      
}

/// @nodoc
mixin _$Message {

 String get id; String get sessionID; String? get agent; MessageTime? get time;
/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageCopyWith<Message> get copyWith => _$MessageCopyWithImpl<Message>(this as Message, _$identity);

  /// Serializes this Message to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Message&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.time, time) || other.time == time));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,agent,time);

@override
String toString() {
  return 'Message(id: $id, sessionID: $sessionID, agent: $agent, time: $time)';
}


}

/// @nodoc
abstract mixin class $MessageCopyWith<$Res>  {
  factory $MessageCopyWith(Message value, $Res Function(Message) _then) = _$MessageCopyWithImpl;
@useResult
$Res call({
 String id, String sessionID, String? agent, MessageTime? time
});


$MessageTimeCopyWith<$Res>? get time;

}
/// @nodoc
class _$MessageCopyWithImpl<$Res>
    implements $MessageCopyWith<$Res> {
  _$MessageCopyWithImpl(this._self, this._then);

  final Message _self;
  final $Res Function(Message) _then;

/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sessionID = null,Object? agent = freezed,Object? time = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as MessageTime?,
  ));
}
/// Create a copy of Message
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
}
}



/// @nodoc
@JsonSerializable()

class MessageUser extends Message {
  const MessageUser({required this.id, required this.sessionID, required this.agent, required this.time, final  String? $type}): $type = $type ?? 'user',super._();
  factory MessageUser.fromJson(Map<String, dynamic> json) => _$MessageUserFromJson(json);

@override final  String id;
@override final  String sessionID;
@override final  String? agent;
@override final  MessageTime? time;

@JsonKey(name: 'role')
final String $type;


/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageUserCopyWith<MessageUser> get copyWith => _$MessageUserCopyWithImpl<MessageUser>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageUserToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageUser&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.time, time) || other.time == time));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,agent,time);

@override
String toString() {
  return 'Message.user(id: $id, sessionID: $sessionID, agent: $agent, time: $time)';
}


}

/// @nodoc
abstract mixin class $MessageUserCopyWith<$Res> implements $MessageCopyWith<$Res> {
  factory $MessageUserCopyWith(MessageUser value, $Res Function(MessageUser) _then) = _$MessageUserCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String? agent, MessageTime? time
});


@override $MessageTimeCopyWith<$Res>? get time;

}
/// @nodoc
class _$MessageUserCopyWithImpl<$Res>
    implements $MessageUserCopyWith<$Res> {
  _$MessageUserCopyWithImpl(this._self, this._then);

  final MessageUser _self;
  final $Res Function(MessageUser) _then;

/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? agent = freezed,Object? time = freezed,}) {
  return _then(MessageUser(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as MessageTime?,
  ));
}

/// Create a copy of Message
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
}
}

/// @nodoc
@JsonSerializable()

class MessageAssistant extends Message {
  const MessageAssistant({required this.id, required this.sessionID, required this.agent, required this.modelID, required this.providerID, required this.time, final  String? $type}): $type = $type ?? 'assistant',super._();
  factory MessageAssistant.fromJson(Map<String, dynamic> json) => _$MessageAssistantFromJson(json);

@override final  String id;
@override final  String sessionID;
@override final  String? agent;
 final  String? modelID;
 final  String? providerID;
@override final  MessageTime? time;

@JsonKey(name: 'role')
final String $type;


/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageAssistantCopyWith<MessageAssistant> get copyWith => _$MessageAssistantCopyWithImpl<MessageAssistant>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageAssistantToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageAssistant&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.modelID, modelID) || other.modelID == modelID)&&(identical(other.providerID, providerID) || other.providerID == providerID)&&(identical(other.time, time) || other.time == time));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,agent,modelID,providerID,time);

@override
String toString() {
  return 'Message.assistant(id: $id, sessionID: $sessionID, agent: $agent, modelID: $modelID, providerID: $providerID, time: $time)';
}


}

/// @nodoc
abstract mixin class $MessageAssistantCopyWith<$Res> implements $MessageCopyWith<$Res> {
  factory $MessageAssistantCopyWith(MessageAssistant value, $Res Function(MessageAssistant) _then) = _$MessageAssistantCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String? agent, String? modelID, String? providerID, MessageTime? time
});


@override $MessageTimeCopyWith<$Res>? get time;

}
/// @nodoc
class _$MessageAssistantCopyWithImpl<$Res>
    implements $MessageAssistantCopyWith<$Res> {
  _$MessageAssistantCopyWithImpl(this._self, this._then);

  final MessageAssistant _self;
  final $Res Function(MessageAssistant) _then;

/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? agent = freezed,Object? modelID = freezed,Object? providerID = freezed,Object? time = freezed,}) {
  return _then(MessageAssistant(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,modelID: freezed == modelID ? _self.modelID : modelID // ignore: cast_nullable_to_non_nullable
as String?,providerID: freezed == providerID ? _self.providerID : providerID // ignore: cast_nullable_to_non_nullable
as String?,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as MessageTime?,
  ));
}

/// Create a copy of Message
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
}
}

/// @nodoc
@JsonSerializable()

class MessageError extends Message {
  const MessageError({required this.id, required this.sessionID, required this.agent, required this.modelID, required this.providerID, required this.errorName, required this.errorMessage, required this.time, final  String? $type}): $type = $type ?? 'error',super._();
  factory MessageError.fromJson(Map<String, dynamic> json) => _$MessageErrorFromJson(json);

@override final  String id;
@override final  String sessionID;
@override final  String? agent;
 final  String? modelID;
 final  String? providerID;
 final  String errorName;
 final  String errorMessage;
@override final  MessageTime? time;

@JsonKey(name: 'role')
final String $type;


/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageErrorCopyWith<MessageError> get copyWith => _$MessageErrorCopyWithImpl<MessageError>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageErrorToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageError&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.modelID, modelID) || other.modelID == modelID)&&(identical(other.providerID, providerID) || other.providerID == providerID)&&(identical(other.errorName, errorName) || other.errorName == errorName)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.time, time) || other.time == time));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,agent,modelID,providerID,errorName,errorMessage,time);

@override
String toString() {
  return 'Message.error(id: $id, sessionID: $sessionID, agent: $agent, modelID: $modelID, providerID: $providerID, errorName: $errorName, errorMessage: $errorMessage, time: $time)';
}


}

/// @nodoc
abstract mixin class $MessageErrorCopyWith<$Res> implements $MessageCopyWith<$Res> {
  factory $MessageErrorCopyWith(MessageError value, $Res Function(MessageError) _then) = _$MessageErrorCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String? agent, String? modelID, String? providerID, String errorName, String errorMessage, MessageTime? time
});


@override $MessageTimeCopyWith<$Res>? get time;

}
/// @nodoc
class _$MessageErrorCopyWithImpl<$Res>
    implements $MessageErrorCopyWith<$Res> {
  _$MessageErrorCopyWithImpl(this._self, this._then);

  final MessageError _self;
  final $Res Function(MessageError) _then;

/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? agent = freezed,Object? modelID = freezed,Object? providerID = freezed,Object? errorName = null,Object? errorMessage = null,Object? time = freezed,}) {
  return _then(MessageError(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,modelID: freezed == modelID ? _self.modelID : modelID // ignore: cast_nullable_to_non_nullable
as String?,providerID: freezed == providerID ? _self.providerID : providerID // ignore: cast_nullable_to_non_nullable
as String?,errorName: null == errorName ? _self.errorName : errorName // ignore: cast_nullable_to_non_nullable
as String,errorMessage: null == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as MessageTime?,
  ));
}

/// Create a copy of Message
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
  const _MessageTime({required this.created, required this.completed});
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

// dart format on
