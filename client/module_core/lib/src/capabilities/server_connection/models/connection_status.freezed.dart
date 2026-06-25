// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'connection_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ConnectionStatus {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionStatus);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ConnectionStatus()';
}


}

/// @nodoc
class $ConnectionStatusCopyWith<$Res>  {
$ConnectionStatusCopyWith(ConnectionStatus _, $Res Function(ConnectionStatus) __);
}



/// @nodoc


class ConnectionDisconnected implements ConnectionStatus {
  const ConnectionDisconnected();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionDisconnected);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ConnectionStatus.disconnected()';
}


}




/// @nodoc


class ConnectionConnected implements ConnectionStatus {
  const ConnectionConnected({required this.config, required this.health});
  

 final  ServerConnectionConfig config;
 final  HealthResponse health;

/// Create a copy of ConnectionStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConnectionConnectedCopyWith<ConnectionConnected> get copyWith => _$ConnectionConnectedCopyWithImpl<ConnectionConnected>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionConnected&&(identical(other.config, config) || other.config == config)&&(identical(other.health, health) || other.health == health));
}


@override
int get hashCode => Object.hash(runtimeType,config,health);

@override
String toString() {
  return 'ConnectionStatus.connected(config: $config, health: $health)';
}


}

/// @nodoc
abstract mixin class $ConnectionConnectedCopyWith<$Res> implements $ConnectionStatusCopyWith<$Res> {
  factory $ConnectionConnectedCopyWith(ConnectionConnected value, $Res Function(ConnectionConnected) _then) = _$ConnectionConnectedCopyWithImpl;
@useResult
$Res call({
 ServerConnectionConfig config, HealthResponse health
});


$ServerConnectionConfigCopyWith<$Res> get config;$HealthResponseCopyWith<$Res> get health;

}
/// @nodoc
class _$ConnectionConnectedCopyWithImpl<$Res>
    implements $ConnectionConnectedCopyWith<$Res> {
  _$ConnectionConnectedCopyWithImpl(this._self, this._then);

  final ConnectionConnected _self;
  final $Res Function(ConnectionConnected) _then;

/// Create a copy of ConnectionStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? config = null,Object? health = null,}) {
  return _then(ConnectionConnected(
config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as ServerConnectionConfig,health: null == health ? _self.health : health // ignore: cast_nullable_to_non_nullable
as HealthResponse,
  ));
}

/// Create a copy of ConnectionStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ServerConnectionConfigCopyWith<$Res> get config {
  
  return $ServerConnectionConfigCopyWith<$Res>(_self.config, (value) {
    return _then(_self.copyWith(config: value));
  });
}/// Create a copy of ConnectionStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$HealthResponseCopyWith<$Res> get health {
  
  return $HealthResponseCopyWith<$Res>(_self.health, (value) {
    return _then(_self.copyWith(health: value));
  });
}
}

/// @nodoc


class ConnectionReconnecting implements ConnectionStatus {
  const ConnectionReconnecting({required this.config});
  

 final  ServerConnectionConfig config;

/// Create a copy of ConnectionStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConnectionReconnectingCopyWith<ConnectionReconnecting> get copyWith => _$ConnectionReconnectingCopyWithImpl<ConnectionReconnecting>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionReconnecting&&(identical(other.config, config) || other.config == config));
}


@override
int get hashCode => Object.hash(runtimeType,config);

@override
String toString() {
  return 'ConnectionStatus.reconnecting(config: $config)';
}


}

/// @nodoc
abstract mixin class $ConnectionReconnectingCopyWith<$Res> implements $ConnectionStatusCopyWith<$Res> {
  factory $ConnectionReconnectingCopyWith(ConnectionReconnecting value, $Res Function(ConnectionReconnecting) _then) = _$ConnectionReconnectingCopyWithImpl;
@useResult
$Res call({
 ServerConnectionConfig config
});


$ServerConnectionConfigCopyWith<$Res> get config;

}
/// @nodoc
class _$ConnectionReconnectingCopyWithImpl<$Res>
    implements $ConnectionReconnectingCopyWith<$Res> {
  _$ConnectionReconnectingCopyWithImpl(this._self, this._then);

  final ConnectionReconnecting _self;
  final $Res Function(ConnectionReconnecting) _then;

/// Create a copy of ConnectionStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? config = null,}) {
  return _then(ConnectionReconnecting(
config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as ServerConnectionConfig,
  ));
}

