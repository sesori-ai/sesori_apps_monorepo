// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'runtime_start_intent.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RuntimeStartIntent {

/// Stable identifier of the bridge run that is about to spawn the runtime.
 String get ownerSessionId;/// The port the spawn is targeting.
 int get port;/// Pid of the hosting bridge process.
 int get bridgePid;/// Start marker of the hosting bridge process (absent on Windows).
 String? get bridgeStartMarker;/// When the intent was recorded (host clock).
 DateTime get recordedAt;
/// Create a copy of RuntimeStartIntent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RuntimeStartIntentCopyWith<RuntimeStartIntent> get copyWith => _$RuntimeStartIntentCopyWithImpl<RuntimeStartIntent>(this as RuntimeStartIntent, _$identity);

  /// Serializes this RuntimeStartIntent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RuntimeStartIntent&&(identical(other.ownerSessionId, ownerSessionId) || other.ownerSessionId == ownerSessionId)&&(identical(other.port, port) || other.port == port)&&(identical(other.bridgePid, bridgePid) || other.bridgePid == bridgePid)&&(identical(other.bridgeStartMarker, bridgeStartMarker) || other.bridgeStartMarker == bridgeStartMarker)&&(identical(other.recordedAt, recordedAt) || other.recordedAt == recordedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ownerSessionId,port,bridgePid,bridgeStartMarker,recordedAt);

@override
String toString() {
  return 'RuntimeStartIntent(ownerSessionId: $ownerSessionId, port: $port, bridgePid: $bridgePid, bridgeStartMarker: $bridgeStartMarker, recordedAt: $recordedAt)';
}


}

