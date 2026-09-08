// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'antigravity_model_config_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AntigravityModelConfigDto {

 String get id;@JsonKey(unknownEnumValue: AntigravityConfigType.unknown) AntigravityConfigType get type; String get currentValue;@JsonKey(fromJson: _modelOptionsFromJson) List<AntigravityModelOptionDto> get options;







}





/// @nodoc
@JsonSerializable(createToJson: false)

class _AntigravityModelConfigDto implements AntigravityModelConfigDto {
  const _AntigravityModelConfigDto({required this.id, @JsonKey(unknownEnumValue: AntigravityConfigType.unknown) required this.type, required this.currentValue, @JsonKey(fromJson: _modelOptionsFromJson) required  List<AntigravityModelOptionDto> options}): _options = options;
  factory _AntigravityModelConfigDto.fromJson(Map<String, dynamic> json) => _$AntigravityModelConfigDtoFromJson(json);

@override final  String id;
@override@JsonKey(unknownEnumValue: AntigravityConfigType.unknown) final  AntigravityConfigType type;
@override final  String currentValue;
 final  List<AntigravityModelOptionDto> _options;
@override@JsonKey(fromJson: _modelOptionsFromJson) List<AntigravityModelOptionDto> get options {
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_options);
}









}





/// @nodoc
mixin _$AntigravityModelOptionDto {

 String get value; String get name;







}





/// @nodoc
@JsonSerializable(createToJson: false)

class _AntigravityModelOptionDto implements AntigravityModelOptionDto {
  const _AntigravityModelOptionDto({required this.value, required this.name});
  factory _AntigravityModelOptionDto.fromJson(Map<String, dynamic> json) => _$AntigravityModelOptionDtoFromJson(json);

@override final  String value;
@override final  String name;








}





/// @nodoc
mixin _$AntigravityModelGroupDto {

 List<AntigravityModelOptionDto> get options;







}





/// @nodoc
@JsonSerializable(createToJson: false)

class _AntigravityModelGroupDto implements AntigravityModelGroupDto {
  const _AntigravityModelGroupDto({required  List<AntigravityModelOptionDto> options}): _options = options;
  factory _AntigravityModelGroupDto.fromJson(Map<String, dynamic> json) => _$AntigravityModelGroupDtoFromJson(json);

 final  List<AntigravityModelOptionDto> _options;
@override List<AntigravityModelOptionDto> get options {
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_options);
}









}




// dart format on
