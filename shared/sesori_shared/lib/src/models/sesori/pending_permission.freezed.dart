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
mixin _$PendingPermissionResponse {

 List<PendingPermission> get data;
/// Create a copy of PendingPermissionResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PendingPermissionResponseCopyWith<PendingPermissionResponse> get copyWith => _$PendingPermissionResponseCopyWithImpl<PendingPermissionResponse>(this as PendingPermissionResponse, _$identity);

  /// Serializes this PendingPermissionResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PendingPermissionResponse&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'PendingPermissionResponse(data: $data)';
}


}

/// @nodoc
abstract mixin class $PendingPermissionResponseCopyWith<$Res>  {
  factory $PendingPermissionResponseCopyWith(PendingPermissionResponse value, $Res Function(PendingPermissionResponse) _then) = _$PendingPermissionResponseCopyWithImpl;
@useResult
$Res call({
 List<PendingPermission> data
});




}
/// @nodoc
class _$PendingPermissionResponseCopyWithImpl<$Res>
    implements $PendingPermissionResponseCopyWith<$Res> {
  _$PendingPermissionResponseCopyWithImpl(this._self, this._then);

  final PendingPermissionResponse _self;
  final $Res Function(PendingPermissionResponse) _then;

/// Create a copy of PendingPermissionResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<PendingPermission>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _PendingPermissionResponse implements PendingPermissionResponse {
  const _PendingPermissionResponse({required final  List<PendingPermission> data}): _data = data;
  factory _PendingPermissionResponse.fromJson(Map<String, dynamic> json) => _$PendingPermissionResponseFromJson(json);

 final  List<PendingPermission> _data;
@override List<PendingPermission> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of PendingPermissionResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PendingPermissionResponseCopyWith<_PendingPermissionResponse> get copyWith => __$PendingPermissionResponseCopyWithImpl<_PendingPermissionResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PendingPermissionResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PendingPermissionResponse&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'PendingPermissionResponse(data: $data)';
}


}

/// @nodoc
abstract mixin class _$PendingPermissionResponseCopyWith<$Res> implements $PendingPermissionResponseCopyWith<$Res> {
  factory _$PendingPermissionResponseCopyWith(_PendingPermissionResponse value, $Res Function(_PendingPermissionResponse) _then) = __$PendingPermissionResponseCopyWithImpl;
@override @useResult
$Res call({
 List<PendingPermission> data
});




}
/// @nodoc
class __$PendingPermissionResponseCopyWithImpl<$Res>
    implements _$PendingPermissionResponseCopyWith<$Res> {
  __$PendingPermissionResponseCopyWithImpl(this._self, this._then);

  final _PendingPermissionResponse _self;
  final $Res Function(_PendingPermissionResponse) _then;

/// Create a copy of PendingPermissionResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_PendingPermissionResponse(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<PendingPermission>,
  ));
}


}


/// @nodoc
mixin _$PendingPermission {

 String get id; String get sessionID; String get tool; String get description;
/// Create a copy of PendingPermission
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PendingPermissionCopyWith<PendingPermission> get copyWith => _$PendingPermissionCopyWithImpl<PendingPermission>(this as PendingPermission, _$identity);

  /// Serializes this PendingPermission to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PendingPermission&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,tool,description);

@override
String toString() {
  return 'PendingPermission(id: $id, sessionID: $sessionID, tool: $tool, description: $description)';
}


}

/// @nodoc
abstract mixin class $PendingPermissionCopyWith<$Res>  {
  factory $PendingPermissionCopyWith(PendingPermission value, $Res Function(PendingPermission) _then) = _$PendingPermissionCopyWithImpl;
@useResult
$Res call({
 String id, String sessionID, String tool, String description
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sessionID = null,Object? tool = null,Object? description = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,tool: null == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _PendingPermission implements PendingPermission {
  const _PendingPermission({required this.id, required this.sessionID, required this.tool, required this.description});
  factory _PendingPermission.fromJson(Map<String, dynamic> json) => _$PendingPermissionFromJson(json);

@override final  String id;
@override final  String sessionID;
@override final  String tool;
@override final  String description;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PendingPermission&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,tool,description);

@override
String toString() {
  return 'PendingPermission(id: $id, sessionID: $sessionID, tool: $tool, description: $description)';
}


}

/// @nodoc
abstract mixin class _$PendingPermissionCopyWith<$Res> implements $PendingPermissionCopyWith<$Res> {
  factory _$PendingPermissionCopyWith(_PendingPermission value, $Res Function(_PendingPermission) _then) = __$PendingPermissionCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, String tool, String description
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? tool = null,Object? description = null,}) {
  return _then(_PendingPermission(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,tool: null == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
