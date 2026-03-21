// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'create_session_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CreateSessionRequest {

 String get projectId; String? get parentSessionId;
/// Create a copy of CreateSessionRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CreateSessionRequestCopyWith<CreateSessionRequest> get copyWith => _$CreateSessionRequestCopyWithImpl<CreateSessionRequest>(this as CreateSessionRequest, _$identity);

  /// Serializes this CreateSessionRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CreateSessionRequest&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.parentSessionId, parentSessionId) || other.parentSessionId == parentSessionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,projectId,parentSessionId);

@override
String toString() {
  return 'CreateSessionRequest(projectId: $projectId, parentSessionId: $parentSessionId)';
}


}

/// @nodoc
abstract mixin class $CreateSessionRequestCopyWith<$Res>  {
  factory $CreateSessionRequestCopyWith(CreateSessionRequest value, $Res Function(CreateSessionRequest) _then) = _$CreateSessionRequestCopyWithImpl;
@useResult
$Res call({
 String projectId, String? parentSessionId
});




}
/// @nodoc
class _$CreateSessionRequestCopyWithImpl<$Res>
    implements $CreateSessionRequestCopyWith<$Res> {
  _$CreateSessionRequestCopyWithImpl(this._self, this._then);

  final CreateSessionRequest _self;
  final $Res Function(CreateSessionRequest) _then;

/// Create a copy of CreateSessionRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? projectId = null,Object? parentSessionId = freezed,}) {
  return _then(_self.copyWith(
projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,parentSessionId: freezed == parentSessionId ? _self.parentSessionId : parentSessionId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _CreateSessionRequest implements CreateSessionRequest {
  const _CreateSessionRequest({required this.projectId, required this.parentSessionId});
  factory _CreateSessionRequest.fromJson(Map<String, dynamic> json) => _$CreateSessionRequestFromJson(json);

@override final  String projectId;
@override final  String? parentSessionId;

/// Create a copy of CreateSessionRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CreateSessionRequestCopyWith<_CreateSessionRequest> get copyWith => __$CreateSessionRequestCopyWithImpl<_CreateSessionRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CreateSessionRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CreateSessionRequest&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.parentSessionId, parentSessionId) || other.parentSessionId == parentSessionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,projectId,parentSessionId);

@override
String toString() {
  return 'CreateSessionRequest(projectId: $projectId, parentSessionId: $parentSessionId)';
}


}

/// @nodoc
abstract mixin class _$CreateSessionRequestCopyWith<$Res> implements $CreateSessionRequestCopyWith<$Res> {
  factory _$CreateSessionRequestCopyWith(_CreateSessionRequest value, $Res Function(_CreateSessionRequest) _then) = __$CreateSessionRequestCopyWithImpl;
@override @useResult
$Res call({
 String projectId, String? parentSessionId
});




}
/// @nodoc
class __$CreateSessionRequestCopyWithImpl<$Res>
    implements _$CreateSessionRequestCopyWith<$Res> {
  __$CreateSessionRequestCopyWithImpl(this._self, this._then);

  final _CreateSessionRequest _self;
  final $Res Function(_CreateSessionRequest) _then;

/// Create a copy of CreateSessionRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? projectId = null,Object? parentSessionId = freezed,}) {
  return _then(_CreateSessionRequest(
projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,parentSessionId: freezed == parentSessionId ? _self.parentSessionId : parentSessionId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
