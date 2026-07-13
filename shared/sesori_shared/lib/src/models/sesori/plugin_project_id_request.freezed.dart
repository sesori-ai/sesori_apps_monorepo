// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_project_id_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PluginProjectIdRequest {

 String get projectId; String get pluginId;
/// Create a copy of PluginProjectIdRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginProjectIdRequestCopyWith<PluginProjectIdRequest> get copyWith => _$PluginProjectIdRequestCopyWithImpl<PluginProjectIdRequest>(this as PluginProjectIdRequest, _$identity);

  /// Serializes this PluginProjectIdRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginProjectIdRequest&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,projectId,pluginId);

@override
String toString() {
  return 'PluginProjectIdRequest(projectId: $projectId, pluginId: $pluginId)';
}


}

/// @nodoc
abstract mixin class $PluginProjectIdRequestCopyWith<$Res>  {
  factory $PluginProjectIdRequestCopyWith(PluginProjectIdRequest value, $Res Function(PluginProjectIdRequest) _then) = _$PluginProjectIdRequestCopyWithImpl;
@useResult
$Res call({
 String projectId, String pluginId
});




}
/// @nodoc
class _$PluginProjectIdRequestCopyWithImpl<$Res>
    implements $PluginProjectIdRequestCopyWith<$Res> {
  _$PluginProjectIdRequestCopyWithImpl(this._self, this._then);

  final PluginProjectIdRequest _self;
  final $Res Function(PluginProjectIdRequest) _then;

/// Create a copy of PluginProjectIdRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? projectId = null,Object? pluginId = null,}) {
  return _then(_self.copyWith(
projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _PluginProjectIdRequest implements PluginProjectIdRequest {
  const _PluginProjectIdRequest({required this.projectId, this.pluginId = legacyMissingPluginId});
  factory _PluginProjectIdRequest.fromJson(Map<String, dynamic> json) => _$PluginProjectIdRequestFromJson(json);

@override final  String projectId;
@override@JsonKey() final  String pluginId;

/// Create a copy of PluginProjectIdRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginProjectIdRequestCopyWith<_PluginProjectIdRequest> get copyWith => __$PluginProjectIdRequestCopyWithImpl<_PluginProjectIdRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginProjectIdRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginProjectIdRequest&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,projectId,pluginId);

@override
String toString() {
  return 'PluginProjectIdRequest(projectId: $projectId, pluginId: $pluginId)';
}


}

/// @nodoc
abstract mixin class _$PluginProjectIdRequestCopyWith<$Res> implements $PluginProjectIdRequestCopyWith<$Res> {
  factory _$PluginProjectIdRequestCopyWith(_PluginProjectIdRequest value, $Res Function(_PluginProjectIdRequest) _then) = __$PluginProjectIdRequestCopyWithImpl;
@override @useResult
$Res call({
 String projectId, String pluginId
});




}
/// @nodoc
class __$PluginProjectIdRequestCopyWithImpl<$Res>
    implements _$PluginProjectIdRequestCopyWith<$Res> {
  __$PluginProjectIdRequestCopyWithImpl(this._self, this._then);

  final _PluginProjectIdRequest _self;
  final $Res Function(_PluginProjectIdRequest) _then;

/// Create a copy of PluginProjectIdRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? projectId = null,Object? pluginId = null,}) {
  return _then(_PluginProjectIdRequest(
projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
