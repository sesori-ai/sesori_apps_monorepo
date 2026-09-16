import "package:freezed_annotation/freezed_annotation.dart";

part "open_code_permission_metadata_dto.freezed.dart";
part "open_code_permission_metadata_dto.g.dart";

/// Known metadata emitted by OpenCode's bash, edit/apply_patch and webfetch
/// tools. Permission patterns are intentionally not used as request contents.
@Freezed(fromJson: true, toJson: false)
sealed class OpenCodePermissionMetadataDto with _$OpenCodePermissionMetadataDto {
  const factory({
    required String? command,
    required String? filepath,
    required String? url,
    @Default([]) List<OpenCodePermissionFileDto> files,
  }) = _OpenCodePermissionMetadataDto;

  factory fromJson(Map<String, dynamic> json) => _$OpenCodePermissionMetadataDtoFromJson(json);
}

enum OpenCodePermissionFileType() {
  add,
  update,
  delete,
  move,
  unknown,
}

@Freezed(fromJson: true, toJson: false)
sealed class OpenCodePermissionFileDto with _$OpenCodePermissionFileDto {
  const factory({
    required String filePath,
    @JsonKey(unknownEnumValue: OpenCodePermissionFileType.unknown) required OpenCodePermissionFileType type,
    required String? movePath,
  }) = _OpenCodePermissionFileDto;

  factory fromJson(Map<String, dynamic> json) => _$OpenCodePermissionFileDtoFromJson(json);
}
