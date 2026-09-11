// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'abort_session_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AbortSessionRequest {

 String get sessionId; SessionAbortSubAgentPolicy get subAgents; bool get useAtomicStop;
/// Create a copy of AbortSessionRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AbortSessionRequestCopyWith<AbortSessionRequest> get copyWith => _$AbortSessionRequestCopyWithImpl<AbortSessionRequest>(this as AbortSessionRequest, _$identity);

  /// Serializes this AbortSessionRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AbortSessionRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AbortSessionRequest&&(identical(other.sessionId, _this.sessionId) || other.sessionId == _this.sessionId)&&(identical(other.subAgents, _this.subAgents) || other.subAgents == _this.subAgents)&&(identical(other.useAtomicStop, _this.useAtomicStop) || other.useAtomicStop == _this.useAtomicStop));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AbortSessionRequest;
  return Object.hash(runtimeType,_this.sessionId,_this.subAgents,_this.useAtomicStop);
}

@override
String toString() {
  final _this = this as AbortSessionRequest;
  return 'AbortSessionRequest(sessionId: ${_this.sessionId}, subAgents: ${_this.subAgents}, useAtomicStop: ${_this.useAtomicStop})';
}


}

/// @nodoc
abstract mixin class $AbortSessionRequestCopyWith<$Res>  {
  factory $AbortSessionRequestCopyWith(AbortSessionRequest value, $Res Function(AbortSessionRequest) _then) = _$AbortSessionRequestCopyWithImpl;
@useResult
$Res call({
 String sessionId, SessionAbortSubAgentPolicy subAgents, bool useAtomicStop
});




}
/// @nodoc
class _$AbortSessionRequestCopyWithImpl<$Res>
    implements $AbortSessionRequestCopyWith<$Res> {
  _$AbortSessionRequestCopyWithImpl(this._self, this._then);

  final AbortSessionRequest _self;
  final $Res Function(AbortSessionRequest) _then;

/// Create a copy of AbortSessionRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? subAgents = null,Object? useAtomicStop = null,}) {
  return _then(AbortSessionRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,subAgents: null == subAgents ? _self.subAgents : subAgents // ignore: cast_nullable_to_non_nullable
as SessionAbortSubAgentPolicy,useAtomicStop: null == useAtomicStop ? _self.useAtomicStop : useAtomicStop // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _AbortSessionRequest implements AbortSessionRequest {
  const _AbortSessionRequest({required this.sessionId, this.subAgents = SessionAbortSubAgentPolicy.stop, this.useAtomicStop = false});
  factory _AbortSessionRequest.fromJson(Map<String, dynamic> json) => _$AbortSessionRequestFromJson(json);

@override final  String sessionId;
@override@JsonKey() final  SessionAbortSubAgentPolicy subAgents;
@override@JsonKey() final  bool useAtomicStop;

/// Create a copy of AbortSessionRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AbortSessionRequestCopyWith<_AbortSessionRequest> get copyWith => __$AbortSessionRequestCopyWithImpl<_AbortSessionRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AbortSessionRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AbortSessionRequest&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.subAgents, subAgents) || other.subAgents == subAgents)&&(identical(other.useAtomicStop, useAtomicStop) || other.useAtomicStop == useAtomicStop));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sessionId,subAgents,useAtomicStop);
}

@override
String toString() {
    return 'AbortSessionRequest(sessionId: $sessionId, subAgents: $subAgents, useAtomicStop: $useAtomicStop)';
}


}

