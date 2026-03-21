// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'active_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ActiveSession {

 String get id; bool get mainAgentRunning; List<String> get childSessionIds;
/// Create a copy of ActiveSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ActiveSessionCopyWith<ActiveSession> get copyWith => _$ActiveSessionCopyWithImpl<ActiveSession>(this as ActiveSession, _$identity);

  /// Serializes this ActiveSession to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ActiveSession&&(identical(other.id, id) || other.id == id)&&(identical(other.mainAgentRunning, mainAgentRunning) || other.mainAgentRunning == mainAgentRunning)&&const DeepCollectionEquality().equals(other.childSessionIds, childSessionIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,mainAgentRunning,const DeepCollectionEquality().hash(childSessionIds));

@override
String toString() {
  return 'ActiveSession(id: $id, mainAgentRunning: $mainAgentRunning, childSessionIds: $childSessionIds)';
}


}

/// @nodoc
abstract mixin class $ActiveSessionCopyWith<$Res>  {
  factory $ActiveSessionCopyWith(ActiveSession value, $Res Function(ActiveSession) _then) = _$ActiveSessionCopyWithImpl;
@useResult
$Res call({
 String id, bool mainAgentRunning, List<String> childSessionIds
});




}
/// @nodoc
class _$ActiveSessionCopyWithImpl<$Res>
    implements $ActiveSessionCopyWith<$Res> {
  _$ActiveSessionCopyWithImpl(this._self, this._then);

  final ActiveSession _self;
  final $Res Function(ActiveSession) _then;

/// Create a copy of ActiveSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? mainAgentRunning = null,Object? childSessionIds = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,mainAgentRunning: null == mainAgentRunning ? _self.mainAgentRunning : mainAgentRunning // ignore: cast_nullable_to_non_nullable
as bool,childSessionIds: null == childSessionIds ? _self.childSessionIds : childSessionIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _ActiveSession implements ActiveSession {
  const _ActiveSession({required this.id, this.mainAgentRunning = false, final  List<String> childSessionIds = const []}): _childSessionIds = childSessionIds;
  factory _ActiveSession.fromJson(Map<String, dynamic> json) => _$ActiveSessionFromJson(json);

@override final  String id;
@override@JsonKey() final  bool mainAgentRunning;
 final  List<String> _childSessionIds;
@override@JsonKey() List<String> get childSessionIds {
  if (_childSessionIds is EqualUnmodifiableListView) return _childSessionIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_childSessionIds);
}


/// Create a copy of ActiveSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ActiveSessionCopyWith<_ActiveSession> get copyWith => __$ActiveSessionCopyWithImpl<_ActiveSession>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ActiveSessionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ActiveSession&&(identical(other.id, id) || other.id == id)&&(identical(other.mainAgentRunning, mainAgentRunning) || other.mainAgentRunning == mainAgentRunning)&&const DeepCollectionEquality().equals(other._childSessionIds, _childSessionIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,mainAgentRunning,const DeepCollectionEquality().hash(_childSessionIds));

@override
String toString() {
  return 'ActiveSession(id: $id, mainAgentRunning: $mainAgentRunning, childSessionIds: $childSessionIds)';
}


}

/// @nodoc
abstract mixin class _$ActiveSessionCopyWith<$Res> implements $ActiveSessionCopyWith<$Res> {
  factory _$ActiveSessionCopyWith(_ActiveSession value, $Res Function(_ActiveSession) _then) = __$ActiveSessionCopyWithImpl;
@override @useResult
$Res call({
 String id, bool mainAgentRunning, List<String> childSessionIds
});




}
/// @nodoc
class __$ActiveSessionCopyWithImpl<$Res>
    implements _$ActiveSessionCopyWith<$Res> {
  __$ActiveSessionCopyWithImpl(this._self, this._then);

  final _ActiveSession _self;
  final $Res Function(_ActiveSession) _then;

/// Create a copy of ActiveSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? mainAgentRunning = null,Object? childSessionIds = null,}) {
  return _then(_ActiveSession(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,mainAgentRunning: null == mainAgentRunning ? _self.mainAgentRunning : mainAgentRunning // ignore: cast_nullable_to_non_nullable
as bool,childSessionIds: null == childSessionIds ? _self._childSessionIds : childSessionIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
