import "package:freezed_annotation/freezed_annotation.dart";

part "catalog_import_progress.freezed.dart";
part "catalog_import_progress.g.dart";

@Freezed(unionKey: "type", fromJson: true, toJson: true, copyWith: false)
sealed class CatalogImportProgress with _$CatalogImportProgress {
  @FreezedUnionValue("enumerating")
  const factory enumerating({
    required String pluginId,
    required int projectsSeen,
    required int sessionsSeen,
  }) = CatalogImportEnumerating;

  @FreezedUnionValue("committing")
  const factory committing({
    required String pluginId,
    required int projectsSeen,
    required int sessionsSeen,
  }) = CatalogImportCommitting;

  @FreezedUnionValue("completed")
  const factory completed({
    required String pluginId,
    required int projectsImported,
    required int sessionsImported,
    required int completedAt,
  }) = CatalogImportCompleted;

  @FreezedUnionValue("cancelled")
  const factory cancelled({
    required String pluginId,
  }) = CatalogImportCancelled;

  @FreezedUnionValue("failed")
  const factory failed({
    required String pluginId,
    required String message,
  }) = CatalogImportFailed;

  factory fromJson(Map<String, dynamic> json) => _$CatalogImportProgressFromJson(json);
}
