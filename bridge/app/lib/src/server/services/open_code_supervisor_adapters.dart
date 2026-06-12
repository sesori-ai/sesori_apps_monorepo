import "dart:io" as io;

import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show BridgeHostInfo, HostProcessService, ProcessIdentity, SignalResult, SpawnedProcess;
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart"
    show RuntimeOwnershipRepository, RuntimeRecordMapper;

import "../foundation/process_match.dart";
import "../models/open_code_ownership_record.dart";
import "../repositories/open_code_ownership_repository.dart";
import "../repositories/process_repository.dart";

/// Thin, named adapters that bridge the legacy constructor-injected
/// repositories into the seams [ManagedProcessService] consumes. They are the
/// "constructor/adapter seams only" the PR 10 fidelity gate is built around:
/// the extracted supervisor runs against these wrappers, so the unchanged
/// 1,224-line `open_code_server_service_test.dart` still exercises the same
/// fakes and asserts the same observable behavior.

/// Maps an [OpenCodeOwnershipRecord] to and from the generic record view the
/// supervisor works with. `toJson`/`fromJson` are required by the interface but
/// unused on this path — PR 10 keeps writing through the legacy
/// [OpenCodeOwnershipRepository] (byte-frozen file), not the host-JSON store —
/// so they simply defer to the freezed model's own serialization.
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
      _withStatus(record: record, status: OpenCodeOwnershipStatus.ready);

  @override
  OpenCodeOwnershipRecord markStopping({required OpenCodeOwnershipRecord record}) =>
      _withStatus(record: record, status: OpenCodeOwnershipStatus.stopping);

  static OpenCodeOwnershipRecord _withStatus({
    required OpenCodeOwnershipRecord record,
    required OpenCodeOwnershipStatus status,
  }) {
    return OpenCodeOwnershipRecord(
      ownerSessionId: record.ownerSessionId,
      openCodePid: record.openCodePid,
      openCodeStartMarker: record.openCodeStartMarker,
      openCodeExecutablePath: record.openCodeExecutablePath,
      openCodeCommand: record.openCodeCommand,
      openCodeArgs: record.openCodeArgs,
      port: record.port,
      bridgePid: record.bridgePid,
      bridgeStartMarker: record.bridgeStartMarker,
      startedAt: record.startedAt,
      status: status,
    );
  }
}

/// Routes the supervisor's record-level ownership operations straight through
/// to the legacy [OpenCodeOwnershipRepository], so the on-disk
/// `opencode-processes.json` is written by the exact same code (and the exact
/// same bytes) as before this PR.
class OpenCodeOwnershipStoreAdapter implements RuntimeOwnershipRepository<OpenCodeOwnershipRecord> {
  const OpenCodeOwnershipStoreAdapter({required OpenCodeOwnershipRepository repository}) : _repository = repository;

  final OpenCodeOwnershipRepository _repository;

  @override
  Future<List<OpenCodeOwnershipRecord>> readAll() => _repository.readAll();

  @override
  Future<OpenCodeOwnershipRecord?> readByOwnerSessionId({required String ownerSessionId}) =>
      _repository.readByOwnerSessionId(ownerSessionId: ownerSessionId);

  @override
  Future<void> upsert({required OpenCodeOwnershipRecord record}) => _repository.upsert(record: record);

  @override
  Future<void> deleteByOwnerSessionId({required String ownerSessionId}) =>
      _repository.deleteByOwnerSessionId(ownerSessionId: ownerSessionId);
}

/// Exposes the bridge-side [ProcessRepository] as the [HostProcessService] the
/// supervisor inspects and signals through. Only the inspect/signal surface is
/// used on the legacy path; [spawn] is owned by the spec's spawn seam (which
/// keeps the existing post-spawn identity capture), so it is unreachable here.
class OpenCodeHostProcessAdapter implements HostProcessService {
  const OpenCodeHostProcessAdapter({required ProcessRepository processRepository})
    : _processRepository = processRepository;

  final ProcessRepository _processRepository;

  @override
  Future<ProcessIdentity?> inspect({required int pid}) => _processRepository.inspectProcess(pid: pid);

  @override
  Future<List<ProcessIdentity>> list({required int? excludePid}) =>
      _processRepository.listProcessIdentities(excludePid: excludePid);

  @override
  Future<SignalResult> signalGraceful({required int pid}) => _processRepository.sendGracefulSignal(pid: pid);

  @override
  Future<SignalResult> signalForce({required int pid}) => _processRepository.sendForceSignal(pid: pid);

  @override
  Future<SpawnedProcess> spawn({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
  }) {
    // The OpenCode runtime is launched through the spec's spawn seam
    // (OpenCodeProcessRepository.startProcess + post-spawn identity capture),
    // never through the host. The supervisor never calls this on the legacy
    // path; failing loud guards against a future caller assuming it does.
    throw UnsupportedError("OpenCode spawns through OpenCodeProcessRepository, not the host process service");
  }
}

/// Answers the supervisor's bridge-identity questions from the same facts and
/// classifier the legacy `_isStaleKillAuthorized` used: the current bridge
/// identity, the owner session id, and the sesori-bridge process match.
class OpenCodeBridgeHostInfo implements BridgeHostInfo {
  const OpenCodeBridgeHostInfo({
    required ProcessRepository processRepository,
    required ProcessIdentity identity,
    required String ownerSessionId,
  }) : _processRepository = processRepository,
       _identity = identity,
       _ownerSessionId = ownerSessionId;

  final ProcessRepository _processRepository;
  final ProcessIdentity _identity;
  final String _ownerSessionId;

  @override
  ProcessIdentity get identity => _identity;

  @override
  String get ownerSessionId => _ownerSessionId;

  @override
  Future<bool> isLiveBridgeProcess({required int pid, required String? startMarker}) async {
    // Reproduces the legacy owner-liveness check verbatim: a process is a live
    // owner only when it still classifies as a sesori-bridge and its start
    // marker matches (with the both-null Windows fallback accepting the match).
    final match = await _processRepository.inspectProcessMatch(pid: pid);
    if (match == null || match.kind != ProcessMatchKind.sesoriBridge) {
      return false;
    }
    final matchIdentity = match.identity;
    if (matchIdentity.pid != pid) {
      return false;
    }
    if (startMarker != null || matchIdentity.startMarker != null) {
      return matchIdentity.startMarker == startMarker;
    }
    return true;
  }
}

/// Wraps the `dart:io` [io.Process] returned by `OpenCodeProcessRepository` as
/// the [SpawnedProcess] the supervisor tracks, carrying the captured (best
/// effort, possibly inspected) identity. [rawProcess] hands the underlying
/// process back so `OpenCodeServerService` can rebuild its public
/// `OpenCodeServerRuntime`.
class SpawnedOpenCodeProcess implements SpawnedProcess {
  const SpawnedOpenCodeProcess({required io.Process process, required this.identity}) : _process = process;

  final io.Process _process;

  @override
  final ProcessIdentity identity;

  /// The underlying spawned process, exposed for `OpenCodeServerRuntime`.
  io.Process get rawProcess => _process;

  @override
  int get pid => _process.pid;

  @override
  io.IOSink get stdin => _process.stdin;

  @override
  Stream<List<int>> get stdout => _process.stdout;

  @override
  Stream<List<int>> get stderr => _process.stderr;

  @override
  Future<int> get exitCode => _process.exitCode;
}
