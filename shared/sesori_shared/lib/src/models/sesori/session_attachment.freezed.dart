// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_attachment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SessionAttachmentRequest {

 String get sessionId; String get attachmentId; SessionAttachmentRendition get rendition;
/// Create a copy of SessionAttachmentRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionAttachmentRequestCopyWith<SessionAttachmentRequest> get copyWith => _$SessionAttachmentRequestCopyWithImpl<SessionAttachmentRequest>(this as SessionAttachmentRequest, _$identity);

  /// Serializes this SessionAttachmentRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionAttachmentRequest&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.attachmentId, attachmentId) || other.attachmentId == attachmentId)&&(identical(other.rendition, rendition) || other.rendition == rendition));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,attachmentId,rendition);

@override
String toString() {
  return 'SessionAttachmentRequest(sessionId: $sessionId, attachmentId: $attachmentId, rendition: $rendition)';
}


}

/// @nodoc
abstract mixin class $SessionAttachmentRequestCopyWith<$Res>  {
  factory $SessionAttachmentRequestCopyWith(SessionAttachmentRequest value, $Res Function(SessionAttachmentRequest) _then) = _$SessionAttachmentRequestCopyWithImpl;
@useResult
$Res call({
 String sessionId, String attachmentId, SessionAttachmentRendition rendition
});




}
/// @nodoc
class _$SessionAttachmentRequestCopyWithImpl<$Res>
    implements $SessionAttachmentRequestCopyWith<$Res> {
  _$SessionAttachmentRequestCopyWithImpl(this._self, this._then);

  final SessionAttachmentRequest _self;
  final $Res Function(SessionAttachmentRequest) _then;

/// Create a copy of SessionAttachmentRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? attachmentId = null,Object? rendition = null,}) {
  return _then(SessionAttachmentRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,attachmentId: null == attachmentId ? _self.attachmentId : attachmentId // ignore: cast_nullable_to_non_nullable
as String,rendition: null == rendition ? _self.rendition : rendition // ignore: cast_nullable_to_non_nullable
as SessionAttachmentRendition,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SessionAttachmentRequest implements SessionAttachmentRequest {
  const _SessionAttachmentRequest({required this.sessionId, required this.attachmentId, required this.rendition});
  factory _SessionAttachmentRequest.fromJson(Map<String, dynamic> json) => _$SessionAttachmentRequestFromJson(json);

@override final  String sessionId;
@override final  String attachmentId;
@override final  SessionAttachmentRendition rendition;

/// Create a copy of SessionAttachmentRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionAttachmentRequestCopyWith<_SessionAttachmentRequest> get copyWith => __$SessionAttachmentRequestCopyWithImpl<_SessionAttachmentRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionAttachmentRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionAttachmentRequest&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.attachmentId, attachmentId) || other.attachmentId == attachmentId)&&(identical(other.rendition, rendition) || other.rendition == rendition));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,attachmentId,rendition);

@override
String toString() {
  return 'SessionAttachmentRequest(sessionId: $sessionId, attachmentId: $attachmentId, rendition: $rendition)';
}


}

/// @nodoc
abstract mixin class _$SessionAttachmentRequestCopyWith<$Res> implements $SessionAttachmentRequestCopyWith<$Res> {
  factory _$SessionAttachmentRequestCopyWith(_SessionAttachmentRequest value, $Res Function(_SessionAttachmentRequest) _then) = __$SessionAttachmentRequestCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, String attachmentId, SessionAttachmentRendition rendition
});




}
/// @nodoc
class __$SessionAttachmentRequestCopyWithImpl<$Res>
    implements _$SessionAttachmentRequestCopyWith<$Res> {
  __$SessionAttachmentRequestCopyWithImpl(this._self, this._then);

  final _SessionAttachmentRequest _self;
  final $Res Function(_SessionAttachmentRequest) _then;

/// Create a copy of SessionAttachmentRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? attachmentId = null,Object? rendition = null,}) {
  return _then(_SessionAttachmentRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,attachmentId: null == attachmentId ? _self.attachmentId : attachmentId // ignore: cast_nullable_to_non_nullable
as String,rendition: null == rendition ? _self.rendition : rendition // ignore: cast_nullable_to_non_nullable
as SessionAttachmentRendition,
  ));
}


}


