// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'rename_project_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RenameProjectRequest {

 String get projectId; String get name;
/// Create a copy of RenameProjectRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RenameProjectRequestCopyWith<RenameProjectRequest> get copyWith => _$RenameProjectRequestCopyWithImpl<RenameProjectRequest>(this as RenameProjectRequest, _$identity);

  /// Serializes this RenameProjectRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RenameProjectRequest&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,projectId,name);

@override
String toString() {
  return 'RenameProjectRequest(projectId: $projectId, name: $name)';
}


}

/// @nodoc
abstract mixin class $RenameProjectRequestCopyWith<$Res>  {
  factory $RenameProjectRequestCopyWith(RenameProjectRequest value, $Res Function(RenameProjectRequest) _then) = _$RenameProjectRequestCopyWithImpl;
@useResult
$Res call({
 String projectId, String name
});




}
/// @nodoc
class _$RenameProjectRequestCopyWithImpl<$Res>
    implements $RenameProjectRequestCopyWith<$Res> {
  _$RenameProjectRequestCopyWithImpl(this._self, this._then);

  final RenameProjectRequest _self;
  final $Res Function(RenameProjectRequest) _then;

/// Create a copy of RenameProjectRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? projectId = null,Object? name = null,}) {
  return _then(_self.copyWith(
projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _RenameProjectRequest implements RenameProjectRequest {
  const _RenameProjectRequest({required this.projectId, required this.name});
  factory _RenameProjectRequest.fromJson(Map<String, dynamic> json) => _$RenameProjectRequestFromJson(json);

@override final  String projectId;
@override final  String name;

/// Create a copy of RenameProjectRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RenameProjectRequestCopyWith<_RenameProjectRequest> get copyWith => __$RenameProjectRequestCopyWithImpl<_RenameProjectRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RenameProjectRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RenameProjectRequest&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,projectId,name);

@override
String toString() {
  return 'RenameProjectRequest(projectId: $projectId, name: $name)';
}


}

/// @nodoc
abstract mixin class _$RenameProjectRequestCopyWith<$Res> implements $RenameProjectRequestCopyWith<$Res> {
  factory _$RenameProjectRequestCopyWith(_RenameProjectRequest value, $Res Function(_RenameProjectRequest) _then) = __$RenameProjectRequestCopyWithImpl;
@override @useResult
$Res call({
 String projectId, String name
});




}
/// @nodoc
class __$RenameProjectRequestCopyWithImpl<$Res>
    implements _$RenameProjectRequestCopyWith<$Res> {
  __$RenameProjectRequestCopyWithImpl(this._self, this._then);

  final _RenameProjectRequest _self;
  final $Res Function(_RenameProjectRequest) _then;

/// Create a copy of RenameProjectRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? projectId = null,Object? name = null,}) {
  return _then(_RenameProjectRequest(
projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