/// @nodoc
abstract mixin class $RuntimeStartIntentCopyWith<$Res>  {
  factory $RuntimeStartIntentCopyWith(RuntimeStartIntent value, $Res Function(RuntimeStartIntent) _then) = _$RuntimeStartIntentCopyWithImpl;
@useResult
$Res call({
 String ownerSessionId, int port, int bridgePid, String? bridgeStartMarker, DateTime recordedAt
});




}
/// @nodoc
class _$RuntimeStartIntentCopyWithImpl<$Res>
    implements $RuntimeStartIntentCopyWith<$Res> {
  _$RuntimeStartIntentCopyWithImpl(this._self, this._then);

  final RuntimeStartIntent _self;
  final $Res Function(RuntimeStartIntent) _then;

/// Create a copy of RuntimeStartIntent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ownerSessionId = null,Object? port = null,Object? bridgePid = null,Object? bridgeStartMarker = freezed,Object? recordedAt = null,}) {
  return _then(_self.copyWith(
ownerSessionId: null == ownerSessionId ? _self.ownerSessionId : ownerSessionId // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,bridgePid: null == bridgePid ? _self.bridgePid : bridgePid // ignore: cast_nullable_to_non_nullable
as int,bridgeStartMarker: freezed == bridgeStartMarker ? _self.bridgeStartMarker : bridgeStartMarker // ignore: cast_nullable_to_non_nullable
as String?,recordedAt: null == recordedAt ? _self.recordedAt : recordedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [RuntimeStartIntent].
extension RuntimeStartIntentPatterns on RuntimeStartIntent {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RuntimeStartIntent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RuntimeStartIntent() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RuntimeStartIntent value)  $default,){
final _that = this;
switch (_that) {
case _RuntimeStartIntent():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RuntimeStartIntent value)?  $default,){
final _that = this;
switch (_that) {
case _RuntimeStartIntent() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String ownerSessionId,  int port,  int bridgePid,  String? bridgeStartMarker,  DateTime recordedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RuntimeStartIntent() when $default != null:
return $default(_that.ownerSessionId,_that.port,_that.bridgePid,_that.bridgeStartMarker,_that.recordedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String ownerSessionId,  int port,  int bridgePid,  String? bridgeStartMarker,  DateTime recordedAt)  $default,) {final _that = this;
switch (_that) {
case _RuntimeStartIntent():
return $default(_that.ownerSessionId,_that.port,_that.bridgePid,_that.bridgeStartMarker,_that.recordedAt);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String ownerSessionId,  int port,  int bridgePid,  String? bridgeStartMarker,  DateTime recordedAt)?  $default,) {final _that = this;
switch (_that) {
case _RuntimeStartIntent() when $default != null:
return $default(_that.ownerSessionId,_that.port,_that.bridgePid,_that.bridgeStartMarker,_that.recordedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RuntimeStartIntent implements RuntimeStartIntent {
  const _RuntimeStartIntent({required this.ownerSessionId, required this.port, required this.bridgePid, required this.bridgeStartMarker, required this.recordedAt});
  factory _RuntimeStartIntent.fromJson(Map<String, dynamic> json) => _$RuntimeStartIntentFromJson(json);

/// Stable identifier of the bridge run that is about to spawn the runtime.
@override final  String ownerSessionId;
/// The port the spawn is targeting.
@override final  int port;
/// Pid of the hosting bridge process.
@override final  int bridgePid;
/// Start marker of the hosting bridge process (absent on Windows).
@override final  String? bridgeStartMarker;
/// When the intent was recorded (host clock).
@override final  DateTime recordedAt;

/// Create a copy of RuntimeStartIntent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RuntimeStartIntentCopyWith<_RuntimeStartIntent> get copyWith => __$RuntimeStartIntentCopyWithImpl<_RuntimeStartIntent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RuntimeStartIntentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RuntimeStartIntent&&(identical(other.ownerSessionId, ownerSessionId) || other.ownerSessionId == ownerSessionId)&&(identical(other.port, port) || other.port == port)&&(identical(other.bridgePid, bridgePid) || other.bridgePid == bridgePid)&&(identical(other.bridgeStartMarker, bridgeStartMarker) || other.bridgeStartMarker == bridgeStartMarker)&&(identical(other.recordedAt, recordedAt) || other.recordedAt == recordedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ownerSessionId,port,bridgePid,bridgeStartMarker,recordedAt);

@override
String toString() {
  return 'RuntimeStartIntent(ownerSessionId: $ownerSessionId, port: $port, bridgePid: $bridgePid, bridgeStartMarker: $bridgeStartMarker, recordedAt: $recordedAt)';
}


}

/// @nodoc
abstract mixin class _$RuntimeStartIntentCopyWith<$Res> implements $RuntimeStartIntentCopyWith<$Res> {
  factory _$RuntimeStartIntentCopyWith(_RuntimeStartIntent value, $Res Function(_RuntimeStartIntent) _then) = __$RuntimeStartIntentCopyWithImpl;
@override @useResult
$Res call({
 String ownerSessionId, int port, int bridgePid, String? bridgeStartMarker, DateTime recordedAt
});




}
/// @nodoc
class __$RuntimeStartIntentCopyWithImpl<$Res>
    implements _$RuntimeStartIntentCopyWith<$Res> {
  __$RuntimeStartIntentCopyWithImpl(this._self, this._then);

  final _RuntimeStartIntent _self;
  final $Res Function(_RuntimeStartIntent) _then;

/// Create a copy of RuntimeStartIntent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ownerSessionId = null,Object? port = null,Object? bridgePid = null,Object? bridgeStartMarker = freezed,Object? recordedAt = null,}) {
  return _then(_RuntimeStartIntent(
ownerSessionId: null == ownerSessionId ? _self.ownerSessionId : ownerSessionId // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,bridgePid: null == bridgePid ? _self.bridgePid : bridgePid // ignore: cast_nullable_to_non_nullable
as int,bridgeStartMarker: freezed == bridgeStartMarker ? _self.bridgeStartMarker : bridgeStartMarker // ignore: cast_nullable_to_non_nullable
as String?,recordedAt: null == recordedAt ? _self.recordedAt : recordedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