/// @nodoc
abstract mixin class _$AbortSessionRequestCopyWith<$Res> implements $AbortSessionRequestCopyWith<$Res> {
  factory _$AbortSessionRequestCopyWith(_AbortSessionRequest value, $Res Function(_AbortSessionRequest) _then) = __$AbortSessionRequestCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, SessionAbortSubAgentPolicy subAgents, bool useAtomicStop
});




}
/// @nodoc
class __$AbortSessionRequestCopyWithImpl<$Res>
    implements _$AbortSessionRequestCopyWith<$Res> {
  __$AbortSessionRequestCopyWithImpl(this._self, this._then);

  final _AbortSessionRequest _self;
  final $Res Function(_AbortSessionRequest) _then;

/// Create a copy of AbortSessionRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? subAgents = null,Object? useAtomicStop = null,}) {
  return _then(_AbortSessionRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,subAgents: null == subAgents ? _self.subAgents : subAgents // ignore: cast_nullable_to_non_nullable
as SessionAbortSubAgentPolicy,useAtomicStop: null == useAtomicStop ? _self.useAtomicStop : useAtomicStop // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$SessionAbortResponse {

 bool get subAgentsHandled;
/// Create a copy of SessionAbortResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionAbortResponseCopyWith<SessionAbortResponse> get copyWith => _$SessionAbortResponseCopyWithImpl<SessionAbortResponse>(this as SessionAbortResponse, _$identity);

  /// Serializes this SessionAbortResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SessionAbortResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionAbortResponse&&(identical(other.subAgentsHandled, _this.subAgentsHandled) || other.subAgentsHandled == _this.subAgentsHandled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SessionAbortResponse;
  return Object.hash(runtimeType,_this.subAgentsHandled);
}

@override
String toString() {
  final _this = this as SessionAbortResponse;
  return 'SessionAbortResponse(subAgentsHandled: ${_this.subAgentsHandled})';
}


}

