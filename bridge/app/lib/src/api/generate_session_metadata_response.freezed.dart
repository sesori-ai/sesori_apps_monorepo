// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'generate_session_metadata_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GenerateSessionMetadataResponse {

 String get title;
/// Create a copy of GenerateSessionMetadataResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GenerateSessionMetadataResponseCopyWith<GenerateSessionMetadataResponse> get copyWith => _$GenerateSessionMetadataResponseCopyWithImpl<GenerateSessionMetadataResponse>(this as GenerateSessionMetadataResponse, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GenerateSessionMetadataResponse&&(identical(other.title, title) || other.title == title));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title);

@override
String toString() {
  return 'GenerateSessionMetadataResponse(title: $title)';
}


}

/// @nodoc
abstract mixin class $GenerateSessionMetadataResponseCopyWith<$Res>  {
  factory $GenerateSessionMetadataResponseCopyWith(GenerateSessionMetadataResponse value, $Res Function(GenerateSessionMetadataResponse) _then) = _$GenerateSessionMetadataResponseCopyWithImpl;
@useResult
$Res call({
 String title
});




}
/// @nodoc
class _$GenerateSessionMetadataResponseCopyWithImpl<$Res>
    implements $GenerateSessionMetadataResponseCopyWith<$Res> {
  _$GenerateSessionMetadataResponseCopyWithImpl(this._self, this._then);

  final GenerateSessionMetadataResponse _self;
  final $Res Function(GenerateSessionMetadataResponse) _then;

/// Create a copy of GenerateSessionMetadataResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,}) {
  return _then(GenerateSessionMetadataResponse(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GenerateSessionMetadataResponse implements GenerateSessionMetadataResponse {
  const _GenerateSessionMetadataResponse({required this.title});
  factory _GenerateSessionMetadataResponse.fromJson(Map<String, dynamic> json) => _$GenerateSessionMetadataResponseFromJson(json);

@override final  String title;

/// Create a copy of GenerateSessionMetadataResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GenerateSessionMetadataResponseCopyWith<_GenerateSessionMetadataResponse> get copyWith => __$GenerateSessionMetadataResponseCopyWithImpl<_GenerateSessionMetadataResponse>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GenerateSessionMetadataResponse&&(identical(other.title, title) || other.title == title));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title);

@override
String toString() {
  return 'GenerateSessionMetadataResponse(title: $title)';
}


}

/// @nodoc
abstract mixin class _$GenerateSessionMetadataResponseCopyWith<$Res> implements $GenerateSessionMetadataResponseCopyWith<$Res> {
  factory _$GenerateSessionMetadataResponseCopyWith(_GenerateSessionMetadataResponse value, $Res Function(_GenerateSessionMetadataResponse) _then) = __$GenerateSessionMetadataResponseCopyWithImpl;
@override @useResult
$Res call({
 String title
});




}
/// @nodoc
class __$GenerateSessionMetadataResponseCopyWithImpl<$Res>
    implements _$GenerateSessionMetadataResponseCopyWith<$Res> {
  __$GenerateSessionMetadataResponseCopyWithImpl(this._self, this._then);

  final _GenerateSessionMetadataResponse _self;
  final $Res Function(_GenerateSessionMetadataResponse) _then;

/// Create a copy of GenerateSessionMetadataResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,}) {
  return _then(_GenerateSessionMetadataResponse(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
