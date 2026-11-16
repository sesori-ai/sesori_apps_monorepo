// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'active_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ActiveSession {

 String get id; bool get mainAgentRunning; bool get awaitingInput; List<String> get childSessionIds; bool get isRetrying; int? get lastUserActivityAt; int? get updatedAt;/// The send of this session into another that the bridge is running, or
/// null when it sends none. Bridges that predate it omit it, which reads
/// as not sending.
 ActiveSessionSending? get sending;
/// Create a copy of ActiveSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ActiveSessionCopyWith<ActiveSession> get copyWith => _$ActiveSessionCopyWithImpl<ActiveSession>(this as ActiveSession, _$identity);

  /// Serializes this ActiveSession to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ActiveSession;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ActiveSession&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.mainAgentRunning, _this.mainAgentRunning) || other.mainAgentRunning == _this.mainAgentRunning)&&(identical(other.awaitingInput, _this.awaitingInput) || other.awaitingInput == _this.awaitingInput)&&const DeepCollectionEquality().equals(other.childSessionIds, _this.childSessionIds)&&(identical(other.isRetrying, _this.isRetrying) || other.isRetrying == _this.isRetrying)&&(identical(other.lastUserActivityAt, _this.lastUserActivityAt) || other.lastUserActivityAt == _this.lastUserActivityAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.sending, _this.sending) || other.sending == _this.sending));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ActiveSession;
  return Object.hash(runtimeType,_this.id,_this.mainAgentRunning,_this.awaitingInput,const DeepCollectionEquality().hash(_this.childSessionIds),_this.isRetrying,_this.lastUserActivityAt,_this.updatedAt,_this.sending);
}

@override
String toString() {
  final _this = this as ActiveSession;
  return 'ActiveSession(id: ${_this.id}, mainAgentRunning: ${_this.mainAgentRunning}, awaitingInput: ${_this.awaitingInput}, childSessionIds: ${_this.childSessionIds}, isRetrying: ${_this.isRetrying}, lastUserActivityAt: ${_this.lastUserActivityAt}, updatedAt: ${_this.updatedAt}, sending: ${_this.sending})';
}


}

