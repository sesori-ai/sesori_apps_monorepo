// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'generate_session_metadata_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GenerateSessionMetadataRequest {

 String get firstMessage;
/// Create a copy of GenerateSessionMetadataRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GenerateSessionMetadataRequestCopyWith<GenerateSessionMetadataRequest> get copyWith => _$GenerateSessionMetadataRequestCopyWithImpl<GenerateSessionMetadataRequest>(this as GenerateSessionMetadataRequest, _$identity);

  /// Serializes this GenerateSessionMetadataRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GenerateSessionMetadataRequest&&(identical(other.firstMessage, firstMessage) || other.firstMessage == firstMessage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,firstMessage);

@override
String toString() {
  return 'GenerateSessionMetadataRequest(firstMessage: $firstMessage)';
}


}

/// @nodoc
abstract mixin class $GenerateSessionMetadataRequestCopyWith<$Res>  {
  factory $GenerateSessionMetadataRequestCopyWith(GenerateSessionMetadataRequest value, $Res Function(GenerateSessionMetadataRequest) _then) = _$GenerateSessionMetadataRequestCopyWithImpl;
@useResult
$Res call({
 String firstMessage
});




}
/// @nodoc
class _$GenerateSessionMetadataRequestCopyWithImpl<$Res>
    implements $GenerateSessionMetadataRequestCopyWith<$Res> {
  _$GenerateSessionMetadataRequestCopyWithImpl(this._self, this._then);

  final GenerateSessionMetadataRequest _self;
  final $Res Function(GenerateSessionMetadataRequest) _then;

/// Create a copy of GenerateSessionMetadataRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? firstMessage = null,}) {
  return _then(GenerateSessionMetadataRequest(
firstMessage: null == firstMessage ? _self.firstMessage : firstMessage // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _GenerateSessionMetadataRequest implements GenerateSessionMetadataRequest {
  const _GenerateSessionMetadataRequest({required this.firstMessage});
  factory _GenerateSessionMetadataRequest.fromJson(Map<String, dynamic> json) => _$GenerateSessionMetadataRequestFromJson(json);

@override final  String firstMessage;

/// Create a copy of GenerateSessionMetadataRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GenerateSessionMetadataRequestCopyWith<_GenerateSessionMetadataRequest> get copyWith => __$GenerateSessionMetadataRequestCopyWithImpl<_GenerateSessionMetadataRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GenerateSessionMetadataRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GenerateSessionMetadataRequest&&(identical(other.firstMessage, firstMessage) || other.firstMessage == firstMessage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,firstMessage);

@override
String toString() {
  return 'GenerateSessionMetadataRequest(firstMessage: $firstMessage)';
}


}

/// @nodoc
abstract mixin class _$GenerateSessionMetadataRequestCopyWith<$Res> implements $GenerateSessionMetadataRequestCopyWith<$Res> {
  factory _$GenerateSessionMetadataRequestCopyWith(_GenerateSessionMetadataRequest value, $Res Function(_GenerateSessionMetadataRequest) _then) = __$GenerateSessionMetadataRequestCopyWithImpl;
@override @useResult
$Res call({
 String firstMessage
});




}
/// @nodoc
class __$GenerateSessionMetadataRequestCopyWithImpl<$Res>
    implements _$GenerateSessionMetadataRequestCopyWith<$Res> {
  __$GenerateSessionMetadataRequestCopyWithImpl(this._self, this._then);

  final _GenerateSessionMetadataRequest _self;
  final $Res Function(_GenerateSessionMetadataRequest) _then;

/// Create a copy of GenerateSessionMetadataRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? firstMessage = null,}) {
  return _then(_GenerateSessionMetadataRequest(
firstMessage: null == firstMessage ? _self.firstMessage : firstMessage // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
