// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bridge_control_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BridgeControlStatus {

/// Whether a helper is currently connected to the GUI's control channel.
 bool get helperOnline; ControlRelayConnectionState get relay; ControlPluginHealthState get plugin; int get activeSessionCount;/// Readable copy of the helper's bridge id (from the `registered` event).
/// Retained across helper disconnects — the offline-unregister fallback
/// needs it exactly when the helper is gone.
 String? get bridgeId;
/// Create a copy of BridgeControlStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgeControlStatusCopyWith<BridgeControlStatus> get copyWith => _$BridgeControlStatusCopyWithImpl<BridgeControlStatus>(this as BridgeControlStatus, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeControlStatus&&(identical(other.helperOnline, helperOnline) || other.helperOnline == helperOnline)&&(identical(other.relay, relay) || other.relay == relay)&&(identical(other.plugin, plugin) || other.plugin == plugin)&&(identical(other.activeSessionCount, activeSessionCount) || other.activeSessionCount == activeSessionCount)&&(identical(other.bridgeId, bridgeId) || other.bridgeId == bridgeId));
}


@override
int get hashCode => Object.hash(runtimeType,helperOnline,relay,plugin,activeSessionCount,bridgeId);

@override
String toString() {
  return 'BridgeControlStatus(helperOnline: $helperOnline, relay: $relay, plugin: $plugin, activeSessionCount: $activeSessionCount, bridgeId: $bridgeId)';
}


}

/// @nodoc
abstract mixin class $BridgeControlStatusCopyWith<$Res>  {
  factory $BridgeControlStatusCopyWith(BridgeControlStatus value, $Res Function(BridgeControlStatus) _then) = _$BridgeControlStatusCopyWithImpl;
@useResult
$Res call({
 bool helperOnline, ControlRelayConnectionState relay, ControlPluginHealthState plugin, int activeSessionCount, String? bridgeId
});




}
/// @nodoc
class _$BridgeControlStatusCopyWithImpl<$Res>
    implements $BridgeControlStatusCopyWith<$Res> {
  _$BridgeControlStatusCopyWithImpl(this._self, this._then);

  final BridgeControlStatus _self;
  final $Res Function(BridgeControlStatus) _then;

/// Create a copy of BridgeControlStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? helperOnline = null,Object? relay = null,Object? plugin = null,Object? activeSessionCount = null,Object? bridgeId = freezed,}) {
  return _then(_self.copyWith(
helperOnline: null == helperOnline ? _self.helperOnline : helperOnline // ignore: cast_nullable_to_non_nullable
as bool,relay: null == relay ? _self.relay : relay // ignore: cast_nullable_to_non_nullable
as ControlRelayConnectionState,plugin: null == plugin ? _self.plugin : plugin // ignore: cast_nullable_to_non_nullable
as ControlPluginHealthState,activeSessionCount: null == activeSessionCount ? _self.activeSessionCount : activeSessionCount // ignore: cast_nullable_to_non_nullable
as int,bridgeId: freezed == bridgeId ? _self.bridgeId : bridgeId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc


class _BridgeControlStatus implements BridgeControlStatus {
  const _BridgeControlStatus({required this.helperOnline, required this.relay, required this.plugin, required this.activeSessionCount, required this.bridgeId});
  

/// Whether a helper is currently connected to the GUI's control channel.
@override final  bool helperOnline;
@override final  ControlRelayConnectionState relay;
@override final  ControlPluginHealthState plugin;
@override final  int activeSessionCount;
/// Readable copy of the helper's bridge id (from the `registered` event).
/// Retained across helper disconnects — the offline-unregister fallback
/// needs it exactly when the helper is gone.
@override final  String? bridgeId;

/// Create a copy of BridgeControlStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BridgeControlStatusCopyWith<_BridgeControlStatus> get copyWith => __$BridgeControlStatusCopyWithImpl<_BridgeControlStatus>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BridgeControlStatus&&(identical(other.helperOnline, helperOnline) || other.helperOnline == helperOnline)&&(identical(other.relay, relay) || other.relay == relay)&&(identical(other.plugin, plugin) || other.plugin == plugin)&&(identical(other.activeSessionCount, activeSessionCount) || other.activeSessionCount == activeSessionCount)&&(identical(other.bridgeId, bridgeId) || other.bridgeId == bridgeId));
}


@override
int get hashCode => Object.hash(runtimeType,helperOnline,relay,plugin,activeSessionCount,bridgeId);

@override
String toString() {
  return 'BridgeControlStatus(helperOnline: $helperOnline, relay: $relay, plugin: $plugin, activeSessionCount: $activeSessionCount, bridgeId: $bridgeId)';
}


}

/// @nodoc
abstract mixin class _$BridgeControlStatusCopyWith<$Res> implements $BridgeControlStatusCopyWith<$Res> {
  factory _$BridgeControlStatusCopyWith(_BridgeControlStatus value, $Res Function(_BridgeControlStatus) _then) = __$BridgeControlStatusCopyWithImpl;
@override @useResult
$Res call({
 bool helperOnline, ControlRelayConnectionState relay, ControlPluginHealthState plugin, int activeSessionCount, String? bridgeId
});




}
/// @nodoc
class __$BridgeControlStatusCopyWithImpl<$Res>
    implements _$BridgeControlStatusCopyWith<$Res> {
  __$BridgeControlStatusCopyWithImpl(this._self, this._then);

  final _BridgeControlStatus _self;
  final $Res Function(_BridgeControlStatus) _then;

/// Create a copy of BridgeControlStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? helperOnline = null,Object? relay = null,Object? plugin = null,Object? activeSessionCount = null,Object? bridgeId = freezed,}) {
  return _then(_BridgeControlStatus(
helperOnline: null == helperOnline ? _self.helperOnline : helperOnline // ignore: cast_nullable_to_non_nullable
as bool,relay: null == relay ? _self.relay : relay // ignore: cast_nullable_to_non_nullable
as ControlRelayConnectionState,plugin: null == plugin ? _self.plugin : plugin // ignore: cast_nullable_to_non_nullable
as ControlPluginHealthState,activeSessionCount: null == activeSessionCount ? _self.activeSessionCount : activeSessionCount // ignore: cast_nullable_to_non_nullable
as int,bridgeId: freezed == bridgeId ? _self.bridgeId : bridgeId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
