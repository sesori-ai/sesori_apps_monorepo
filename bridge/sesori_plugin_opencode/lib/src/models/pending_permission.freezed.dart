// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pending_permission.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PendingPermission {

 String get id; String get sessionID; String get permission;
/// Create a copy of PendingPermission
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PendingPermissionCopyWith<PendingPermission> get copyWith => _$PendingPermissionCopyWithImpl<PendingPermission>(this as PendingPermission, _$identity);

  /// Serializes this PendingPermission to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PendingPermission&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.permission, permission) || other.permission == permission));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,permission);

@override
String toString() {
  return 'PendingPermission(id: $id, sessionID: $sessionID, permission: $permission)';
}


}

/// @nodoc
abstract mixin class $PendingPermissionCopyWith<$Res>  {
  factory $PendingPermissionCopyWith(PendingPermission value, $Res Function(PendingPermission) _then) = _$PendingPermissionCopyWithImpl;
@useResult
$Res call({
 String id, String sessionID, String permission
});




}
/// @nodoc
class _$PendingPermissionCopyWithImpl<$Res>
    implements $PendingPermissionCopyWith<$Res> {
  _$PendingPermissionCopyWithImpl(this._self, this._then);

  final PendingPermission _self;
  final $Res Function(PendingPermission) _then;

/// Create a copy of PendingPermission
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sessionID = null,Object? permission = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,permission: null == permission ? _self.permission : permission // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _PendingPermission implements PendingPermission {
  const _PendingPermission({required this.id, required this.sessionID, required this.permission});
  factory _PendingPermission.fromJson(Map<String, dynamic> json) => _$PendingPermissionFromJson(json);

@override final  String id;
@override final  String sessionID;
@override final  String permission;

/// Create a copy of PendingPermission
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PendingPermissionCopyWith<_PendingPermission> get copyWith => __$PendingPermissionCopyWithImpl<_PendingPermission>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PendingPermissionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PendingPermission&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.permission, permission) || other.permission == permission));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,permission);

@override
String toString() {
  return 'PendingPermission(id: $id, sessionID: $sessionID, permission: $permission)';
}


}

/// @nodoc
abstract mixin class _$PendingPermissionCopyWith<$Res> implements $PendingPermissionCopyWith<$Res> {
  factory _$PendingPermissionCopyWith(_PendingPermission value, $Res Function(_PendingPermission) _then) = __$PendingPermissionCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String permission
});




}
/// @nodoc
class __$PendingPermissionCopyWithImpl<$Res>
    implements _$PendingPermissionCopyWith<$Res> {
  __$PendingPermissionCopyWithImpl(this._self, this._then);

  final _PendingPermission _self;
  final $Res Function(_PendingPermission) _then;

/// Create a copy of PendingPermission
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? permission = null,}) {
  return _then(_PendingPermission(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,permission: null == permission ? _self.permission : permission // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
