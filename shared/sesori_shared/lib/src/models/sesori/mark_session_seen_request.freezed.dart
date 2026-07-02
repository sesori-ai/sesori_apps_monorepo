// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mark_session_seen_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MarkSessionSeenRequest {

 String get sessionId; bool get read; String? get projectId;
/// Create a copy of MarkSessionSeenRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MarkSessionSeenRequestCopyWith<MarkSessionSeenRequest> get copyWith => _$MarkSessionSeenRequestCopyWithImpl<MarkSessionSeenRequest>(this as MarkSessionSeenRequest, _$identity);

  /// Serializes this MarkSessionSeenRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MarkSessionSeenRequest&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.read, read) || other.read == read)&&(identical(other.projectId, projectId) || other.projectId == projectId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,read,projectId);

@override
String toString() {
  return 'MarkSessionSeenRequest(sessionId: $sessionId, read: $read, projectId: $projectId)';
}


}

/// @nodoc
abstract mixin class $MarkSessionSeenRequestCopyWith<$Res>  {
  factory $MarkSessionSeenRequestCopyWith(MarkSessionSeenRequest value, $Res Function(MarkSessionSeenRequest) _then) = _$MarkSessionSeenRequestCopyWithImpl;
@useResult
$Res call({
 String sessionId, bool read, String? projectId
});




}
/// @nodoc
class _$MarkSessionSeenRequestCopyWithImpl<$Res>
    implements $MarkSessionSeenRequestCopyWith<$Res> {
  _$MarkSessionSeenRequestCopyWithImpl(this._self, this._then);

  final MarkSessionSeenRequest _self;
  final $Res Function(MarkSessionSeenRequest) _then;

/// Create a copy of MarkSessionSeenRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? read = null,Object? projectId = freezed,}) {
  return _then(_self.copyWith(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,read: null == read ? _self.read : read // ignore: cast_nullable_to_non_nullable
as bool,projectId: freezed == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _MarkSessionSeenRequest implements MarkSessionSeenRequest {
  const _MarkSessionSeenRequest({required this.sessionId, required this.read, required this.projectId});
  factory _MarkSessionSeenRequest.fromJson(Map<String, dynamic> json) => _$MarkSessionSeenRequestFromJson(json);

@override final  String sessionId;
@override final  bool read;
@override final  String? projectId;

/// Create a copy of MarkSessionSeenRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MarkSessionSeenRequestCopyWith<_MarkSessionSeenRequest> get copyWith => __$MarkSessionSeenRequestCopyWithImpl<_MarkSessionSeenRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MarkSessionSeenRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MarkSessionSeenRequest&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.read, read) || other.read == read)&&(identical(other.projectId, projectId) || other.projectId == projectId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,read,projectId);

@override
String toString() {
  return 'MarkSessionSeenRequest(sessionId: $sessionId, read: $read, projectId: $projectId)';
}


}

/// @nodoc
abstract mixin class _$MarkSessionSeenRequestCopyWith<$Res> implements $MarkSessionSeenRequestCopyWith<$Res> {
  factory _$MarkSessionSeenRequestCopyWith(_MarkSessionSeenRequest value, $Res Function(_MarkSessionSeenRequest) _then) = __$MarkSessionSeenRequestCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, bool read, String? projectId
});




}
/// @nodoc
class __$MarkSessionSeenRequestCopyWithImpl<$Res>
    implements _$MarkSessionSeenRequestCopyWith<$Res> {
  __$MarkSessionSeenRequestCopyWithImpl(this._self, this._then);

  final _MarkSessionSeenRequest _self;
  final $Res Function(_MarkSessionSeenRequest) _then;

/// Create a copy of MarkSessionSeenRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? read = null,Object? projectId = freezed,}) {
  return _then(_MarkSessionSeenRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,read: null == read ? _self.read : read // ignore: cast_nullable_to_non_nullable
as bool,projectId: freezed == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
