// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_activity_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SessionActivityInfo {

 bool get mainAgentRunning; int get backgroundTaskCount;
/// Create a copy of SessionActivityInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionActivityInfoCopyWith<SessionActivityInfo> get copyWith => _$SessionActivityInfoCopyWithImpl<SessionActivityInfo>(this as SessionActivityInfo, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionActivityInfo&&(identical(other.mainAgentRunning, mainAgentRunning) || other.mainAgentRunning == mainAgentRunning)&&(identical(other.backgroundTaskCount, backgroundTaskCount) || other.backgroundTaskCount == backgroundTaskCount));
}


@override
int get hashCode => Object.hash(runtimeType,mainAgentRunning,backgroundTaskCount);

@override
String toString() {
  return 'SessionActivityInfo(mainAgentRunning: $mainAgentRunning, backgroundTaskCount: $backgroundTaskCount)';
}


}

/// @nodoc
abstract mixin class $SessionActivityInfoCopyWith<$Res>  {
  factory $SessionActivityInfoCopyWith(SessionActivityInfo value, $Res Function(SessionActivityInfo) _then) = _$SessionActivityInfoCopyWithImpl;
@useResult
$Res call({
 bool mainAgentRunning, int backgroundTaskCount
});




}
/// @nodoc
class _$SessionActivityInfoCopyWithImpl<$Res>
    implements $SessionActivityInfoCopyWith<$Res> {
  _$SessionActivityInfoCopyWithImpl(this._self, this._then);

  final SessionActivityInfo _self;
  final $Res Function(SessionActivityInfo) _then;

/// Create a copy of SessionActivityInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? mainAgentRunning = null,Object? backgroundTaskCount = null,}) {
  return _then(_self.copyWith(
mainAgentRunning: null == mainAgentRunning ? _self.mainAgentRunning : mainAgentRunning // ignore: cast_nullable_to_non_nullable
as bool,backgroundTaskCount: null == backgroundTaskCount ? _self.backgroundTaskCount : backgroundTaskCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc


class _SessionActivityInfo implements SessionActivityInfo {
  const _SessionActivityInfo({this.mainAgentRunning = false, this.backgroundTaskCount = 0});
  

@override@JsonKey() final  bool mainAgentRunning;
@override@JsonKey() final  int backgroundTaskCount;

/// Create a copy of SessionActivityInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionActivityInfoCopyWith<_SessionActivityInfo> get copyWith => __$SessionActivityInfoCopyWithImpl<_SessionActivityInfo>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionActivityInfo&&(identical(other.mainAgentRunning, mainAgentRunning) || other.mainAgentRunning == mainAgentRunning)&&(identical(other.backgroundTaskCount, backgroundTaskCount) || other.backgroundTaskCount == backgroundTaskCount));
}


@override
int get hashCode => Object.hash(runtimeType,mainAgentRunning,backgroundTaskCount);

@override
String toString() {
  return 'SessionActivityInfo(mainAgentRunning: $mainAgentRunning, backgroundTaskCount: $backgroundTaskCount)';
}


}

/// @nodoc
abstract mixin class _$SessionActivityInfoCopyWith<$Res> implements $SessionActivityInfoCopyWith<$Res> {
  factory _$SessionActivityInfoCopyWith(_SessionActivityInfo value, $Res Function(_SessionActivityInfo) _then) = __$SessionActivityInfoCopyWithImpl;
@override @useResult
$Res call({
 bool mainAgentRunning, int backgroundTaskCount
});




}
/// @nodoc
class __$SessionActivityInfoCopyWithImpl<$Res>
    implements _$SessionActivityInfoCopyWith<$Res> {
  __$SessionActivityInfoCopyWithImpl(this._self, this._then);

  final _SessionActivityInfo _self;
  final $Res Function(_SessionActivityInfo) _then;

/// Create a copy of SessionActivityInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mainAgentRunning = null,Object? backgroundTaskCount = null,}) {
  return _then(_SessionActivityInfo(
mainAgentRunning: null == mainAgentRunning ? _self.mainAgentRunning : mainAgentRunning // ignore: cast_nullable_to_non_nullable
as bool,backgroundTaskCount: null == backgroundTaskCount ? _self.backgroundTaskCount : backgroundTaskCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
