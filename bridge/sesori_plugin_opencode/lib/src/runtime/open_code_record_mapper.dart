import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart" show RuntimeRecordMapper;

import "open_code_ownership_record.dart";

/// Maps an [OpenCodeOwnershipRecord] to and from the generic record view the
/// [ManagedProcessService] supervisor works with.
///
/// `toJson`/`fromJson` defer to the freezed model's own serialization, so the
/// supervisor's [HostJsonRuntimeOwnershipRepository] writes the exact same bytes
/// to `opencode-processes.json` the legacy bridge-side path did. The remaining
/// accessors extract the identity fields the supervisor uses for process
/// matching and stale-cleanup authorization, and the `mark*` helpers flip the
/// status field via freezed `copyWith`.
class OpenCodeRecordMapper implements RuntimeRecordMapper<OpenCodeOwnershipRecord> {
  const OpenCodeRecordMapper();

  @override
  Map<String, dynamic> toJson({required OpenCodeOwnershipRecord record}) => record.toJson();

  @override
  OpenCodeOwnershipRecord fromJson({required Map<String, dynamic> json}) => OpenCodeOwnershipRecord.fromJson(json);

  @override
  String ownerSessionIdOf({required OpenCodeOwnershipRecord record}) => record.ownerSessionId;

  @override
  int runtimePidOf({required OpenCodeOwnershipRecord record}) => record.openCodePid;

  @override
  String? runtimeStartMarkerOf({required OpenCodeOwnershipRecord record}) => record.openCodeStartMarker;

  @override
  String? runtimeExecutablePathOf({required OpenCodeOwnershipRecord record}) => record.openCodeExecutablePath;

  @override
  String runtimeCommandLineOf({required OpenCodeOwnershipRecord record}) =>
      <String>[record.openCodeCommand, ...record.openCodeArgs].join(" ");

  @override
  int bridgePidOf({required OpenCodeOwnershipRecord record}) => record.bridgePid;

  @override
  String? bridgeStartMarkerOf({required OpenCodeOwnershipRecord record}) => record.bridgeStartMarker;

  @override
  OpenCodeOwnershipRecord markReady({required OpenCodeOwnershipRecord record}) =>
      record.copyWith(status: OpenCodeOwnershipStatus.ready);

  @override
  OpenCodeOwnershipRecord markStopping({required OpenCodeOwnershipRecord record}) =>
      record.copyWith(status: OpenCodeOwnershipStatus.stopping);
}
