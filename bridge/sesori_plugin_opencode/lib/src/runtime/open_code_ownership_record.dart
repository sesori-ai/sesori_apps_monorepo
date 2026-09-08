import "package:freezed_annotation/freezed_annotation.dart";

part "open_code_ownership_record.freezed.dart";
part "open_code_ownership_record.g.dart";

/// Lifecycle status of an owned `opencode serve` process, as persisted in the
/// frozen `opencode-processes.json` ownership file.
enum OpenCodeOwnershipStatus() {
  starting,
  ready,
  stopping,
}

/// The OpenCode ownership record persisted to `<cacheDir>/runtime/opencode-processes.json`.
///
/// Supplied to the managed-runtime supervisor as its concrete record type via
/// [OpenCodeRecordMapper]. Field names and JSON encoding form the frozen
/// ownership-file persistence contract.
@freezed
sealed class OpenCodeOwnershipRecord with _$OpenCodeOwnershipRecord {
  const factory({
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

  factory fromJson(Map<String, dynamic> json) =>
      _$OpenCodeOwnershipRecordFromJson(json);
}
