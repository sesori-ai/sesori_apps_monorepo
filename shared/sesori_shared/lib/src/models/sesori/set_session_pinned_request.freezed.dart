// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'set_session_pinned_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SetSessionPinnedRequest {

 String get sessionId; bool get pinned;
/// Create a copy of SetSessionPinnedRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SetSessionPinnedRequestCopyWith<SetSessionPinnedRequest> get copyWith => _$SetSessionPinnedRequestCopyWithImpl<SetSessionPinnedRequest>(this as SetSessionPinnedRequest, _$identity);

  /// Serializes this SetSessionPinnedRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SetSessionPinnedRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SetSessionPinnedRequest&&(identical(other.sessionId, _this.sessionId) || other.sessionId == _this.sessionId)&&(identical(other.pinned, _this.pinned) || other.pinned == _this.pinned));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SetSessionPinnedRequest;
  return Object.hash(runtimeType,_this.sessionId,_this.pinned);
}

@override
String toString() {
  final _this = this as SetSessionPinnedRequest;
  return 'SetSessionPinnedRequest(sessionId: ${_this.sessionId}, pinned: ${_this.pinned})';
}


}

/// @nodoc
abstract mixin class $SetSessionPinnedRequestCopyWith<$Res>  {
  factory $SetSessionPinnedRequestCopyWith(SetSessionPinnedRequest value, $Res Function(SetSessionPinnedRequest) _then) = _$SetSessionPinnedRequestCopyWithImpl;
@useResult
$Res call({
 String sessionId, bool pinned
});




}
/// @nodoc
class _$SetSessionPinnedRequestCopyWithImpl<$Res>
    implements $SetSessionPinnedRequestCopyWith<$Res> {
  _$SetSessionPinnedRequestCopyWithImpl(this._self, this._then);

  final SetSessionPinnedRequest _self;
  final $Res Function(SetSessionPinnedRequest) _then;

/// Create a copy of SetSessionPinnedRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? pinned = null,}) {
  return _then(SetSessionPinnedRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,pinned: null == pinned ? _self.pinned : pinned // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SetSessionPinnedRequest implements SetSessionPinnedRequest {
  const _SetSessionPinnedRequest({required this.sessionId, required this.pinned});
  factory _SetSessionPinnedRequest.fromJson(Map<String, dynamic> json) => _$SetSessionPinnedRequestFromJson(json);

@override final  String sessionId;
@override final  bool pinned;

/// Create a copy of SetSessionPinnedRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SetSessionPinnedRequestCopyWith<_SetSessionPinnedRequest> get copyWith => __$SetSessionPinnedRequestCopyWithImpl<_SetSessionPinnedRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SetSessionPinnedRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SetSessionPinnedRequest&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.pinned, pinned) || other.pinned == pinned));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sessionId,pinned);
}

@override
String toString() {
    return 'SetSessionPinnedRequest(sessionId: $sessionId, pinned: $pinned)';
}


}

/// @nodoc
abstract mixin class _$SetSessionPinnedRequestCopyWith<$Res> implements $SetSessionPinnedRequestCopyWith<$Res> {
  factory _$SetSessionPinnedRequestCopyWith(_SetSessionPinnedRequest value, $Res Function(_SetSessionPinnedRequest) _then) = __$SetSessionPinnedRequestCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, bool pinned
});




}
/// @nodoc
class __$SetSessionPinnedRequestCopyWithImpl<$Res>
    implements _$SetSessionPinnedRequestCopyWith<$Res> {
  __$SetSessionPinnedRequestCopyWithImpl(this._self, this._then);

  final _SetSessionPinnedRequest _self;
  final $Res Function(_SetSessionPinnedRequest) _then;

/// Create a copy of SetSessionPinnedRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? pinned = null,}) {
  return _then(_SetSessionPinnedRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,pinned: null == pinned ? _self.pinned : pinned // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
