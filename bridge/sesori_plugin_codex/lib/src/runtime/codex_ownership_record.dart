import "package:freezed_annotation/freezed_annotation.dart";

part "codex_ownership_record.freezed.dart";
part "codex_ownership_record.g.dart";

/// Lifecycle status of an owned `codex app-server` process, as persisted in the
/// `codex-processes.json` ownership file.
enum CodexOwnershipStatus {
  starting,
  ready,
  stopping,
}

/// The Codex ownership record persisted to
/// `<stateDir>/codex-processes.json`.
///
/// Mirrors the OpenCode ownership record field-for-field (renamed for codex) so
/// the shared `sesori_plugin_runtime` supervisor can track, match, and reap an
/// owned `codex app-server` child exactly the way it does for OpenCode. It is
/// supplied to the managed-runtime supervisor as the concrete record type via
/// [CodexRecordMapper].
@freezed
sealed class CodexOwnershipRecord with _$CodexOwnershipRecord {
  const factory CodexOwnershipRecord({
    required String ownerSessionId,
    required int codexPid,
    required String? codexStartMarker,
    required String codexExecutablePath,
    required String codexCommand,
    required List<String> codexArgs,
    required int port,
    required int bridgePid,
    required String? bridgeStartMarker,
    required DateTime startedAt,
    required CodexOwnershipStatus status,
  }) = _CodexOwnershipRecord;

  factory CodexOwnershipRecord.fromJson(Map<String, dynamic> json) =>
      _$CodexOwnershipRecordFromJson(json);
}
