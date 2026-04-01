// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'set_base_branch_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SetBaseBranchRequest {

 String get projectId; String get baseBranch;
/// Create a copy of SetBaseBranchRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SetBaseBranchRequestCopyWith<SetBaseBranchRequest> get copyWith => _$SetBaseBranchRequestCopyWithImpl<SetBaseBranchRequest>(this as SetBaseBranchRequest, _$identity);

  /// Serializes this SetBaseBranchRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SetBaseBranchRequest&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.baseBranch, baseBranch) || other.baseBranch == baseBranch));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,projectId,baseBranch);

@override
String toString() {
  return 'SetBaseBranchRequest(projectId: $projectId, baseBranch: $baseBranch)';
}


}

/// @nodoc
abstract mixin class $SetBaseBranchRequestCopyWith<$Res>  {
  factory $SetBaseBranchRequestCopyWith(SetBaseBranchRequest value, $Res Function(SetBaseBranchRequest) _then) = _$SetBaseBranchRequestCopyWithImpl;
@useResult
$Res call({
 String projectId, String baseBranch
});




}
/// @nodoc
class _$SetBaseBranchRequestCopyWithImpl<$Res>
    implements $SetBaseBranchRequestCopyWith<$Res> {
  _$SetBaseBranchRequestCopyWithImpl(this._self, this._then);

  final SetBaseBranchRequest _self;
  final $Res Function(SetBaseBranchRequest) _then;

/// Create a copy of SetBaseBranchRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? projectId = null,Object? baseBranch = null,}) {
  return _then(_self.copyWith(
projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,baseBranch: null == baseBranch ? _self.baseBranch : baseBranch // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SetBaseBranchRequest implements SetBaseBranchRequest {
  const _SetBaseBranchRequest({required this.projectId, required this.baseBranch});
  factory _SetBaseBranchRequest.fromJson(Map<String, dynamic> json) => _$SetBaseBranchRequestFromJson(json);

@override final  String projectId;
@override final  String baseBranch;

/// Create a copy of SetBaseBranchRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SetBaseBranchRequestCopyWith<_SetBaseBranchRequest> get copyWith => __$SetBaseBranchRequestCopyWithImpl<_SetBaseBranchRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SetBaseBranchRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SetBaseBranchRequest&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.baseBranch, baseBranch) || other.baseBranch == baseBranch));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,projectId,baseBranch);

@override
String toString() {
  return 'SetBaseBranchRequest(projectId: $projectId, baseBranch: $baseBranch)';
}


}

/// @nodoc
abstract mixin class _$SetBaseBranchRequestCopyWith<$Res> implements $SetBaseBranchRequestCopyWith<$Res> {
  factory _$SetBaseBranchRequestCopyWith(_SetBaseBranchRequest value, $Res Function(_SetBaseBranchRequest) _then) = __$SetBaseBranchRequestCopyWithImpl;
@override @useResult
$Res call({
 String projectId, String baseBranch
});




}
/// @nodoc
class __$SetBaseBranchRequestCopyWithImpl<$Res>
    implements _$SetBaseBranchRequestCopyWith<$Res> {
  __$SetBaseBranchRequestCopyWithImpl(this._self, this._then);

  final _SetBaseBranchRequest _self;
  final $Res Function(_SetBaseBranchRequest) _then;

/// Create a copy of SetBaseBranchRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? projectId = null,Object? baseBranch = null,}) {
  return _then(_SetBaseBranchRequest(
projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,baseBranch: null == baseBranch ? _self.baseBranch : baseBranch // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
