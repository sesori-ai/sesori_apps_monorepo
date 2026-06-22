// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_pending_permission.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PluginPendingPermission {

 String get id; String get sessionID;/// Top-most root session this request should be surfaced under (for a
/// child/sub-agent session's request). Null when unknown.
 String? get displaySessionId; String get tool; String get description;
/// Create a copy of PluginPendingPermission
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginPendingPermissionCopyWith<PluginPendingPermission> get copyWith => _$PluginPendingPermissionCopyWithImpl<PluginPendingPermission>(this as PluginPendingPermission, _$identity);

  /// Serializes this PluginPendingPermission to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginPendingPermission&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.displaySessionId, displaySessionId) || other.displaySessionId == displaySessionId)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,displaySessionId,tool,description);

@override
String toString() {
  return 'PluginPendingPermission(id: $id, sessionID: $sessionID, displaySessionId: $displaySessionId, tool: $tool, description: $description)';
}


}

/// @nodoc
abstract mixin class $PluginPendingPermissionCopyWith<$Res>  {
  factory $PluginPendingPermissionCopyWith(PluginPendingPermission value, $Res Function(PluginPendingPermission) _then) = _$PluginPendingPermissionCopyWithImpl;
@useResult
$Res call({
 String id, String sessionID, String? displaySessionId, String tool, String description
});




}
/// @nodoc
class _$PluginPendingPermissionCopyWithImpl<$Res>
    implements $PluginPendingPermissionCopyWith<$Res> {
  _$PluginPendingPermissionCopyWithImpl(this._self, this._then);

  final PluginPendingPermission _self;
  final $Res Function(PluginPendingPermission) _then;

/// Create a copy of PluginPendingPermission
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sessionID = null,Object? displaySessionId = freezed,Object? tool = null,Object? description = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,displaySessionId: freezed == displaySessionId ? _self.displaySessionId : displaySessionId // ignore: cast_nullable_to_non_nullable
as String?,tool: null == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable(createFactory: false)

class _PluginPendingPermission implements PluginPendingPermission {
  const _PluginPendingPermission({required this.id, required this.sessionID, required this.displaySessionId, required this.tool, required this.description});
  

@override final  String id;
@override final  String sessionID;
/// Top-most root session this request should be surfaced under (for a
/// child/sub-agent session's request). Null when unknown.
@override final  String? displaySessionId;
@override final  String tool;
@override final  String description;

/// Create a copy of PluginPendingPermission
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginPendingPermissionCopyWith<_PluginPendingPermission> get copyWith => __$PluginPendingPermissionCopyWithImpl<_PluginPendingPermission>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginPendingPermissionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginPendingPermission&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.displaySessionId, displaySessionId) || other.displaySessionId == displaySessionId)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,displaySessionId,tool,description);

@override
String toString() {
  return 'PluginPendingPermission(id: $id, sessionID: $sessionID, displaySessionId: $displaySessionId, tool: $tool, description: $description)';
}


}

/// @nodoc
abstract mixin class _$PluginPendingPermissionCopyWith<$Res> implements $PluginPendingPermissionCopyWith<$Res> {
  factory _$PluginPendingPermissionCopyWith(_PluginPendingPermission value, $Res Function(_PluginPendingPermission) _then) = __$PluginPendingPermissionCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String? displaySessionId, String tool, String description
});




}
/// @nodoc
class __$PluginPendingPermissionCopyWithImpl<$Res>
    implements _$PluginPendingPermissionCopyWith<$Res> {
  __$PluginPendingPermissionCopyWithImpl(this._self, this._then);

  final _PluginPendingPermission _self;
  final $Res Function(_PluginPendingPermission) _then;

/// Create a copy of PluginPendingPermission
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? displaySessionId = freezed,Object? tool = null,Object? description = null,}) {
  return _then(_PluginPendingPermission(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,displaySessionId: freezed == displaySessionId ? _self.displaySessionId : displaySessionId // ignore: cast_nullable_to_non_nullable
as String?,tool: null == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
