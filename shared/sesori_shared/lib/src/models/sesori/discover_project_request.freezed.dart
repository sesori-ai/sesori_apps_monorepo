// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'discover_project_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DiscoverProjectRequest {

 String get path;
/// Create a copy of DiscoverProjectRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiscoverProjectRequestCopyWith<DiscoverProjectRequest> get copyWith => _$DiscoverProjectRequestCopyWithImpl<DiscoverProjectRequest>(this as DiscoverProjectRequest, _$identity);

  /// Serializes this DiscoverProjectRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiscoverProjectRequest&&(identical(other.path, path) || other.path == path));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path);

@override
String toString() {
  return 'DiscoverProjectRequest(path: $path)';
}


}

/// @nodoc
abstract mixin class $DiscoverProjectRequestCopyWith<$Res>  {
  factory $DiscoverProjectRequestCopyWith(DiscoverProjectRequest value, $Res Function(DiscoverProjectRequest) _then) = _$DiscoverProjectRequestCopyWithImpl;
@useResult
$Res call({
 String path
});




}
/// @nodoc
class _$DiscoverProjectRequestCopyWithImpl<$Res>
    implements $DiscoverProjectRequestCopyWith<$Res> {
  _$DiscoverProjectRequestCopyWithImpl(this._self, this._then);

  final DiscoverProjectRequest _self;
  final $Res Function(DiscoverProjectRequest) _then;

/// Create a copy of DiscoverProjectRequest
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

class _DiscoverProjectRequest implements DiscoverProjectRequest {
  const _DiscoverProjectRequest({required this.path});
  factory _DiscoverProjectRequest.fromJson(Map<String, dynamic> json) => _$DiscoverProjectRequestFromJson(json);

@override final  String path;

/// Create a copy of DiscoverProjectRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DiscoverProjectRequestCopyWith<_DiscoverProjectRequest> get copyWith => __$DiscoverProjectRequestCopyWithImpl<_DiscoverProjectRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DiscoverProjectRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DiscoverProjectRequest&&(identical(other.path, path) || other.path == path));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path);

@override
String toString() {
  return 'DiscoverProjectRequest(path: $path)';
}


}

/// @nodoc
abstract mixin class _$DiscoverProjectRequestCopyWith<$Res> implements $DiscoverProjectRequestCopyWith<$Res> {
  factory _$DiscoverProjectRequestCopyWith(_DiscoverProjectRequest value, $Res Function(_DiscoverProjectRequest) _then) = __$DiscoverProjectRequestCopyWithImpl;
@override @useResult
$Res call({
 String path
});




}
/// @nodoc
class __$DiscoverProjectRequestCopyWithImpl<$Res>
    implements _$DiscoverProjectRequestCopyWith<$Res> {
  __$DiscoverProjectRequestCopyWithImpl(this._self, this._then);

  final _DiscoverProjectRequest _self;
  final $Res Function(_DiscoverProjectRequest) _then;

/// Create a copy of DiscoverProjectRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,}) {
  return _then(_DiscoverProjectRequest(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