/// @nodoc
abstract mixin class $ActiveSessionCopyWith<$Res>  {
  factory $ActiveSessionCopyWith(ActiveSession value, $Res Function(ActiveSession) _then) = _$ActiveSessionCopyWithImpl;
@useResult
$Res call({
 String id, bool mainAgentRunning, bool awaitingInput, List<String> childSessionIds, bool isRetrying, int? lastUserActivityAt, int? updatedAt, ActiveSessionSending? sending
});


$ActiveSessionSendingCopyWith<$Res>? get sending;

}
/// @nodoc
class _$ActiveSessionCopyWithImpl<$Res>
    implements $ActiveSessionCopyWith<$Res> {
  _$ActiveSessionCopyWithImpl(this._self, this._then);

  final ActiveSession _self;
  final $Res Function(ActiveSession) _then;

/// Create a copy of ActiveSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? mainAgentRunning = null,Object? awaitingInput = null,Object? childSessionIds = null,Object? isRetrying = null,Object? lastUserActivityAt = freezed,Object? updatedAt = freezed,Object? sending = freezed,}) {
  return _then(ActiveSession(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,mainAgentRunning: null == mainAgentRunning ? _self.mainAgentRunning : mainAgentRunning // ignore: cast_nullable_to_non_nullable
as bool,awaitingInput: null == awaitingInput ? _self.awaitingInput : awaitingInput // ignore: cast_nullable_to_non_nullable
as bool,childSessionIds: null == childSessionIds ? _self.childSessionIds : childSessionIds // ignore: cast_nullable_to_non_nullable
as List<String>,isRetrying: null == isRetrying ? _self.isRetrying : isRetrying // ignore: cast_nullable_to_non_nullable
as bool,lastUserActivityAt: freezed == lastUserActivityAt ? _self.lastUserActivityAt : lastUserActivityAt // ignore: cast_nullable_to_non_nullable
as int?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int?,sending: freezed == sending ? _self.sending : sending // ignore: cast_nullable_to_non_nullable
as ActiveSessionSending?,
  ));
}
/// Create a copy of ActiveSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActiveSessionSendingCopyWith<$Res>? get sending {
    if (_self.sending == null) {
    return null;
  }

  return $ActiveSessionSendingCopyWith<$Res>(_self.sending!, (value) {
    return _then(_self.copyWith(sending: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _ActiveSession implements ActiveSession {
  const _ActiveSession({required this.id, this.mainAgentRunning = false, this.awaitingInput = false,  List<String> childSessionIds = const [], this.isRetrying = false, required this.lastUserActivityAt, required this.updatedAt, required this.sending}): _childSessionIds = childSessionIds;
  factory _ActiveSession.fromJson(Map<String, dynamic> json) => _$ActiveSessionFromJson(json);

@override final  String id;
@override@JsonKey() final  bool mainAgentRunning;
@override@JsonKey() final  bool awaitingInput;
 final  List<String> _childSessionIds;
@override@JsonKey() List<String> get childSessionIds {
  if (_childSessionIds is EqualUnmodifiableListView) return _childSessionIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_childSessionIds);
}

@override@JsonKey() final  bool isRetrying;
@override final  int? lastUserActivityAt;
@override final  int? updatedAt;
/// The send of this session into another that the bridge is running, or
/// null when it sends none. Bridges that predate it omit it, which reads
/// as not sending.
@override final  ActiveSessionSending? sending;

/// Create a copy of ActiveSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ActiveSessionCopyWith<_ActiveSession> get copyWith => __$ActiveSessionCopyWithImpl<_ActiveSession>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ActiveSessionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ActiveSession&&(identical(other.id, id) || other.id == id)&&(identical(other.mainAgentRunning, mainAgentRunning) || other.mainAgentRunning == mainAgentRunning)&&(identical(other.awaitingInput, awaitingInput) || other.awaitingInput == awaitingInput)&&const DeepCollectionEquality().equals(other.childSessionIds, _childSessionIds)&&(identical(other.isRetrying, isRetrying) || other.isRetrying == isRetrying)&&(identical(other.lastUserActivityAt, lastUserActivityAt) || other.lastUserActivityAt == lastUserActivityAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.sending, sending) || other.sending == sending));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,mainAgentRunning,awaitingInput,const DeepCollectionEquality().hash(_childSessionIds),isRetrying,lastUserActivityAt,updatedAt,sending);
}

@override
String toString() {
    return 'ActiveSession(id: $id, mainAgentRunning: $mainAgentRunning, awaitingInput: $awaitingInput, childSessionIds: $childSessionIds, isRetrying: $isRetrying, lastUserActivityAt: $lastUserActivityAt, updatedAt: $updatedAt, sending: $sending)';
}


}

/// @nodoc
abstract mixin class _$ActiveSessionCopyWith<$Res> implements $ActiveSessionCopyWith<$Res> {
  factory _$ActiveSessionCopyWith(_ActiveSession value, $Res Function(_ActiveSession) _then) = __$ActiveSessionCopyWithImpl;
@override @useResult
$Res call({
 String id, bool mainAgentRunning, bool awaitingInput, List<String> childSessionIds, bool isRetrying, int? lastUserActivityAt, int? updatedAt, ActiveSessionSending? sending
});


@override $ActiveSessionSendingCopyWith<$Res>? get sending;

}
/// @nodoc
class __$ActiveSessionCopyWithImpl<$Res>
    implements _$ActiveSessionCopyWith<$Res> {
  __$ActiveSessionCopyWithImpl(this._self, this._then);

  final _ActiveSession _self;
  final $Res Function(_ActiveSession) _then;

/// Create a copy of ActiveSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? mainAgentRunning = null,Object? awaitingInput = null,Object? childSessionIds = null,Object? isRetrying = null,Object? lastUserActivityAt = freezed,Object? updatedAt = freezed,Object? sending = freezed,}) {
  return _then(_ActiveSession(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,mainAgentRunning: null == mainAgentRunning ? _self.mainAgentRunning : mainAgentRunning // ignore: cast_nullable_to_non_nullable
as bool,awaitingInput: null == awaitingInput ? _self.awaitingInput : awaitingInput // ignore: cast_nullable_to_non_nullable
as bool,childSessionIds: null == childSessionIds ? _self._childSessionIds : childSessionIds // ignore: cast_nullable_to_non_nullable
as List<String>,isRetrying: null == isRetrying ? _self.isRetrying : isRetrying // ignore: cast_nullable_to_non_nullable
as bool,lastUserActivityAt: freezed == lastUserActivityAt ? _self.lastUserActivityAt : lastUserActivityAt // ignore: cast_nullable_to_non_nullable
as int?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int?,sending: freezed == sending ? _self.sending : sending // ignore: cast_nullable_to_non_nullable
as ActiveSessionSending?,
  ));
}

/// Create a copy of ActiveSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActiveSessionSendingCopyWith<$Res>? get sending {
    if (_self.sending == null) {
    return null;
  }

  return $ActiveSessionSendingCopyWith<$Res>(_self.sending!, (value) {
    return _then(_self.copyWith(sending: value));
  });
}
}