/// @nodoc
abstract mixin class $SessionAbortResponseCopyWith<$Res>  {
  factory $SessionAbortResponseCopyWith(SessionAbortResponse value, $Res Function(SessionAbortResponse) _then) = _$SessionAbortResponseCopyWithImpl;
@useResult
$Res call({
 bool subAgentsHandled
});




}
/// @nodoc
class _$SessionAbortResponseCopyWithImpl<$Res>
    implements $SessionAbortResponseCopyWith<$Res> {
  _$SessionAbortResponseCopyWithImpl(this._self, this._then);

  final SessionAbortResponse _self;
  final $Res Function(SessionAbortResponse) _then;

/// Create a copy of SessionAbortResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? subAgentsHandled = null,}) {
  return _then(SessionAbortResponse(
subAgentsHandled: null == subAgentsHandled ? _self.subAgentsHandled : subAgentsHandled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SessionAbortResponse implements SessionAbortResponse {
  const _SessionAbortResponse({this.subAgentsHandled = false});
  factory _SessionAbortResponse.fromJson(Map<String, dynamic> json) => _$SessionAbortResponseFromJson(json);

@override@JsonKey() final  bool subAgentsHandled;

/// Create a copy of SessionAbortResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionAbortResponseCopyWith<_SessionAbortResponse> get copyWith => __$SessionAbortResponseCopyWithImpl<_SessionAbortResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionAbortResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionAbortResponse&&(identical(other.subAgentsHandled, subAgentsHandled) || other.subAgentsHandled == subAgentsHandled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,subAgentsHandled);
}

@override
String toString() {
    return 'SessionAbortResponse(subAgentsHandled: $subAgentsHandled)';
}


}

/// @nodoc
abstract mixin class _$SessionAbortResponseCopyWith<$Res> implements $SessionAbortResponseCopyWith<$Res> {
  factory _$SessionAbortResponseCopyWith(_SessionAbortResponse value, $Res Function(_SessionAbortResponse) _then) = __$SessionAbortResponseCopyWithImpl;
@override @useResult
$Res call({
 bool subAgentsHandled
});




}
/// @nodoc
class __$SessionAbortResponseCopyWithImpl<$Res>
    implements _$SessionAbortResponseCopyWith<$Res> {
  __$SessionAbortResponseCopyWithImpl(this._self, this._then);

  final _SessionAbortResponse _self;
  final $Res Function(_SessionAbortResponse) _then;

/// Create a copy of SessionAbortResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? subAgentsHandled = null,}) {
  return _then(_SessionAbortResponse(
subAgentsHandled: null == subAgentsHandled ? _self.subAgentsHandled : subAgentsHandled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

SessionAbortRefusal _$SessionAbortRefusalFromJson(
  Map<String, dynamic> json
) {
        switch (json['kind']) {
                  case 'notPerformed':
          return SessionAbortNotPerformedRefusal.fromJson(
            json
          );
        
          default:
            return SessionAbortUnknownRefusal.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$SessionAbortRefusal {



  /// Serializes this SessionAbortRefusal to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionAbortRefusal);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SessionAbortRefusal()';
}


}





/// @nodoc
@JsonSerializable()

class SessionAbortNotPerformedRefusal implements SessionAbortRefusal {
  const SessionAbortNotPerformedRefusal({@JsonKey(fromJson: _abortRefusalReasonFromJson, toJson: _abortRefusalReasonToJson) required this.reason,  String? $type}): $type = $type ?? 'notPerformed';
  factory SessionAbortNotPerformedRefusal.fromJson(Map<String, dynamic> json) => _$SessionAbortNotPerformedRefusalFromJson(json);

@JsonKey(fromJson: _abortRefusalReasonFromJson, toJson: _abortRefusalReasonToJson) final  SessionAbortRefusalReason reason;

@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SessionAbortNotPerformedRefusalToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionAbortNotPerformedRefusal&&(identical(other.reason, reason) || other.reason == reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,reason);
}

@override
String toString() {
    return 'SessionAbortRefusal.notPerformed(reason: $reason)';
}


}




/// @nodoc
@JsonSerializable()

class SessionAbortUnknownRefusal implements SessionAbortRefusal {
  const SessionAbortUnknownRefusal({ String? $type}): $type = $type ?? 'unknown';
  factory SessionAbortUnknownRefusal.fromJson(Map<String, dynamic> json) => _$SessionAbortUnknownRefusalFromJson(json);



@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SessionAbortUnknownRefusalToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionAbortUnknownRefusal);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SessionAbortRefusal.unknown()';
}


}





/// @nodoc
mixin _$SessionAbortRejection {

 int get runningSubAgentCount;/// Whether the main agent itself is mid-turn, which decides whether a
/// "main agent only" stop is worth offering.
 bool get mainAgentRunning;/// Whether a `keep` stop (main agent only) is honored while the main agent
/// runs. Backends whose interrupt also stops sub-agents report false.
 bool get mainAgentOnlySupported;
/// Create a copy of SessionAbortRejection
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionAbortRejectionCopyWith<SessionAbortRejection> get copyWith => _$SessionAbortRejectionCopyWithImpl<SessionAbortRejection>(this as SessionAbortRejection, _$identity);

  /// Serializes this SessionAbortRejection to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SessionAbortRejection;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionAbortRejection&&(identical(other.runningSubAgentCount, _this.runningSubAgentCount) || other.runningSubAgentCount == _this.runningSubAgentCount)&&(identical(other.mainAgentRunning, _this.mainAgentRunning) || other.mainAgentRunning == _this.mainAgentRunning)&&(identical(other.mainAgentOnlySupported, _this.mainAgentOnlySupported) || other.mainAgentOnlySupported == _this.mainAgentOnlySupported));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SessionAbortRejection;
  return Object.hash(runtimeType,_this.runningSubAgentCount,_this.mainAgentRunning,_this.mainAgentOnlySupported);
}

@override
String toString() {
  final _this = this as SessionAbortRejection;
  return 'SessionAbortRejection(runningSubAgentCount: ${_this.runningSubAgentCount}, mainAgentRunning: ${_this.mainAgentRunning}, mainAgentOnlySupported: ${_this.mainAgentOnlySupported})';
}


}

/// @nodoc
abstract mixin class $SessionAbortRejectionCopyWith<$Res>  {
  factory $SessionAbortRejectionCopyWith(SessionAbortRejection value, $Res Function(SessionAbortRejection) _then) = _$SessionAbortRejectionCopyWithImpl;
@useResult
$Res call({
 int runningSubAgentCount, bool mainAgentRunning, bool mainAgentOnlySupported
});




}
/// @nodoc
class _$SessionAbortRejectionCopyWithImpl<$Res>
    implements $SessionAbortRejectionCopyWith<$Res> {
  _$SessionAbortRejectionCopyWithImpl(this._self, this._then);

  final SessionAbortRejection _self;
  final $Res Function(SessionAbortRejection) _then;

/// Create a copy of SessionAbortRejection
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? runningSubAgentCount = null,Object? mainAgentRunning = null,Object? mainAgentOnlySupported = null,}) {
  return _then(SessionAbortRejection(
runningSubAgentCount: null == runningSubAgentCount ? _self.runningSubAgentCount : runningSubAgentCount // ignore: cast_nullable_to_non_nullable
as int,mainAgentRunning: null == mainAgentRunning ? _self.mainAgentRunning : mainAgentRunning // ignore: cast_nullable_to_non_nullable
as bool,mainAgentOnlySupported: null == mainAgentOnlySupported ? _self.mainAgentOnlySupported : mainAgentOnlySupported // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SessionAbortRejection implements SessionAbortRejection {
  const _SessionAbortRejection({required this.runningSubAgentCount, required this.mainAgentRunning, this.mainAgentOnlySupported = false});
  factory _SessionAbortRejection.fromJson(Map<String, dynamic> json) => _$SessionAbortRejectionFromJson(json);

@override final  int runningSubAgentCount;
/// Whether the main agent itself is mid-turn, which decides whether a
/// "main agent only" stop is worth offering.
@override final  bool mainAgentRunning;
/// Whether a `keep` stop (main agent only) is honored while the main agent
/// runs. Backends whose interrupt also stops sub-agents report false.
@override@JsonKey() final  bool mainAgentOnlySupported;

/// Create a copy of SessionAbortRejection
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionAbortRejectionCopyWith<_SessionAbortRejection> get copyWith => __$SessionAbortRejectionCopyWithImpl<_SessionAbortRejection>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionAbortRejectionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionAbortRejection&&(identical(other.runningSubAgentCount, runningSubAgentCount) || other.runningSubAgentCount == runningSubAgentCount)&&(identical(other.mainAgentRunning, mainAgentRunning) || other.mainAgentRunning == mainAgentRunning)&&(identical(other.mainAgentOnlySupported, mainAgentOnlySupported) || other.mainAgentOnlySupported == mainAgentOnlySupported));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,runningSubAgentCount,mainAgentRunning,mainAgentOnlySupported);
}

@override
String toString() {
    return 'SessionAbortRejection(runningSubAgentCount: $runningSubAgentCount, mainAgentRunning: $mainAgentRunning, mainAgentOnlySupported: $mainAgentOnlySupported)';
}


}

