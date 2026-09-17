import "package:freezed_annotation/freezed_annotation.dart";

part "permission_details.freezed.dart";
part "permission_details.g.dart";

/// Backend-neutral request details. Unknown future kinds retain the generic
/// tool/description presentation without preventing a permission decision.
@Freezed(unionKey: "kind", fallbackUnion: "generic", fromJson: true, toJson: true)
sealed class PermissionDetails with _$PermissionDetails {
  const factory generic() = GenericPermissionDetails;
  const factory command({required String command}) = CommandPermissionDetails;
  const factory fileChanges({required List<PermissionFile> files}) = FileChangesPermissionDetails;
  const factory network({required List<String> targets, required String? command}) = NetworkPermissionDetails;

  factory fromJson(Map<String, dynamic> json) => _$PermissionDetailsFromJson(json);
}

enum PermissionFileOperation() {
  create,
  write,
  delete,
}

@Freezed(fromJson: true, toJson: true)
sealed class PermissionFile with _$PermissionFile {
  const factory({
    required String path,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) required PermissionFileOperation? operation,
  }) = _PermissionFile;

  factory fromJson(Map<String, dynamic> json) => _$PermissionFileFromJson(json);
}
