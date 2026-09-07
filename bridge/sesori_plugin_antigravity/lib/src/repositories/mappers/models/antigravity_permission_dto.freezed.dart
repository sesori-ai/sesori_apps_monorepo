// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'antigravity_permission_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AntigravityPermissionRequestDto {

 String get sessionId; AntigravityPermissionToolDto get toolCall;@JsonKey(fromJson: _optionsFromJson) List<AntigravityPermissionOptionDto> get options;







}





/// @nodoc

@JsonSerializable(checked: true, createToJson: false)
class _AntigravityPermissionRequestDto implements AntigravityPermissionRequestDto {
  const _AntigravityPermissionRequestDto({required this.sessionId, required this.toolCall, @JsonKey(fromJson: _optionsFromJson) required  List<AntigravityPermissionOptionDto> options}): _options = options;
  factory _AntigravityPermissionRequestDto.fromJson(Map<String, dynamic> json) => _$AntigravityPermissionRequestDtoFromJson(json);

@override final  String sessionId;
@override final  AntigravityPermissionToolDto toolCall;
 final  List<AntigravityPermissionOptionDto> _options;
@override@JsonKey(fromJson: _optionsFromJson) List<AntigravityPermissionOptionDto> get options {
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_options);
}









}





/// @nodoc
mixin _$AntigravityPermissionToolDto {

 String get toolCallId; String get title;@JsonKey(unknownEnumValue: AntigravityPermissionToolKind.unknown) AntigravityPermissionToolKind? get kind;







}





/// @nodoc

@JsonSerializable(checked: true, createToJson: false)
class _AntigravityPermissionToolDto implements AntigravityPermissionToolDto {
  const _AntigravityPermissionToolDto({required this.toolCallId, required this.title, @JsonKey(unknownEnumValue: AntigravityPermissionToolKind.unknown) required this.kind});
  factory _AntigravityPermissionToolDto.fromJson(Map<String, dynamic> json) => _$AntigravityPermissionToolDtoFromJson(json);

@override final  String toolCallId;
@override final  String title;
@override@JsonKey(unknownEnumValue: AntigravityPermissionToolKind.unknown) final  AntigravityPermissionToolKind? kind;








}





/// @nodoc
mixin _$AntigravityPermissionOptionDto {

 String get optionId; String get name;@JsonKey(unknownEnumValue: AntigravityPermissionKind.unknown) AntigravityPermissionKind get kind;@JsonKey(name: "_meta") AntigravityPermissionMetadataDto? get metadata;







}





/// @nodoc

@JsonSerializable(checked: true, createToJson: false)
class _AntigravityPermissionOptionDto implements AntigravityPermissionOptionDto {
  const _AntigravityPermissionOptionDto({required this.optionId, required this.name, @JsonKey(unknownEnumValue: AntigravityPermissionKind.unknown) required this.kind, @JsonKey(name: "_meta") required this.metadata});
  factory _AntigravityPermissionOptionDto.fromJson(Map<String, dynamic> json) => _$AntigravityPermissionOptionDtoFromJson(json);

@override final  String optionId;
@override final  String name;
@override@JsonKey(unknownEnumValue: AntigravityPermissionKind.unknown) final  AntigravityPermissionKind kind;
@override@JsonKey(name: "_meta") final  AntigravityPermissionMetadataDto? metadata;








}





/// @nodoc
mixin _$AntigravityPermissionMetadataDto {

@JsonKey(name: "agy.security.warning", fromJson: _warningPresent) bool get hasWarning;







}





/// @nodoc

@JsonSerializable(checked: true, createToJson: false)
class _AntigravityPermissionMetadataDto implements AntigravityPermissionMetadataDto {
  const _AntigravityPermissionMetadataDto({@JsonKey(name: "agy.security.warning", fromJson: _warningPresent) this.hasWarning = false});
  factory _AntigravityPermissionMetadataDto.fromJson(Map<String, dynamic> json) => _$AntigravityPermissionMetadataDtoFromJson(json);

@override@JsonKey(name: "agy.security.warning", fromJson: _warningPresent) final  bool hasWarning;








}




// dart format on
