// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bridge_startup_lock.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BridgeStartupLock {

 int get bridgePid; String? get bridgeStartMarker;
/// Create a copy of BridgeStartupLock
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgeStartupLockCopyWith<BridgeStartupLock> get copyWith => _$BridgeStartupLockCopyWithImpl<BridgeStartupLock>(this as BridgeStartupLock, _$identity);

  /// Serializes this BridgeStartupLock to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeStartupLock&&(identical(other.bridgePid, bridgePid) || other.bridgePid == bridgePid)&&(identical(other.bridgeStartMarker, bridgeStartMarker) || other.bridgeStartMarker == bridgeStartMarker));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,bridgePid,bridgeStartMarker);

@override
String toString() {
  return 'BridgeStartupLock(bridgePid: $bridgePid, bridgeStartMarker: $bridgeStartMarker)';
}


}

/// @nodoc
abstract mixin class $BridgeStartupLockCopyWith<$Res>  {
  factory $BridgeStartupLockCopyWith(BridgeStartupLock value, $Res Function(BridgeStartupLock) _then) = _$BridgeStartupLockCopyWithImpl;
@useResult
$Res call({
 int bridgePid, String? bridgeStartMarker
});




}
/// @nodoc
class _$BridgeStartupLockCopyWithImpl<$Res>
    implements $BridgeStartupLockCopyWith<$Res> {
  _$BridgeStartupLockCopyWithImpl(this._self, this._then);

  final BridgeStartupLock _self;
  final $Res Function(BridgeStartupLock) _then;

/// Create a copy of BridgeStartupLock
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bridgePid = null,Object? bridgeStartMarker = freezed,}) {
  return _then(_self.copyWith(
bridgePid: null == bridgePid ? _self.bridgePid : bridgePid // ignore: cast_nullable_to_non_nullable
as int,bridgeStartMarker: freezed == bridgeStartMarker ? _self.bridgeStartMarker : bridgeStartMarker // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _BridgeStartupLock implements BridgeStartupLock {
  const _BridgeStartupLock({required this.bridgePid, required this.bridgeStartMarker});
  factory _BridgeStartupLock.fromJson(Map<String, dynamic> json) => _$BridgeStartupLockFromJson(json);

@override final  int bridgePid;
@override final  String? bridgeStartMarker;

/// Create a copy of BridgeStartupLock
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BridgeStartupLockCopyWith<_BridgeStartupLock> get copyWith => __$BridgeStartupLockCopyWithImpl<_BridgeStartupLock>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BridgeStartupLockToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BridgeStartupLock&&(identical(other.bridgePid, bridgePid) || other.bridgePid == bridgePid)&&(identical(other.bridgeStartMarker, bridgeStartMarker) || other.bridgeStartMarker == bridgeStartMarker));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,bridgePid,bridgeStartMarker);

@override
String toString() {
  return 'BridgeStartupLock(bridgePid: $bridgePid, bridgeStartMarker: $bridgeStartMarker)';
}


}

/// @nodoc
abstract mixin class _$BridgeStartupLockCopyWith<$Res> implements $BridgeStartupLockCopyWith<$Res> {
  factory _$BridgeStartupLockCopyWith(_BridgeStartupLock value, $Res Function(_BridgeStartupLock) _then) = __$BridgeStartupLockCopyWithImpl;
@override @useResult
$Res call({
 int bridgePid, String? bridgeStartMarker
});




}
/// @nodoc
class __$BridgeStartupLockCopyWithImpl<$Res>
    implements _$BridgeStartupLockCopyWith<$Res> {
  __$BridgeStartupLockCopyWithImpl(this._self, this._then);

  final _BridgeStartupLock _self;
  final $Res Function(_BridgeStartupLock) _then;

/// Create a copy of BridgeStartupLock
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bridgePid = null,Object? bridgeStartMarker = freezed,}) {
  return _then(_BridgeStartupLock(
bridgePid: null == bridgePid ? _self.bridgePid : bridgePid // ignore: cast_nullable_to_non_nullable
as int,bridgeStartMarker: freezed == bridgeStartMarker ? _self.bridgeStartMarker : bridgeStartMarker // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
