// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'connection_overlay_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ConnectionOverlayState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionOverlayState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ConnectionOverlayState()';
}


}

/// @nodoc
class $ConnectionOverlayStateCopyWith<$Res>  {
$ConnectionOverlayStateCopyWith(ConnectionOverlayState _, $Res Function(ConnectionOverlayState) __);
}



/// @nodoc


class ConnectionOverlayHidden implements ConnectionOverlayState {
  const ConnectionOverlayHidden({required this.connected});
  

 final  bool connected;

/// Create a copy of ConnectionOverlayState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConnectionOverlayHiddenCopyWith<ConnectionOverlayHidden> get copyWith => _$ConnectionOverlayHiddenCopyWithImpl<ConnectionOverlayHidden>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionOverlayHidden&&(identical(other.connected, connected) || other.connected == connected));
}


@override
int get hashCode => Object.hash(runtimeType,connected);

@override
String toString() {
  return 'ConnectionOverlayState.hidden(connected: $connected)';
}


}

/// @nodoc
abstract mixin class $ConnectionOverlayHiddenCopyWith<$Res> implements $ConnectionOverlayStateCopyWith<$Res> {
  factory $ConnectionOverlayHiddenCopyWith(ConnectionOverlayHidden value, $Res Function(ConnectionOverlayHidden) _then) = _$ConnectionOverlayHiddenCopyWithImpl;
@useResult
$Res call({
 bool connected
});




}
/// @nodoc
class _$ConnectionOverlayHiddenCopyWithImpl<$Res>
    implements $ConnectionOverlayHiddenCopyWith<$Res> {
  _$ConnectionOverlayHiddenCopyWithImpl(this._self, this._then);

  final ConnectionOverlayHidden _self;
  final $Res Function(ConnectionOverlayHidden) _then;

/// Create a copy of ConnectionOverlayState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? connected = null,}) {
  return _then(ConnectionOverlayHidden(
connected: null == connected ? _self.connected : connected // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class ConnectionOverlayReconnecting implements ConnectionOverlayState {
  const ConnectionOverlayReconnecting();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionOverlayReconnecting);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ConnectionOverlayState.reconnecting()';
}


}




/// @nodoc


class ConnectionOverlayConnectionLost implements ConnectionOverlayState {
  const ConnectionOverlayConnectionLost();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionOverlayConnectionLost);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ConnectionOverlayState.connectionLost()';
}


}




/// @nodoc


class ConnectionOverlayBridgeOffline implements ConnectionOverlayState {
  const ConnectionOverlayBridgeOffline();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionOverlayBridgeOffline);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ConnectionOverlayState.bridgeOffline()';
}


}




// dart format on
