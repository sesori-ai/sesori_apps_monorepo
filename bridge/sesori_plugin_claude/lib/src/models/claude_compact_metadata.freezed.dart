// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'claude_compact_metadata.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ClaudeCompactMetadata {

@JsonKey(fromJson: _triggerOrNull) ClaudeCompactTrigger? get trigger;/// The context size before compacting, in tokens.
@JsonKey(readValue: _readPreTokens, fromJson: _intOrNull) int? get preTokens;/// The context size after compacting, in tokens.
@JsonKey(readValue: _readPostTokens, fromJson: _intOrNull) int? get postTokens;
/// Create a copy of ClaudeCompactMetadata
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClaudeCompactMetadataCopyWith<ClaudeCompactMetadata> get copyWith => _$ClaudeCompactMetadataCopyWithImpl<ClaudeCompactMetadata>(this as ClaudeCompactMetadata, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ClaudeCompactMetadata;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaudeCompactMetadata&&(identical(other.trigger, _this.trigger) || other.trigger == _this.trigger)&&(identical(other.preTokens, _this.preTokens) || other.preTokens == _this.preTokens)&&(identical(other.postTokens, _this.postTokens) || other.postTokens == _this.postTokens));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ClaudeCompactMetadata;
  return Object.hash(runtimeType,_this.trigger,_this.preTokens,_this.postTokens);
}



}

/// @nodoc
abstract mixin class $ClaudeCompactMetadataCopyWith<$Res>  {
  factory $ClaudeCompactMetadataCopyWith(ClaudeCompactMetadata value, $Res Function(ClaudeCompactMetadata) _then) = _$ClaudeCompactMetadataCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _triggerOrNull) ClaudeCompactTrigger? trigger,@JsonKey(readValue: _readPreTokens, fromJson: _intOrNull) int? preTokens,@JsonKey(readValue: _readPostTokens, fromJson: _intOrNull) int? postTokens
});




}
/// @nodoc
class _$ClaudeCompactMetadataCopyWithImpl<$Res>
    implements $ClaudeCompactMetadataCopyWith<$Res> {
  _$ClaudeCompactMetadataCopyWithImpl(this._self, this._then);

  final ClaudeCompactMetadata _self;
  final $Res Function(ClaudeCompactMetadata) _then;

/// Create a copy of ClaudeCompactMetadata
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? trigger = freezed,Object? preTokens = freezed,Object? postTokens = freezed,}) {
  return _then(ClaudeCompactMetadata(
trigger: freezed == trigger ? _self.trigger : trigger // ignore: cast_nullable_to_non_nullable
as ClaudeCompactTrigger?,preTokens: freezed == preTokens ? _self.preTokens : preTokens // ignore: cast_nullable_to_non_nullable
as int?,postTokens: freezed == postTokens ? _self.postTokens : postTokens // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _ClaudeCompactMetadata implements ClaudeCompactMetadata {
  const _ClaudeCompactMetadata({@JsonKey(fromJson: _triggerOrNull) required this.trigger, @JsonKey(readValue: _readPreTokens, fromJson: _intOrNull) required this.preTokens, @JsonKey(readValue: _readPostTokens, fromJson: _intOrNull) required this.postTokens});
  factory _ClaudeCompactMetadata.fromJson(Map<String, dynamic> json) => _$ClaudeCompactMetadataFromJson(json);

@override@JsonKey(fromJson: _triggerOrNull) final  ClaudeCompactTrigger? trigger;
/// The context size before compacting, in tokens.
@override@JsonKey(readValue: _readPreTokens, fromJson: _intOrNull) final  int? preTokens;
/// The context size after compacting, in tokens.
@override@JsonKey(readValue: _readPostTokens, fromJson: _intOrNull) final  int? postTokens;

/// Create a copy of ClaudeCompactMetadata
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClaudeCompactMetadataCopyWith<_ClaudeCompactMetadata> get copyWith => __$ClaudeCompactMetadataCopyWithImpl<_ClaudeCompactMetadata>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClaudeCompactMetadata&&(identical(other.trigger, trigger) || other.trigger == trigger)&&(identical(other.preTokens, preTokens) || other.preTokens == preTokens)&&(identical(other.postTokens, postTokens) || other.postTokens == postTokens));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,trigger,preTokens,postTokens);
}



}

/// @nodoc
abstract mixin class _$ClaudeCompactMetadataCopyWith<$Res> implements $ClaudeCompactMetadataCopyWith<$Res> {
  factory _$ClaudeCompactMetadataCopyWith(_ClaudeCompactMetadata value, $Res Function(_ClaudeCompactMetadata) _then) = __$ClaudeCompactMetadataCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _triggerOrNull) ClaudeCompactTrigger? trigger,@JsonKey(readValue: _readPreTokens, fromJson: _intOrNull) int? preTokens,@JsonKey(readValue: _readPostTokens, fromJson: _intOrNull) int? postTokens
});




}
/// @nodoc
class __$ClaudeCompactMetadataCopyWithImpl<$Res>
    implements _$ClaudeCompactMetadataCopyWith<$Res> {
  __$ClaudeCompactMetadataCopyWithImpl(this._self, this._then);

  final _ClaudeCompactMetadata _self;
  final $Res Function(_ClaudeCompactMetadata) _then;

/// Create a copy of ClaudeCompactMetadata
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? trigger = freezed,Object? preTokens = freezed,Object? postTokens = freezed,}) {
  return _then(_ClaudeCompactMetadata(
trigger: freezed == trigger ? _self.trigger : trigger // ignore: cast_nullable_to_non_nullable
as ClaudeCompactTrigger?,preTokens: freezed == preTokens ? _self.preTokens : preTokens // ignore: cast_nullable_to_non_nullable
as int?,postTokens: freezed == postTokens ? _self.postTokens : postTokens // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
