// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'feedback_submit_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FeedbackSubmitRequest {

 List<FeedbackIssue> get issues; String? get message; FeedbackSource get source; DevicePlatform get platform; String get appVersion;
/// Create a copy of FeedbackSubmitRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FeedbackSubmitRequestCopyWith<FeedbackSubmitRequest> get copyWith => _$FeedbackSubmitRequestCopyWithImpl<FeedbackSubmitRequest>(this as FeedbackSubmitRequest, _$identity);

  /// Serializes this FeedbackSubmitRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as FeedbackSubmitRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FeedbackSubmitRequest&&const DeepCollectionEquality().equals(other.issues, _this.issues)&&(identical(other.message, _this.message) || other.message == _this.message)&&(identical(other.source, _this.source) || other.source == _this.source)&&(identical(other.platform, _this.platform) || other.platform == _this.platform)&&(identical(other.appVersion, _this.appVersion) || other.appVersion == _this.appVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as FeedbackSubmitRequest;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.issues),_this.message,_this.source,_this.platform,_this.appVersion);
}

@override
String toString() {
  final _this = this as FeedbackSubmitRequest;
  return 'FeedbackSubmitRequest(issues: ${_this.issues}, message: ${_this.message}, source: ${_this.source}, platform: ${_this.platform}, appVersion: ${_this.appVersion})';
}


}

/// @nodoc
abstract mixin class $FeedbackSubmitRequestCopyWith<$Res>  {
  factory $FeedbackSubmitRequestCopyWith(FeedbackSubmitRequest value, $Res Function(FeedbackSubmitRequest) _then) = _$FeedbackSubmitRequestCopyWithImpl;
@useResult
$Res call({
 List<FeedbackIssue> issues, String? message, FeedbackSource source, DevicePlatform platform, String appVersion
});




}
/// @nodoc
class _$FeedbackSubmitRequestCopyWithImpl<$Res>
    implements $FeedbackSubmitRequestCopyWith<$Res> {
  _$FeedbackSubmitRequestCopyWithImpl(this._self, this._then);

  final FeedbackSubmitRequest _self;
  final $Res Function(FeedbackSubmitRequest) _then;

/// Create a copy of FeedbackSubmitRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? issues = null,Object? message = freezed,Object? source = null,Object? platform = null,Object? appVersion = null,}) {
  return _then(FeedbackSubmitRequest(
issues: null == issues ? _self.issues : issues // ignore: cast_nullable_to_non_nullable
as List<FeedbackIssue>,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as FeedbackSource,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as DevicePlatform,appVersion: null == appVersion ? _self.appVersion : appVersion // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _FeedbackSubmitRequest implements FeedbackSubmitRequest {
  const _FeedbackSubmitRequest({required  List<FeedbackIssue> issues, required this.message, required this.source, required this.platform, required this.appVersion}): _issues = issues;
  factory _FeedbackSubmitRequest.fromJson(Map<String, dynamic> json) => _$FeedbackSubmitRequestFromJson(json);

 final  List<FeedbackIssue> _issues;
@override List<FeedbackIssue> get issues {
  if (_issues is EqualUnmodifiableListView) return _issues;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_issues);
}

@override final  String? message;
@override final  FeedbackSource source;
@override final  DevicePlatform platform;
@override final  String appVersion;

/// Create a copy of FeedbackSubmitRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FeedbackSubmitRequestCopyWith<_FeedbackSubmitRequest> get copyWith => __$FeedbackSubmitRequestCopyWithImpl<_FeedbackSubmitRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FeedbackSubmitRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FeedbackSubmitRequest&&const DeepCollectionEquality().equals(other.issues, _issues)&&(identical(other.message, message) || other.message == message)&&(identical(other.source, source) || other.source == source)&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.appVersion, appVersion) || other.appVersion == appVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_issues),message,source,platform,appVersion);
}

@override
String toString() {
    return 'FeedbackSubmitRequest(issues: $issues, message: $message, source: $source, platform: $platform, appVersion: $appVersion)';
}


}

/// @nodoc
abstract mixin class _$FeedbackSubmitRequestCopyWith<$Res> implements $FeedbackSubmitRequestCopyWith<$Res> {
  factory _$FeedbackSubmitRequestCopyWith(_FeedbackSubmitRequest value, $Res Function(_FeedbackSubmitRequest) _then) = __$FeedbackSubmitRequestCopyWithImpl;
@override @useResult
$Res call({
 List<FeedbackIssue> issues, String? message, FeedbackSource source, DevicePlatform platform, String appVersion
});




}
/// @nodoc
class __$FeedbackSubmitRequestCopyWithImpl<$Res>
    implements _$FeedbackSubmitRequestCopyWith<$Res> {
  __$FeedbackSubmitRequestCopyWithImpl(this._self, this._then);

  final _FeedbackSubmitRequest _self;
  final $Res Function(_FeedbackSubmitRequest) _then;

/// Create a copy of FeedbackSubmitRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? issues = null,Object? message = freezed,Object? source = null,Object? platform = null,Object? appVersion = null,}) {
  return _then(_FeedbackSubmitRequest(
issues: null == issues ? _self._issues : issues // ignore: cast_nullable_to_non_nullable
as List<FeedbackIssue>,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as FeedbackSource,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as DevicePlatform,appVersion: null == appVersion ? _self.appVersion : appVersion // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
