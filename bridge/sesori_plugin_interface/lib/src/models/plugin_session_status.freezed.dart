// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_session_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PluginSessionStatus {



  /// Serializes this PluginSessionStatus to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginSessionStatus);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PluginSessionStatus()';
}


}

/// @nodoc
class $PluginSessionStatusCopyWith<$Res>  {
$PluginSessionStatusCopyWith(PluginSessionStatus _, $Res Function(PluginSessionStatus) __);
}



/// @nodoc
@JsonSerializable(createFactory: false)

class PluginSessionStatusIdle implements PluginSessionStatus {
  const PluginSessionStatusIdle({final  String? $type}): $type = $type ?? 'idle';
  



@JsonKey(name: 'runtimeType')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$PluginSessionStatusIdleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginSessionStatusIdle);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PluginSessionStatus.idle()';
}


}




/// @nodoc
@JsonSerializable(createFactory: false)

class PluginSessionStatusBusy implements PluginSessionStatus {
  const PluginSessionStatusBusy({final  String? $type}): $type = $type ?? 'busy';
  



@JsonKey(name: 'runtimeType')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$PluginSessionStatusBusyToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginSessionStatusBusy);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PluginSessionStatus.busy()';
}


}




/// @nodoc
@JsonSerializable(createFactory: false)

class PluginSessionStatusRetry implements PluginSessionStatus {
  const PluginSessionStatusRetry({required this.attempt, required this.message, required this.next, final  String? $type}): $type = $type ?? 'retry';
  

 final  int attempt;
 final  String message;
 final  int next;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of PluginSessionStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginSessionStatusRetryCopyWith<PluginSessionStatusRetry> get copyWith => _$PluginSessionStatusRetryCopyWithImpl<PluginSessionStatusRetry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginSessionStatusRetryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginSessionStatusRetry&&(identical(other.attempt, attempt) || other.attempt == attempt)&&(identical(other.message, message) || other.message == message)&&(identical(other.next, next) || other.next == next));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,attempt,message,next);

@override
String toString() {
  return 'PluginSessionStatus.retry(attempt: $attempt, message: $message, next: $next)';
}


}

/// @nodoc
abstract mixin class $PluginSessionStatusRetryCopyWith<$Res> implements $PluginSessionStatusCopyWith<$Res> {
  factory $PluginSessionStatusRetryCopyWith(PluginSessionStatusRetry value, $Res Function(PluginSessionStatusRetry) _then) = _$PluginSessionStatusRetryCopyWithImpl;
@useResult
$Res call({
 int attempt, String message, int next
});




}
/// @nodoc
class _$PluginSessionStatusRetryCopyWithImpl<$Res>
    implements $PluginSessionStatusRetryCopyWith<$Res> {
  _$PluginSessionStatusRetryCopyWithImpl(this._self, this._then);

  final PluginSessionStatusRetry _self;
  final $Res Function(PluginSessionStatusRetry) _then;

/// Create a copy of PluginSessionStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? attempt = null,Object? message = null,Object? next = null,}) {
  return _then(PluginSessionStatusRetry(
attempt: null == attempt ? _self.attempt : attempt // ignore: cast_nullable_to_non_nullable
as int,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,next: null == next ? _self.next : next // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
