// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SessionStatusResponse {

// key is session id, value is status
 Map<String, SessionStatus> get statuses;
/// Create a copy of SessionStatusResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionStatusResponseCopyWith<SessionStatusResponse> get copyWith => _$SessionStatusResponseCopyWithImpl<SessionStatusResponse>(this as SessionStatusResponse, _$identity);

  /// Serializes this SessionStatusResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionStatusResponse&&const DeepCollectionEquality().equals(other.statuses, statuses));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(statuses));

@override
String toString() {
  return 'SessionStatusResponse(statuses: $statuses)';
}


}

/// @nodoc
abstract mixin class $SessionStatusResponseCopyWith<$Res>  {
  factory $SessionStatusResponseCopyWith(SessionStatusResponse value, $Res Function(SessionStatusResponse) _then) = _$SessionStatusResponseCopyWithImpl;
@useResult
$Res call({
 Map<String, SessionStatus> statuses
});




}
/// @nodoc
class _$SessionStatusResponseCopyWithImpl<$Res>
    implements $SessionStatusResponseCopyWith<$Res> {
  _$SessionStatusResponseCopyWithImpl(this._self, this._then);

  final SessionStatusResponse _self;
  final $Res Function(SessionStatusResponse) _then;

/// Create a copy of SessionStatusResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? statuses = null,}) {
  return _then(_self.copyWith(
statuses: null == statuses ? _self.statuses : statuses // ignore: cast_nullable_to_non_nullable
as Map<String, SessionStatus>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SessionStatusResponse implements SessionStatusResponse {
  const _SessionStatusResponse({required final  Map<String, SessionStatus> statuses}): _statuses = statuses;
  factory _SessionStatusResponse.fromJson(Map<String, dynamic> json) => _$SessionStatusResponseFromJson(json);

// key is session id, value is status
 final  Map<String, SessionStatus> _statuses;
// key is session id, value is status
@override Map<String, SessionStatus> get statuses {
  if (_statuses is EqualUnmodifiableMapView) return _statuses;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_statuses);
}


/// Create a copy of SessionStatusResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionStatusResponseCopyWith<_SessionStatusResponse> get copyWith => __$SessionStatusResponseCopyWithImpl<_SessionStatusResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionStatusResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionStatusResponse&&const DeepCollectionEquality().equals(other._statuses, _statuses));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_statuses));

@override
String toString() {
  return 'SessionStatusResponse(statuses: $statuses)';
}


}

/// @nodoc
abstract mixin class _$SessionStatusResponseCopyWith<$Res> implements $SessionStatusResponseCopyWith<$Res> {
  factory _$SessionStatusResponseCopyWith(_SessionStatusResponse value, $Res Function(_SessionStatusResponse) _then) = __$SessionStatusResponseCopyWithImpl;
@override @useResult
$Res call({
 Map<String, SessionStatus> statuses
});




}
/// @nodoc
class __$SessionStatusResponseCopyWithImpl<$Res>
    implements _$SessionStatusResponseCopyWith<$Res> {
  __$SessionStatusResponseCopyWithImpl(this._self, this._then);

  final _SessionStatusResponse _self;
  final $Res Function(_SessionStatusResponse) _then;

/// Create a copy of SessionStatusResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? statuses = null,}) {
  return _then(_SessionStatusResponse(
statuses: null == statuses ? _self._statuses : statuses // ignore: cast_nullable_to_non_nullable
as Map<String, SessionStatus>,
  ));
}


}

SessionStatus _$SessionStatusFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'idle':
          return SessionStatusIdle.fromJson(
            json
          );
                case 'busy':
          return SessionStatusBusy.fromJson(
            json
          );
                case 'retry':
          return SessionStatusRetry.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'SessionStatus',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$SessionStatus {



  /// Serializes this SessionStatus to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionStatus);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SessionStatus()';
}


}

/// @nodoc
class $SessionStatusCopyWith<$Res>  {
$SessionStatusCopyWith(SessionStatus _, $Res Function(SessionStatus) __);
}



/// @nodoc
@JsonSerializable()

class SessionStatusIdle implements SessionStatus {
  const SessionStatusIdle({final  String? $type}): $type = $type ?? 'idle';
  factory SessionStatusIdle.fromJson(Map<String, dynamic> json) => _$SessionStatusIdleFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SessionStatusIdleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionStatusIdle);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SessionStatus.idle()';
}


}




/// @nodoc
@JsonSerializable()

class SessionStatusBusy implements SessionStatus {
  const SessionStatusBusy({final  String? $type}): $type = $type ?? 'busy';
  factory SessionStatusBusy.fromJson(Map<String, dynamic> json) => _$SessionStatusBusyFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SessionStatusBusyToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionStatusBusy);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SessionStatus.busy()';
}


}




/// @nodoc
@JsonSerializable()

class SessionStatusRetry implements SessionStatus {
  const SessionStatusRetry({required this.attempt, required this.message, required this.next, final  String? $type}): $type = $type ?? 'retry';
  factory SessionStatusRetry.fromJson(Map<String, dynamic> json) => _$SessionStatusRetryFromJson(json);

 final  int attempt;
 final  String message;
 final  int next;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SessionStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionStatusRetryCopyWith<SessionStatusRetry> get copyWith => _$SessionStatusRetryCopyWithImpl<SessionStatusRetry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionStatusRetryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionStatusRetry&&(identical(other.attempt, attempt) || other.attempt == attempt)&&(identical(other.message, message) || other.message == message)&&(identical(other.next, next) || other.next == next));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,attempt,message,next);

@override
String toString() {
  return 'SessionStatus.retry(attempt: $attempt, message: $message, next: $next)';
}


}

/// @nodoc
abstract mixin class $SessionStatusRetryCopyWith<$Res> implements $SessionStatusCopyWith<$Res> {
  factory $SessionStatusRetryCopyWith(SessionStatusRetry value, $Res Function(SessionStatusRetry) _then) = _$SessionStatusRetryCopyWithImpl;
@useResult
$Res call({
 int attempt, String message, int next
});




}
/// @nodoc
class _$SessionStatusRetryCopyWithImpl<$Res>
    implements $SessionStatusRetryCopyWith<$Res> {
  _$SessionStatusRetryCopyWithImpl(this._self, this._then);

  final SessionStatusRetry _self;
  final $Res Function(SessionStatusRetry) _then;

/// Create a copy of SessionStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? attempt = null,Object? message = null,Object? next = null,}) {
  return _then(SessionStatusRetry(
attempt: null == attempt ? _self.attempt : attempt // ignore: cast_nullable_to_non_nullable
as int,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,next: null == next ? _self.next : next // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
