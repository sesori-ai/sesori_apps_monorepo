// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'voice_transcription_failure_metadata.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VoiceTranscriptionFailureMetadata {

 bool? get retryable;
/// Create a copy of VoiceTranscriptionFailureMetadata
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VoiceTranscriptionFailureMetadataCopyWith<VoiceTranscriptionFailureMetadata> get copyWith => _$VoiceTranscriptionFailureMetadataCopyWithImpl<VoiceTranscriptionFailureMetadata>(this as VoiceTranscriptionFailureMetadata, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VoiceTranscriptionFailureMetadata&&(identical(other.retryable, retryable) || other.retryable == retryable));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,retryable);

@override
String toString() {
  return 'VoiceTranscriptionFailureMetadata(retryable: $retryable)';
}


}

/// @nodoc
abstract mixin class $VoiceTranscriptionFailureMetadataCopyWith<$Res>  {
  factory $VoiceTranscriptionFailureMetadataCopyWith(VoiceTranscriptionFailureMetadata value, $Res Function(VoiceTranscriptionFailureMetadata) _then) = _$VoiceTranscriptionFailureMetadataCopyWithImpl;
@useResult
$Res call({
 bool? retryable
});




}
/// @nodoc
class _$VoiceTranscriptionFailureMetadataCopyWithImpl<$Res>
    implements $VoiceTranscriptionFailureMetadataCopyWith<$Res> {
  _$VoiceTranscriptionFailureMetadataCopyWithImpl(this._self, this._then);

  final VoiceTranscriptionFailureMetadata _self;
  final $Res Function(VoiceTranscriptionFailureMetadata) _then;

/// Create a copy of VoiceTranscriptionFailureMetadata
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? retryable = freezed,}) {
  return _then(VoiceTranscriptionFailureMetadata(
retryable: freezed == retryable ? _self.retryable : retryable // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _VoiceTranscriptionFailureMetadata implements VoiceTranscriptionFailureMetadata {
  const _VoiceTranscriptionFailureMetadata({required this.retryable});
  factory _VoiceTranscriptionFailureMetadata.fromJson(Map<String, dynamic> json) => _$VoiceTranscriptionFailureMetadataFromJson(json);

@override final  bool? retryable;

/// Create a copy of VoiceTranscriptionFailureMetadata
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VoiceTranscriptionFailureMetadataCopyWith<_VoiceTranscriptionFailureMetadata> get copyWith => __$VoiceTranscriptionFailureMetadataCopyWithImpl<_VoiceTranscriptionFailureMetadata>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VoiceTranscriptionFailureMetadata&&(identical(other.retryable, retryable) || other.retryable == retryable));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,retryable);

@override
String toString() {
  return 'VoiceTranscriptionFailureMetadata(retryable: $retryable)';
}


}

/// @nodoc
abstract mixin class _$VoiceTranscriptionFailureMetadataCopyWith<$Res> implements $VoiceTranscriptionFailureMetadataCopyWith<$Res> {
  factory _$VoiceTranscriptionFailureMetadataCopyWith(_VoiceTranscriptionFailureMetadata value, $Res Function(_VoiceTranscriptionFailureMetadata) _then) = __$VoiceTranscriptionFailureMetadataCopyWithImpl;
@override @useResult
$Res call({
 bool? retryable
});




}
/// @nodoc
class __$VoiceTranscriptionFailureMetadataCopyWithImpl<$Res>
    implements _$VoiceTranscriptionFailureMetadataCopyWith<$Res> {
  __$VoiceTranscriptionFailureMetadataCopyWithImpl(this._self, this._then);

  final _VoiceTranscriptionFailureMetadata _self;
  final $Res Function(_VoiceTranscriptionFailureMetadata) _then;

/// Create a copy of VoiceTranscriptionFailureMetadata
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? retryable = freezed,}) {
  return _then(_VoiceTranscriptionFailureMetadata(
retryable: freezed == retryable ? _self.retryable : retryable // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}

// dart format on
