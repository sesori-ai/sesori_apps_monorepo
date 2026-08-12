import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

part "archived_session_file_dto.freezed.dart";

part "archived_session_file_dto.g.dart";

/// How much of the transcript the archive actually captured.
///
/// Recorded honestly so an audit file never implies completeness it does not
/// have: archiving proceeds even when the backend cannot be consulted, because
/// refusing would trap the session.
@JsonEnum()
enum ArchivedSessionCompleteness() {
  /// The store was brought current from the backend before the export.
  @JsonValue("complete")
  complete,

  /// The backend could not be consulted, so the export holds whatever the
  /// store had. The backend's own copy is untouched and still authoritative.
  @JsonValue("store_only")
  storeOnly,
}

/// The on-disk audit record for an archived session.
///
/// Written once, read rarely. Payloads are wire-model JSON so the archived
/// read path reconstructs exactly what the live store would have served.
@Freezed(fromJson: true, toJson: true)
sealed class ArchivedSessionFileDto with _$ArchivedSessionFileDto {
  const factory ArchivedSessionFileDto({
    required int schemaVersion,
    required int archivedAt,
    required ArchivedSessionCompleteness completeness,
    required ArchivedSessionSnapshotDto session,
    required List<ArchivedMessageDto> messages,
  }) = _ArchivedSessionFileDto;

  factory ArchivedSessionFileDto.fromJson(Map<String, dynamic> json) => _$ArchivedSessionFileDtoFromJson(json);
}

/// The session metadata as it stood at archive time, so the audit file is
/// readable without the main database.
@Freezed(fromJson: true, toJson: true)
sealed class ArchivedSessionSnapshotDto with _$ArchivedSessionSnapshotDto {
  const factory ArchivedSessionSnapshotDto({
    required String sessionId,
    required String backendSessionId,
    required String pluginId,
    required String projectId,
    required String? parentSessionId,
    required String directory,
    required String? worktreePath,
    required String? branchName,
    required String? baseBranch,
    required String? baseCommit,
    required String? lastAgent,
    required String? lastAgentModel,
    required String? title,
    required int createdAt,
    required int updatedAt,
  }) = _ArchivedSessionSnapshotDto;

  factory ArchivedSessionSnapshotDto.fromJson(Map<String, dynamic> json) => _$ArchivedSessionSnapshotDtoFromJson(json);
}

/// One archived message, carrying the `seq` it held in the live store so the
/// archived read path pages in the same cursor domain.
@Freezed(fromJson: true, toJson: true)
sealed class ArchivedMessageDto with _$ArchivedMessageDto {
  const factory ArchivedMessageDto({
    required int seq,
    required Message info,

    /// Parts in their **stored** form — the same JSON the live store holds,
    /// with attachments as internal `stored_file` references into the archived
    /// spill directory.
    ///
    /// Deliberately untyped: `MessagePart.fromJson` maps that internal source
    /// to its forward-compatible `unknown` fallback, which would silently drop
    /// the digest and lose the attachment. The read path rehydrates these maps
    /// exactly as it rehydrates a database row.
    required List<Map<String, dynamic>> parts,
  }) = _ArchivedMessageDto;

  factory ArchivedMessageDto.fromJson(Map<String, dynamic> json) => _$ArchivedMessageDtoFromJson(json);
}