/// @nodoc
mixin _$ActiveSessionSending {

/// The target's title when the send started; null when it had none.
 String? get targetTitle;
/// Create a copy of ActiveSessionSending
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ActiveSessionSendingCopyWith<ActiveSessionSending> get copyWith => _$ActiveSessionSendingCopyWithImpl<ActiveSessionSending>(this as ActiveSessionSending, _$identity);

  /// Serializes this ActiveSessionSending to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ActiveSessionSending;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ActiveSessionSending&&(identical(other.targetTitle, _this.targetTitle) || other.targetTitle == _this.targetTitle));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ActiveSessionSending;
  return Object.hash(runtimeType,_this.targetTitle);
}

@override
String toString() {
  final _this = this as ActiveSessionSending;
  return 'ActiveSessionSending(targetTitle: ${_this.targetTitle})';
}


}

/// @nodoc
abstract mixin class $ActiveSessionSendingCopyWith<$Res>  {
  factory $ActiveSessionSendingCopyWith(ActiveSessionSending value, $Res Function(ActiveSessionSending) _then) = _$ActiveSessionSendingCopyWithImpl;
@useResult
$Res call({
 String? targetTitle
});




}
/// @nodoc
class _$ActiveSessionSendingCopyWithImpl<$Res>
    implements $ActiveSessionSendingCopyWith<$Res> {
  _$ActiveSessionSendingCopyWithImpl(this._self, this._then);

  final ActiveSessionSending _self;
  final $Res Function(ActiveSessionSending) _then;

/// Create a copy of ActiveSessionSending
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? targetTitle = freezed,}) {
  return _then(ActiveSessionSending(
targetTitle: freezed == targetTitle ? _self.targetTitle : targetTitle // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _ActiveSessionSending implements ActiveSessionSending {
  const _ActiveSessionSending({required this.targetTitle});
  factory _ActiveSessionSending.fromJson(Map<String, dynamic> json) => _$ActiveSessionSendingFromJson(json);

/// The target's title when the send started; null when it had none.
@override final  String? targetTitle;

/// Create a copy of ActiveSessionSending
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ActiveSessionSendingCopyWith<_ActiveSessionSending> get copyWith => __$ActiveSessionSendingCopyWithImpl<_ActiveSessionSending>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ActiveSessionSendingToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ActiveSessionSending&&(identical(other.targetTitle, targetTitle) || other.targetTitle == targetTitle));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,targetTitle);
}

@override
String toString() {
    return 'ActiveSessionSending(targetTitle: $targetTitle)';
}


}

/// @nodoc
abstract mixin class _$ActiveSessionSendingCopyWith<$Res> implements $ActiveSessionSendingCopyWith<$Res> {
  factory _$ActiveSessionSendingCopyWith(_ActiveSessionSending value, $Res Function(_ActiveSessionSending) _then) = __$ActiveSessionSendingCopyWithImpl;
@override @useResult
$Res call({
 String? targetTitle
});




}
/// @nodoc
class __$ActiveSessionSendingCopyWithImpl<$Res>
    implements _$ActiveSessionSendingCopyWith<$Res> {
  __$ActiveSessionSendingCopyWithImpl(this._self, this._then);

  final _ActiveSessionSending _self;
  final $Res Function(_ActiveSessionSending) _then;

/// Create a copy of ActiveSessionSending
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? targetTitle = freezed,}) {
  return _then(_ActiveSessionSending(
targetTitle: freezed == targetTitle ? _self.targetTitle : targetTitle // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
