import "package:freezed_annotation/freezed_annotation.dart";

part "catalog_import_progress.freezed.dart";
part "catalog_import_progress.g.dart";

/// How much of a completed import was genuinely new, as opposed to rows the
/// catalog already held.
///
/// Carried as one optional group rather than two independently nullable counts,
/// so "the delta is known" and "the delta is absent" are the only two states a
/// consumer has to handle. A bridge that predates this field omits the whole
/// object, which honestly means unknown; a consumer must then fall back to the
/// total counts rather than reporting that nothing was new.
@Freezed(fromJson: true, toJson: true)
sealed class CatalogImportNewItems with _$CatalogImportNewItems {
  const factory({
    required int projects,
    required int sessions,
  }) = _CatalogImportNewItems;

  factory fromJson(Map<String, dynamic> json) => _$CatalogImportNewItemsFromJson(json);
}

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

  /// [projectsImported] and [sessionsImported] are the totals published, not
  /// the number that changed. [newItems] carries the delta when the bridge
  /// reports one and is absent on a bridge that predates it.
  // COMPATIBILITY 2026-08-24 (v1.9.0): newItems is nullable because bridges
  // released before v1.9.0 omit it, and absence there honestly means "this
  // producer does not report a delta" rather than "nothing was new". An
  // @Default is deliberately not used: zero already means "nothing was new",
  // so defaulting would make an older bridge claim a fact it never sent.
  // Cleanup: make newItems non-nullable and drop every consumer's totals
  // fallback once the minimum supported bridge is >= v1.9.0.
  @FreezedUnionValue("completed")
  const factory completed({
    required String pluginId,
    required int projectsImported,
    required int sessionsImported,
    required int completedAt,
    required CatalogImportNewItems? newItems,
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
