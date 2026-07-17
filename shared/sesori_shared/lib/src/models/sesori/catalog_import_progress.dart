import "package:freezed_annotation/freezed_annotation.dart";

part "catalog_import_progress.freezed.dart";
part "catalog_import_progress.g.dart";

@Freezed(unionKey: "type", fromJson: true, toJson: true, copyWith: false)
sealed class CatalogImportProgress with _$CatalogImportProgress {
  @FreezedUnionValue("enumerating")
  const factory CatalogImportProgress.enumerating({
    required String pluginId,
    required int projectsSeen,
    required int sessionsSeen,
  }) = CatalogImportEnumerating;

  @FreezedUnionValue("committing")
  const factory CatalogImportProgress.committing({
    required String pluginId,
    required int projectsSeen,
    required int sessionsSeen,
  }) = CatalogImportCommitting;

  @FreezedUnionValue("completed")
  const factory CatalogImportProgress.completed({
    required String pluginId,
    required int projectsImported,
    required int sessionsImported,
    required int completedAt,
  }) = CatalogImportCompleted;

  @FreezedUnionValue("cancelled")
  const factory CatalogImportProgress.cancelled({
    required String pluginId,
  }) = CatalogImportCancelled;

  @FreezedUnionValue("failed")
  const factory CatalogImportProgress.failed({
    required String pluginId,
    required String message,
  }) = CatalogImportFailed;

  factory CatalogImportProgress.fromJson(Map<String, dynamic> json) => _$CatalogImportProgressFromJson(json);
}
