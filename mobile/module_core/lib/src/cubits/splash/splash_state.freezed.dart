// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'splash_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SplashState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SplashState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SplashState()';
}


}

/// @nodoc
class $SplashStateCopyWith<$Res>  {
$SplashStateCopyWith(SplashState _, $Res Function(SplashState) __);
}



/// @nodoc


class SplashInitializing implements SplashState {
  const SplashInitializing();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SplashInitializing);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SplashState.initializing()';
}


}




/// @nodoc


class SplashReady implements SplashState {
  const SplashReady({required this.route});
  

 final  AppRoute route;

/// Create a copy of SplashState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SplashReadyCopyWith<SplashReady> get copyWith => _$SplashReadyCopyWithImpl<SplashReady>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SplashReady&&(identical(other.route, route) || other.route == route));
}


@override
int get hashCode => Object.hash(runtimeType,route);

@override
String toString() {
  return 'SplashState.ready(route: $route)';
}


}

/// @nodoc
abstract mixin class $SplashReadyCopyWith<$Res> implements $SplashStateCopyWith<$Res> {
  factory $SplashReadyCopyWith(SplashReady value, $Res Function(SplashReady) _then) = _$SplashReadyCopyWithImpl;
@useResult
$Res call({
 AppRoute route
});




}
/// @nodoc
class _$SplashReadyCopyWithImpl<$Res>
    implements $SplashReadyCopyWith<$Res> {
  _$SplashReadyCopyWithImpl(this._self, this._then);

  final SplashReady _self;
  final $Res Function(SplashReady) _then;

/// Create a copy of SplashState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? route = null,}) {
  return _then(SplashReady(
route: null == route ? _self.route : route // ignore: cast_nullable_to_non_nullable
as AppRoute,
  ));
}


}

// dart format on
