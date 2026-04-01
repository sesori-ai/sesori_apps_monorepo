// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'delete_session_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DeleteSessionRequest {

 String get sessionId; bool get deleteWorktree; bool get deleteBranch; bool get force;
/// Create a copy of DeleteSessionRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeleteSessionRequestCopyWith<DeleteSessionRequest> get copyWith => _$DeleteSessionRequestCopyWithImpl<DeleteSessionRequest>(this as DeleteSessionRequest, _$identity);

  /// Serializes this DeleteSessionRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeleteSessionRequest&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.deleteWorktree, deleteWorktree) || other.deleteWorktree == deleteWorktree)&&(identical(other.deleteBranch, deleteBranch) || other.deleteBranch == deleteBranch)&&(identical(other.force, force) || other.force == force));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,deleteWorktree,deleteBranch,force);

@override
String toString() {
  return 'DeleteSessionRequest(sessionId: $sessionId, deleteWorktree: $deleteWorktree, deleteBranch: $deleteBranch, force: $force)';
}


}

/// @nodoc
abstract mixin class $DeleteSessionRequestCopyWith<$Res>  {
  factory $DeleteSessionRequestCopyWith(DeleteSessionRequest value, $Res Function(DeleteSessionRequest) _then) = _$DeleteSessionRequestCopyWithImpl;
@useResult
$Res call({
 String sessionId, bool deleteWorktree, bool deleteBranch, bool force
});




}
/// @nodoc
class _$DeleteSessionRequestCopyWithImpl<$Res>
    implements $DeleteSessionRequestCopyWith<$Res> {
  _$DeleteSessionRequestCopyWithImpl(this._self, this._then);

  final DeleteSessionRequest _self;
  final $Res Function(DeleteSessionRequest) _then;

/// Create a copy of DeleteSessionRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? deleteWorktree = null,Object? deleteBranch = null,Object? force = null,}) {
  return _then(_self.copyWith(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,deleteWorktree: null == deleteWorktree ? _self.deleteWorktree : deleteWorktree // ignore: cast_nullable_to_non_nullable
as bool,deleteBranch: null == deleteBranch ? _self.deleteBranch : deleteBranch // ignore: cast_nullable_to_non_nullable
as bool,force: null == force ? _self.force : force // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _DeleteSessionRequest implements DeleteSessionRequest {
  const _DeleteSessionRequest({required this.sessionId, required this.deleteWorktree, required this.deleteBranch, required this.force});
  factory _DeleteSessionRequest.fromJson(Map<String, dynamic> json) => _$DeleteSessionRequestFromJson(json);

@override final  String sessionId;
@override final  bool deleteWorktree;
@override final  bool deleteBranch;
@override final  bool force;

/// Create a copy of DeleteSessionRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeleteSessionRequestCopyWith<_DeleteSessionRequest> get copyWith => __$DeleteSessionRequestCopyWithImpl<_DeleteSessionRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeleteSessionRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeleteSessionRequest&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.deleteWorktree, deleteWorktree) || other.deleteWorktree == deleteWorktree)&&(identical(other.deleteBranch, deleteBranch) || other.deleteBranch == deleteBranch)&&(identical(other.force, force) || other.force == force));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,deleteWorktree,deleteBranch,force);

@override
String toString() {
  return 'DeleteSessionRequest(sessionId: $sessionId, deleteWorktree: $deleteWorktree, deleteBranch: $deleteBranch, force: $force)';
}


}

/// @nodoc
abstract mixin class _$DeleteSessionRequestCopyWith<$Res> implements $DeleteSessionRequestCopyWith<$Res> {
  factory _$DeleteSessionRequestCopyWith(_DeleteSessionRequest value, $Res Function(_DeleteSessionRequest) _then) = __$DeleteSessionRequestCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, bool deleteWorktree, bool deleteBranch, bool force
});




}
/// @nodoc
class __$DeleteSessionRequestCopyWithImpl<$Res>
    implements _$DeleteSessionRequestCopyWith<$Res> {
  __$DeleteSessionRequestCopyWithImpl(this._self, this._then);

  final _DeleteSessionRequest _self;
  final $Res Function(_DeleteSessionRequest) _then;

/// Create a copy of DeleteSessionRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? deleteWorktree = null,Object? deleteBranch = null,Object? force = null,}) {
  return _then(_DeleteSessionRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,deleteWorktree: null == deleteWorktree ? _self.deleteWorktree : deleteWorktree // ignore: cast_nullable_to_non_nullable
as bool,deleteBranch: null == deleteBranch ? _self.deleteBranch : deleteBranch // ignore: cast_nullable_to_non_nullable
as bool,force: null == force ? _self.force : force // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
