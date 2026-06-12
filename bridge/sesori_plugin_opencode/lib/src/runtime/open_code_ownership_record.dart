import "package:freezed_annotation/freezed_annotation.dart";

part "open_code_ownership_record.freezed.dart";
part "open_code_ownership_record.g.dart";

/// Lifecycle status of an owned `opencode serve` process, as persisted in the
/// frozen `opencode-processes.json` ownership file.
enum OpenCodeOwnershipStatus {
  starting,
  ready,
  stopping,
}

/// The OpenCode ownership record persisted to `<cacheDir>/runtime/opencode-processes.json`.
///
/// This is the plugin-owned copy of the bridge's existing freezed model — same
/// fields, same declaration order, same `json_serializable` output — so it
/// writes **byte-compatible** JSON to the frozen ownership file. It is supplied
/// to the managed-runtime supervisor as the concrete record type via
/// [OpenCodeRecordMapper], letting the OpenCode plugin own its own runtime
/// persistence without depending on `bridge/app`.
///
/// During the migration window (PRs 11–12) the bridge-side copy at
/// `bridge/app/lib/src/server/models/open_code_ownership_record.dart` still
/// drives the legacy path; the two are deliberately byte-identical and the
/// bridge-side copy is deleted in PR 13.
@freezed
sealed class OpenCodeOwnershipRecord with _$OpenCodeOwnershipRecord {
  const factory OpenCodeOwnershipRecord({
    required String ownerSessionId,
    required int openCodePid,
    required String? openCodeStartMarker,
    required String openCodeExecutablePath,
    required String openCodeCommand,
    required List<String> openCodeArgs,
    required int port,
    required int bridgePid,
    required String? bridgeStartMarker,
    required DateTime startedAt,
    required OpenCodeOwnershipStatus status,
  }) = _OpenCodeOwnershipRecord;

  factory OpenCodeOwnershipRecord.fromJson(Map<String, dynamic> json) =>
      _$OpenCodeOwnershipRecordFromJson(json);
}