/// @nodoc
mixin _$SessionAttachmentResponse {

 String get mime; String get base64; int get byteLength;
/// Create a copy of SessionAttachmentResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionAttachmentResponseCopyWith<SessionAttachmentResponse> get copyWith => _$SessionAttachmentResponseCopyWithImpl<SessionAttachmentResponse>(this as SessionAttachmentResponse, _$identity);

  /// Serializes this SessionAttachmentResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionAttachmentResponse&&(identical(other.mime, mime) || other.mime == mime)&&(identical(other.base64, base64) || other.base64 == base64)&&(identical(other.byteLength, byteLength) || other.byteLength == byteLength));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,mime,base64,byteLength);



}

/// @nodoc
abstract mixin class $SessionAttachmentResponseCopyWith<$Res>  {
  factory $SessionAttachmentResponseCopyWith(SessionAttachmentResponse value, $Res Function(SessionAttachmentResponse) _then) = _$SessionAttachmentResponseCopyWithImpl;
@useResult
$Res call({
 String mime, String base64, int byteLength
});




}
/// @nodoc
class _$SessionAttachmentResponseCopyWithImpl<$Res>
    implements $SessionAttachmentResponseCopyWith<$Res> {
  _$SessionAttachmentResponseCopyWithImpl(this._self, this._then);

  final SessionAttachmentResponse _self;
  final $Res Function(SessionAttachmentResponse) _then;

/// Create a copy of SessionAttachmentResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? mime = null,Object? base64 = null,Object? byteLength = null,}) {
  return _then(SessionAttachmentResponse(
mime: null == mime ? _self.mime : mime // ignore: cast_nullable_to_non_nullable
as String,base64: null == base64 ? _self.base64 : base64 // ignore: cast_nullable_to_non_nullable
as String,byteLength: null == byteLength ? _self.byteLength : byteLength // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SessionAttachmentResponse implements SessionAttachmentResponse {
  const _SessionAttachmentResponse({required this.mime, required this.base64, required this.byteLength});
  factory _SessionAttachmentResponse.fromJson(Map<String, dynamic> json) => _$SessionAttachmentResponseFromJson(json);

@override final  String mime;
@override final  String base64;
@override final  int byteLength;

/// Create a copy of SessionAttachmentResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionAttachmentResponseCopyWith<_SessionAttachmentResponse> get copyWith => __$SessionAttachmentResponseCopyWithImpl<_SessionAttachmentResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionAttachmentResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionAttachmentResponse&&(identical(other.mime, mime) || other.mime == mime)&&(identical(other.base64, base64) || other.base64 == base64)&&(identical(other.byteLength, byteLength) || other.byteLength == byteLength));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,mime,base64,byteLength);



}

/// @nodoc
abstract mixin class _$SessionAttachmentResponseCopyWith<$Res> implements $SessionAttachmentResponseCopyWith<$Res> {
  factory _$SessionAttachmentResponseCopyWith(_SessionAttachmentResponse value, $Res Function(_SessionAttachmentResponse) _then) = __$SessionAttachmentResponseCopyWithImpl;
@override @useResult
$Res call({
 String mime, String base64, int byteLength
});




}
/// @nodoc
class __$SessionAttachmentResponseCopyWithImpl<$Res>
    implements _$SessionAttachmentResponseCopyWith<$Res> {
  __$SessionAttachmentResponseCopyWithImpl(this._self, this._then);

  final _SessionAttachmentResponse _self;
  final $Res Function(_SessionAttachmentResponse) _then;

/// Create a copy of SessionAttachmentResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mime = null,Object? base64 = null,Object? byteLength = null,}) {
  return _then(_SessionAttachmentResponse(
mime: null == mime ? _self.mime : mime // ignore: cast_nullable_to_non_nullable
as String,base64: null == base64 ? _self.base64 : base64 // ignore: cast_nullable_to_non_nullable
as String,byteLength: null == byteLength ? _self.byteLength : byteLength // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
