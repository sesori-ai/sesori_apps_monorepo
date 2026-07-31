// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bridge_identity_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BridgeIdentityState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeIdentityState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'BridgeIdentityState()';
}


}

/// @nodoc
class $BridgeIdentityStateCopyWith<$Res>  {
$BridgeIdentityStateCopyWith(BridgeIdentityState _, $Res Function(BridgeIdentityState) __);
}



/// @nodoc


class BridgeIdentityPending implements BridgeIdentityState {
  const BridgeIdentityPending();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeIdentityPending);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'BridgeIdentityState.pending()';
}


}




/// @nodoc


class BridgeIdentityNamed implements BridgeIdentityState {
  const BridgeIdentityNamed({required this.bridge});
  

 final  BridgeSummary bridge;

/// Create a copy of BridgeIdentityState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgeIdentityNamedCopyWith<BridgeIdentityNamed> get copyWith => _$BridgeIdentityNamedCopyWithImpl<BridgeIdentityNamed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeIdentityNamed&&(identical(other.bridge, bridge) || other.bridge == bridge));
}


@override
int get hashCode => Object.hash(runtimeType,bridge);

@override
String toString() {
  return 'BridgeIdentityState.named(bridge: $bridge)';
}


}

/// @nodoc
abstract mixin class $BridgeIdentityNamedCopyWith<$Res> implements $BridgeIdentityStateCopyWith<$Res> {
  factory $BridgeIdentityNamedCopyWith(BridgeIdentityNamed value, $Res Function(BridgeIdentityNamed) _then) = _$BridgeIdentityNamedCopyWithImpl;
@useResult
$Res call({
 BridgeSummary bridge
});


$BridgeSummaryCopyWith<$Res> get bridge;

}
/// @nodoc
class _$BridgeIdentityNamedCopyWithImpl<$Res>
    implements $BridgeIdentityNamedCopyWith<$Res> {
  _$BridgeIdentityNamedCopyWithImpl(this._self, this._then);

  final BridgeIdentityNamed _self;
  final $Res Function(BridgeIdentityNamed) _then;

/// Create a copy of BridgeIdentityState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? bridge = null,}) {
  return _then(BridgeIdentityNamed(
bridge: null == bridge ? _self.bridge : bridge // ignore: cast_nullable_to_non_nullable
as BridgeSummary,
  ));
}

/// Create a copy of BridgeIdentityState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BridgeSummaryCopyWith<$Res> get bridge {
  
  return $BridgeSummaryCopyWith<$Res>(_self.bridge, (value) {
    return _then(_self.copyWith(bridge: value));
  });
}
}

/// @nodoc


class BridgeIdentityUnnamed implements BridgeIdentityState {
  const BridgeIdentityUnnamed();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeIdentityUnnamed);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'BridgeIdentityState.unnamed()';
}


}




// dart format on
