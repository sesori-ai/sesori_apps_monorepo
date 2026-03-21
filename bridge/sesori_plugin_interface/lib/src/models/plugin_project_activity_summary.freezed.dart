// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_project_activity_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PluginProjectActivitySummary {

 String get id; List<PluginActiveSession> get activeSessions;
/// Create a copy of PluginProjectActivitySummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginProjectActivitySummaryCopyWith<PluginProjectActivitySummary> get copyWith => _$PluginProjectActivitySummaryCopyWithImpl<PluginProjectActivitySummary>(this as PluginProjectActivitySummary, _$identity);

  /// Serializes this PluginProjectActivitySummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginProjectActivitySummary&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other.activeSessions, activeSessions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,const DeepCollectionEquality().hash(activeSessions));

@override
String toString() {
  return 'PluginProjectActivitySummary(id: $id, activeSessions: $activeSessions)';
}


}

/// @nodoc
abstract mixin class $PluginProjectActivitySummaryCopyWith<$Res>  {
  factory $PluginProjectActivitySummaryCopyWith(PluginProjectActivitySummary value, $Res Function(PluginProjectActivitySummary) _then) = _$PluginProjectActivitySummaryCopyWithImpl;
@useResult
$Res call({
 String id, List<PluginActiveSession> activeSessions
});




}
/// @nodoc
class _$PluginProjectActivitySummaryCopyWithImpl<$Res>
    implements $PluginProjectActivitySummaryCopyWith<$Res> {
  _$PluginProjectActivitySummaryCopyWithImpl(this._self, this._then);

  final PluginProjectActivitySummary _self;
  final $Res Function(PluginProjectActivitySummary) _then;

/// Create a copy of PluginProjectActivitySummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? activeSessions = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,activeSessions: null == activeSessions ? _self.activeSessions : activeSessions // ignore: cast_nullable_to_non_nullable
as List<PluginActiveSession>,
  ));
}

}



/// @nodoc
@JsonSerializable(createFactory: false)

class _PluginProjectActivitySummary implements PluginProjectActivitySummary {
  const _PluginProjectActivitySummary({required this.id, required final  List<PluginActiveSession> activeSessions}): _activeSessions = activeSessions;
  

@override final  String id;
 final  List<PluginActiveSession> _activeSessions;
@override List<PluginActiveSession> get activeSessions {
  if (_activeSessions is EqualUnmodifiableListView) return _activeSessions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_activeSessions);
}


/// Create a copy of PluginProjectActivitySummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginProjectActivitySummaryCopyWith<_PluginProjectActivitySummary> get copyWith => __$PluginProjectActivitySummaryCopyWithImpl<_PluginProjectActivitySummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginProjectActivitySummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginProjectActivitySummary&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other._activeSessions, _activeSessions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,const DeepCollectionEquality().hash(_activeSessions));

@override
String toString() {
  return 'PluginProjectActivitySummary(id: $id, activeSessions: $activeSessions)';
}


}

/// @nodoc
abstract mixin class _$PluginProjectActivitySummaryCopyWith<$Res> implements $PluginProjectActivitySummaryCopyWith<$Res> {
  factory _$PluginProjectActivitySummaryCopyWith(_PluginProjectActivitySummary value, $Res Function(_PluginProjectActivitySummary) _then) = __$PluginProjectActivitySummaryCopyWithImpl;
@override @useResult
$Res call({
 String id, List<PluginActiveSession> activeSessions
});




}
/// @nodoc
class __$PluginProjectActivitySummaryCopyWithImpl<$Res>
    implements _$PluginProjectActivitySummaryCopyWith<$Res> {
  __$PluginProjectActivitySummaryCopyWithImpl(this._self, this._then);

  final _PluginProjectActivitySummary _self;
  final $Res Function(_PluginProjectActivitySummary) _then;

/// Create a copy of PluginProjectActivitySummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? activeSessions = null,}) {
  return _then(_PluginProjectActivitySummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,activeSessions: null == activeSessions ? _self._activeSessions : activeSessions // ignore: cast_nullable_to_non_nullable
as List<PluginActiveSession>,
  ));
}


}

// dart format on