/// @nodoc
abstract mixin class _$SessionAbortRejectionCopyWith<$Res> implements $SessionAbortRejectionCopyWith<$Res> {
  factory _$SessionAbortRejectionCopyWith(_SessionAbortRejection value, $Res Function(_SessionAbortRejection) _then) = __$SessionAbortRejectionCopyWithImpl;
@override @useResult
$Res call({
 int runningSubAgentCount, bool mainAgentRunning, bool mainAgentOnlySupported
});




}
/// @nodoc
class __$SessionAbortRejectionCopyWithImpl<$Res>
    implements _$SessionAbortRejectionCopyWith<$Res> {
  __$SessionAbortRejectionCopyWithImpl(this._self, this._then);

  final _SessionAbortRejection _self;
  final $Res Function(_SessionAbortRejection) _then;

/// Create a copy of SessionAbortRejection
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? runningSubAgentCount = null,Object? mainAgentRunning = null,Object? mainAgentOnlySupported = null,}) {
  return _then(_SessionAbortRejection(
runningSubAgentCount: null == runningSubAgentCount ? _self.runningSubAgentCount : runningSubAgentCount // ignore: cast_nullable_to_non_nullable
as int,mainAgentRunning: null == mainAgentRunning ? _self.mainAgentRunning : mainAgentRunning // ignore: cast_nullable_to_non_nullable
as bool,mainAgentOnlySupported: null == mainAgentOnlySupported ? _self.mainAgentOnlySupported : mainAgentOnlySupported // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
