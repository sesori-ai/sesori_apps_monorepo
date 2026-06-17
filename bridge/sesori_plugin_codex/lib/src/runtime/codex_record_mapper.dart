import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart" show RuntimeRecordMapper;

import "codex_ownership_record.dart";

/// Maps a [CodexOwnershipRecord] to and from the generic record view the
/// [ManagedProcessService] supervisor works with.
///
/// `toJson`/`fromJson` defer to the freezed model's own serialization; the
/// remaining accessors extract the identity fields the supervisor uses for
/// process matching and stale-cleanup authorization, and the `mark*` helpers
/// flip the status field via freezed `copyWith`.
class CodexRecordMapper implements RuntimeRecordMapper<CodexOwnershipRecord> {
  const CodexRecordMapper();

  @override
  Map<String, dynamic> toJson({required CodexOwnershipRecord record}) => record.toJson();

  @override
  CodexOwnershipRecord fromJson({required Map<String, dynamic> json}) =>
      CodexOwnershipRecord.fromJson(json);

  @override
  String ownerSessionIdOf({required CodexOwnershipRecord record}) => record.ownerSessionId;

  @override
  int runtimePidOf({required CodexOwnershipRecord record}) => record.codexPid;

  @override
  String? runtimeStartMarkerOf({required CodexOwnershipRecord record}) => record.codexStartMarker;

  @override
  String? runtimeExecutablePathOf({required CodexOwnershipRecord record}) => record.codexExecutablePath;

  @override
  String runtimeCommandLineOf({required CodexOwnershipRecord record}) =>
      <String>[record.codexCommand, ...record.codexArgs].join(" ");

  @override
  int bridgePidOf({required CodexOwnershipRecord record}) => record.bridgePid;

  @override
  String? bridgeStartMarkerOf({required CodexOwnershipRecord record}) => record.bridgeStartMarker;

  @override
  CodexOwnershipRecord markReady({required CodexOwnershipRecord record}) =>
      record.copyWith(status: CodexOwnershipStatus.ready);

  @override
  CodexOwnershipRecord markStopping({required CodexOwnershipRecord record}) =>
      record.copyWith(status: CodexOwnershipStatus.stopping);
}
