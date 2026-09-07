// ignore_for_file: invalid_annotation_target, Freezed forwards factory JSON configuration to generated classes

import "package:freezed_annotation/freezed_annotation.dart";

part "antigravity_permission_dto.freezed.dart";
part "antigravity_permission_dto.g.dart";

const _input = Freezed(copyWith: false, equal: false, toStringOverride: false, toJson: false);

@JsonEnum(fieldRename: FieldRename.snake)
enum AntigravityPermissionKind() {
  allowOnce,
  allowAlways,
  rejectOnce,
  rejectAlways,
  unknown,
}

/// Standard ACP tool categories; absent or future values retain an honest display fallback.
enum AntigravityPermissionToolKind() {
  read,
  edit,
  delete,
  move,
  search,
  execute,
  think,
  fetch,
  other,
  unknown,
}

@_input
sealed class AntigravityPermissionRequestDto with _$AntigravityPermissionRequestDto {
  @JsonSerializable(checked: true, createToJson: false)
  const factory({
    required String sessionId,
    required AntigravityPermissionToolDto toolCall,
    @JsonKey(fromJson: _optionsFromJson) required List<AntigravityPermissionOptionDto> options,
  }) = _AntigravityPermissionRequestDto;
  factory fromJson(Map<String, dynamic> json) => _$AntigravityPermissionRequestDtoFromJson(json);
}

@_input
sealed class AntigravityPermissionToolDto with _$AntigravityPermissionToolDto {
  @JsonSerializable(checked: true, createToJson: false)
  const factory({
    required String toolCallId,
    required String title,
    @JsonKey(unknownEnumValue: AntigravityPermissionToolKind.unknown) required AntigravityPermissionToolKind? kind,
  }) = _AntigravityPermissionToolDto;
  factory fromJson(Map<String, dynamic> json) => _$AntigravityPermissionToolDtoFromJson(json);
}

@_input
sealed class AntigravityPermissionOptionDto with _$AntigravityPermissionOptionDto {
  @JsonSerializable(checked: true, createToJson: false)
  const factory({
    required String optionId,
    required String name,
    @JsonKey(unknownEnumValue: AntigravityPermissionKind.unknown) required AntigravityPermissionKind kind,
    @JsonKey(name: "_meta") required AntigravityPermissionMetadataDto? metadata,
  }) = _AntigravityPermissionOptionDto;
  factory fromJson(Map<String, dynamic> json) => _$AntigravityPermissionOptionDtoFromJson(json);
}

@_input
sealed class AntigravityPermissionMetadataDto with _$AntigravityPermissionMetadataDto {
  @JsonSerializable(checked: true, createToJson: false)
  const factory({
    @JsonKey(name: "agy.security.warning", fromJson: _warningPresent) @Default(false) bool hasWarning,
  }) = _AntigravityPermissionMetadataDto;
  factory fromJson(Map<String, dynamic> json) => _$AntigravityPermissionMetadataDtoFromJson(json);
}

// Warning contents are opaque and never rendered; only their presence matters.
// ignore: no_slop_linter/prefer_specific_type, external warning payload has no fixed value shape
bool _warningPresent(Object? value) => value != null;

// Bound the external list before generated parsing allocates all option DTOs.
// ignore: no_slop_linter/prefer_specific_type, JSON array boundary passed to generated decoders
List<AntigravityPermissionOptionDto> _optionsFromJson(List<dynamic> entries) {
  if (entries.length > 32) throw const FormatException("Too many Antigravity permission options");
  // ignore: no_slop_linter/prefer_specific_type, each JSON object is immediately decoded by the generated factory
  return entries.cast<Map<String, dynamic>>().map(AntigravityPermissionOptionDto.fromJson).toList(growable: false);
}