/// Create a copy of ConnectionStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ServerConnectionConfigCopyWith<$Res> get config {
  
  return $ServerConnectionConfigCopyWith<$Res>(_self.config, (value) {
    return _then(_self.copyWith(config: value));
  });
}
}

/// @nodoc


class ConnectionLost implements ConnectionStatus {
  const ConnectionLost({required this.config});
  

 final  ServerConnectionConfig config;

/// Create a copy of ConnectionStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConnectionLostCopyWith<ConnectionLost> get copyWith => _$ConnectionLostCopyWithImpl<ConnectionLost>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionLost&&(identical(other.config, config) || other.config == config));
}


@override
int get hashCode => Object.hash(runtimeType,config);

@override
String toString() {
  return 'ConnectionStatus.connectionLost(config: $config)';
}


}

/// @nodoc
abstract mixin class $ConnectionLostCopyWith<$Res> implements $ConnectionStatusCopyWith<$Res> {
  factory $ConnectionLostCopyWith(ConnectionLost value, $Res Function(ConnectionLost) _then) = _$ConnectionLostCopyWithImpl;
@useResult
$Res call({
 ServerConnectionConfig config
});


$ServerConnectionConfigCopyWith<$Res> get config;

}
/// @nodoc
class _$ConnectionLostCopyWithImpl<$Res>
    implements $ConnectionLostCopyWith<$Res> {
  _$ConnectionLostCopyWithImpl(this._self, this._then);

  final ConnectionLost _self;
  final $Res Function(ConnectionLost) _then;

/// Create a copy of ConnectionStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? config = null,}) {
  return _then(ConnectionLost(
config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as ServerConnectionConfig,
  ));
}

/// Create a copy of ConnectionStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ServerConnectionConfigCopyWith<$Res> get config {
  
  return $ServerConnectionConfigCopyWith<$Res>(_self.config, (value) {
    return _then(_self.copyWith(config: value));
  });
}
}

/// @nodoc


class ConnectionBridgeOffline implements ConnectionStatus {
  const ConnectionBridgeOffline({required this.config, required this.health});
  

 final  ServerConnectionConfig config;
 final  HealthResponse health;

/// Create a copy of ConnectionStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConnectionBridgeOfflineCopyWith<ConnectionBridgeOffline> get copyWith => _$ConnectionBridgeOfflineCopyWithImpl<ConnectionBridgeOffline>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionBridgeOffline&&(identical(other.config, config) || other.config == config)&&(identical(other.health, health) || other.health == health));
}


@override
int get hashCode => Object.hash(runtimeType,config,health);

@override
String toString() {
  return 'ConnectionStatus.bridgeOffline(config: $config, health: $health)';
}


}

/// @nodoc
abstract mixin class $ConnectionBridgeOfflineCopyWith<$Res> implements $ConnectionStatusCopyWith<$Res> {
  factory $ConnectionBridgeOfflineCopyWith(ConnectionBridgeOffline value, $Res Function(ConnectionBridgeOffline) _then) = _$ConnectionBridgeOfflineCopyWithImpl;
@useResult
$Res call({
 ServerConnectionConfig config, HealthResponse health
});


$ServerConnectionConfigCopyWith<$Res> get config;$HealthResponseCopyWith<$Res> get health;

}
/// @nodoc
class _$ConnectionBridgeOfflineCopyWithImpl<$Res>
    implements $ConnectionBridgeOfflineCopyWith<$Res> {
  _$ConnectionBridgeOfflineCopyWithImpl(this._self, this._then);

  final ConnectionBridgeOffline _self;
  final $Res Function(ConnectionBridgeOffline) _then;

/// Create a copy of ConnectionStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? config = null,Object? health = null,}) {
  return _then(ConnectionBridgeOffline(
config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as ServerConnectionConfig,health: null == health ? _self.health : health // ignore: cast_nullable_to_non_nullable
as HealthResponse,
  ));
}

/// Create a copy of ConnectionStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ServerConnectionConfigCopyWith<$Res> get config {
  
  return $ServerConnectionConfigCopyWith<$Res>(_self.config, (value) {
    return _then(_self.copyWith(config: value));
  });
}/// Create a copy of ConnectionStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$HealthResponseCopyWith<$Res> get health {
  
  return $HealthResponseCopyWith<$Res>(_self.health, (value) {
    return _then(_self.copyWith(health: value));
  });
}
}

// dart format on
