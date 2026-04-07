// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_active_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PluginActiveSession {

 String get id; bool get mainAgentRunning; bool get awaitingInput; List<String> get childSessionIds;
/// Create a copy of PluginActiveSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginActiveSessionCopyWith<PluginActiveSession> get copyWith => _$PluginActiveSessionCopyWithImpl<PluginActiveSession>(this as PluginActiveSession, _$identity);

  /// Serializes this PluginActiveSession to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginActiveSession&&(identical(other.id, id) || other.id == id)&&(identical(other.mainAgentRunning, mainAgentRunning) || other.mainAgentRunning == mainAgentRunning)&&(identical(other.awaitingInput, awaitingInput) || other.awaitingInput == awaitingInput)&&const DeepCollectionEquality().equals(other.childSessionIds, childSessionIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,mainAgentRunning,awaitingInput,const DeepCollectionEquality().hash(childSessionIds));

@override
String toString() {
  return 'PluginActiveSession(id: $id, mainAgentRunning: $mainAgentRunning, awaitingInput: $awaitingInput, childSessionIds: $childSessionIds)';
}


}

/// @nodoc
abstract mixin class $PluginActiveSessionCopyWith<$Res>  {
  factory $PluginActiveSessionCopyWith(PluginActiveSession value, $Res Function(PluginActiveSession) _then) = _$PluginActiveSessionCopyWithImpl;
@useResult
$Res call({
 String id, bool mainAgentRunning, bool awaitingInput, List<String> childSessionIds
});




}
/// @nodoc
class _$PluginActiveSessionCopyWithImpl<$Res>
    implements $PluginActiveSessionCopyWith<$Res> {
  _$PluginActiveSessionCopyWithImpl(this._self, this._then);

  final PluginActiveSession _self;
  final $Res Function(PluginActiveSession) _then;

/// Create a copy of PluginActiveSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? mainAgentRunning = null,Object? awaitingInput = null,Object? childSessionIds = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,mainAgentRunning: null == mainAgentRunning ? _self.mainAgentRunning : mainAgentRunning // ignore: cast_nullable_to_non_nullable
as bool,awaitingInput: null == awaitingInput ? _self.awaitingInput : awaitingInput // ignore: cast_nullable_to_non_nullable
as bool,childSessionIds: null == childSessionIds ? _self.childSessionIds : childSessionIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}



/// @nodoc
@JsonSerializable(createFactory: false)

class _PluginActiveSession implements PluginActiveSession {
  const _PluginActiveSession({required this.id, this.mainAgentRunning = false, this.awaitingInput = false, final  List<String> childSessionIds = const []}): _childSessionIds = childSessionIds;
  

@override final  String id;
@override@JsonKey() final  bool mainAgentRunning;
@override@JsonKey() final  bool awaitingInput;
 final  List<String> _childSessionIds;
@override@JsonKey() List<String> get childSessionIds {
  if (_childSessionIds is EqualUnmodifiableListView) return _childSessionIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_childSessionIds);
}


/// Create a copy of PluginActiveSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginActiveSessionCopyWith<_PluginActiveSession> get copyWith => __$PluginActiveSessionCopyWithImpl<_PluginActiveSession>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginActiveSessionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginActiveSession&&(identical(other.id, id) || other.id == id)&&(identical(other.mainAgentRunning, mainAgentRunning) || other.mainAgentRunning == mainAgentRunning)&&(identical(other.awaitingInput, awaitingInput) || other.awaitingInput == awaitingInput)&&const DeepCollectionEquality().equals(other._childSessionIds, _childSessionIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,mainAgentRunning,awaitingInput,const DeepCollectionEquality().hash(_childSessionIds));

@override
String toString() {
  return 'PluginActiveSession(id: $id, mainAgentRunning: $mainAgentRunning, awaitingInput: $awaitingInput, childSessionIds: $childSessionIds)';
}


}

/// @nodoc
abstract mixin class _$PluginActiveSessionCopyWith<$Res> implements $PluginActiveSessionCopyWith<$Res> {
  factory _$PluginActiveSessionCopyWith(_PluginActiveSession value, $Res Function(_PluginActiveSession) _then) = __$PluginActiveSessionCopyWithImpl;
@override @useResult
$Res call({
 String id, bool mainAgentRunning, bool awaitingInput, List<String> childSessionIds
});




}
/// @nodoc
class __$PluginActiveSessionCopyWithImpl<$Res>
    implements _$PluginActiveSessionCopyWith<$Res> {
  __$PluginActiveSessionCopyWithImpl(this._self, this._then);

  final _PluginActiveSession _self;
  final $Res Function(_PluginActiveSession) _then;

/// Create a copy of PluginActiveSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? mainAgentRunning = null,Object? awaitingInput = null,Object? childSessionIds = null,}) {
  return _then(_PluginActiveSession(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,mainAgentRunning: null == mainAgentRunning ? _self.mainAgentRunning : mainAgentRunning // ignore: cast_nullable_to_non_nullable
as bool,awaitingInput: null == awaitingInput ? _self.awaitingInput : awaitingInput // ignore: cast_nullable_to_non_nullable
as bool,childSessionIds: null == childSessionIds ? _self._childSessionIds : childSessionIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
