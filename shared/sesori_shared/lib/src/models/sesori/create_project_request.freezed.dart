// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'create_project_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CreateProjectRequest {

 String get path;
/// Create a copy of CreateProjectRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CreateProjectRequestCopyWith<CreateProjectRequest> get copyWith => _$CreateProjectRequestCopyWithImpl<CreateProjectRequest>(this as CreateProjectRequest, _$identity);

  /// Serializes this CreateProjectRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CreateProjectRequest&&(identical(other.path, path) || other.path == path));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path);

@override
String toString() {
  return 'CreateProjectRequest(path: $path)';
}


}

/// @nodoc
abstract mixin class $CreateProjectRequestCopyWith<$Res>  {
  factory $CreateProjectRequestCopyWith(CreateProjectRequest value, $Res Function(CreateProjectRequest) _then) = _$CreateProjectRequestCopyWithImpl;
@useResult
$Res call({
 String path
});




}
/// @nodoc
class _$CreateProjectRequestCopyWithImpl<$Res>
    implements $CreateProjectRequestCopyWith<$Res> {
  _$CreateProjectRequestCopyWithImpl(this._self, this._then);

  final CreateProjectRequest _self;
  final $Res Function(CreateProjectRequest) _then;

/// Create a copy of CreateProjectRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = null,}) {
  return _then(_self.copyWith(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _CreateProjectRequest implements CreateProjectRequest {
  const _CreateProjectRequest({required this.path});
  factory _CreateProjectRequest.fromJson(Map<String, dynamic> json) => _$CreateProjectRequestFromJson(json);

@override final  String path;

/// Create a copy of CreateProjectRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CreateProjectRequestCopyWith<_CreateProjectRequest> get copyWith => __$CreateProjectRequestCopyWithImpl<_CreateProjectRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CreateProjectRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CreateProjectRequest&&(identical(other.path, path) || other.path == path));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path);

@override
String toString() {
  return 'CreateProjectRequest(path: $path)';
}


}

/// @nodoc
abstract mixin class _$CreateProjectRequestCopyWith<$Res> implements $CreateProjectRequestCopyWith<$Res> {
  factory _$CreateProjectRequestCopyWith(_CreateProjectRequest value, $Res Function(_CreateProjectRequest) _then) = __$CreateProjectRequestCopyWithImpl;
@override @useResult
$Res call({
 String path
});




}
/// @nodoc
class __$CreateProjectRequestCopyWithImpl<$Res>
    implements _$CreateProjectRequestCopyWith<$Res> {
  __$CreateProjectRequestCopyWithImpl(this._self, this._then);

  final _CreateProjectRequest _self;
  final $Res Function(_CreateProjectRequest) _then;

/// Create a copy of CreateProjectRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,}) {
  return _then(_CreateProjectRequest(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
