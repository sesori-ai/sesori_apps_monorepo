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
