import "package:freezed_annotation/freezed_annotation.dart";

part "acp_permission_details_dto.freezed.dart";
part "acp_permission_details_dto.g.dart";

/// The standardized portion of a request_permission toolCall. Opaque rawInput
/// is deliberately excluded: its schema is owned by each concrete harness.
@Freezed(fromJson: true, toJson: false)
sealed class AcpPermissionDetailsDto with _$AcpPermissionDetailsDto {
  const factory({
    @JsonKey(unknownEnumValue: AcpPermissionToolKind.unknown) required AcpPermissionToolKind? kind,
    @Default([]) List<AcpPermissionLocationDto> locations,
    @Default([]) List<AcpPermissionContentDto> content,
  }) = _AcpPermissionDetailsDto;
  factory fromJson(Map<String, dynamic> json) => _$AcpPermissionDetailsDtoFromJson(json);
}

enum AcpPermissionToolKind() {
  edit,
  delete,
  move,
  fetch,
  unknown,
}

@Freezed(fromJson: true, toJson: false)
sealed class AcpPermissionLocationDto with _$AcpPermissionLocationDto {
  const factory({required String path}) = _AcpPermissionLocationDto;
  factory fromJson(Map<String, dynamic> json) => _$AcpPermissionLocationDtoFromJson(json);
}

@Freezed(unionKey: "type", fallbackUnion: "unknown", fromJson: true, toJson: false)
sealed class AcpPermissionContentDto with _$AcpPermissionContentDto {
  const factory diff({required String path, required String? oldText}) = AcpPermissionDiffDto;
  const factory content({required AcpPermissionResourceDto content}) = AcpPermissionStandardContentDto;
  const factory unknown() = AcpPermissionUnknownContentDto;
  factory fromJson(Map<String, dynamic> json) => _$AcpPermissionContentDtoFromJson(json);
}

@Freezed(unionKey: "type", fallbackUnion: "unknown", fromJson: true, toJson: false)
sealed class AcpPermissionResourceDto with _$AcpPermissionResourceDto {
  @FreezedUnionValue("resource_link")
  const factory link({required String uri}) = AcpPermissionResourceLinkDto;
  const factory unknown() = AcpPermissionUnknownResourceDto;
  factory fromJson(Map<String, dynamic> json) => _$AcpPermissionResourceDtoFromJson(json);
}
