import "dart:async";
import "dart:convert";
import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

const _gracefulShutdownWait = Duration(seconds: 5);

void main() {
  group("ManagedProcessService", () {
    late _FakeOwnershipRepository ownershipRepository;
    late _FakeHostProcessService processService;
    late _FakeBridgeHostInfo bridge;
    late _FakeServerClock clock;

    setUp(() {
      ownershipRepository = _FakeOwnershipRepository();
      processService = _FakeHostProcessService();
      bridge = _FakeBridgeHostInfo(
        identity: _identity(
          pid: 900,
          startMarker: "bridge-start",
          executablePath: "/usr/local/bin/sesori-bridge",
          commandLine: "sesori-bridge",
        ),
      );
      clock = _FakeServerClock();
    });

    test("stale cleanup kills matching OpenCode only when owner bridge is dead", () async {
      final staleRecord = _record(
        ownerSessionId: "stale-owner",
        openCodePid: 401,
        openCodeStartMarker: "open-start",
        bridgePid: 901,
        bridgeStartMarker: "dead-bridge-start",
      );
      ownershipRepository.records[staleRecord.ownerSessionId] = staleRecord;
      processService.inspectResults[401] = <ProcessIdentity?>[
        _opencodeIdentity(pid: 401, startMarker: "open-start"),
        _opencodeIdentity(pid: 401, startMarker: "open-start"),
        _opencodeIdentity(pid: 401, startMarker: "open-start"),
        null,
      ];
      bridge.liveBridgeResults[901] = <bool>[false];

      await _service(
        ownershipRepository: ownershipRepository,
        processService: processService,
        bridge: bridge,
        clock: clock,
      ).cleanupStaleOwnedRuntimes(terminatedBridgeIdentities: const <ProcessIdentity>[]);

      expect(processService.signalRequests, equals(<String>["graceful:401", "force:401"]));
      expect(ownershipRepository.records, isEmpty);
      expect(clock.delays, equals(<Duration>[_gracefulShutdownWait]));
    });

    test("stale cleanup does not signal when pre-signal identity no longer matches", () async {
      final staleRecord = _record(
        ownerSessionId: "stale-owner",
        openCodePid: 402,
        openCodeStartMarker: "open-start",
        bridgePid: 901,
        bridgeStartMarker: "dead-bridge-start",
      );
      ownershipRepository.records[staleRecord.ownerSessionId] = staleRecord;
      processService.inspectResults[402] = <ProcessIdentity?>[
        _opencodeIdentity(pid: 402, startMarker: "open-start"),
        _opencodeIdentity(pid: 402, startMarker: "different-start"),
      ];
      bridge.liveBridgeResults[901] = <bool>[false];

      await _service(
        ownershipRepository: ownershipRepository,
        processService: processService,
        bridge: bridge,
        clock: clock,
      ).cleanupStaleOwnedRuntimes(terminatedBridgeIdentities: const <ProcessIdentity>[]);

      expect(processService.signalRequests, isEmpty);
      expect(clock.delays, isEmpty);
      expect(ownershipRepository.records, isEmpty);
    });

    test("stale cleanup preserves live owner and missing marker records", () async {
      final liveRecord = _record(
        ownerSessionId: "live-owner",
        openCodePid: 501,
        openCodeStartMarker: "open-live",
        bridgePid: 902,
        bridgeStartMarker: "live-bridge-start",
      );
      final missingMarkerRecord = _record(
        ownerSessionId: "missing-marker",
        openCodePid: 502,
        openCodeStartMarker: null,
        bridgePid: 903,
        bridgeStartMarker: "dead-bridge-start",
      );
      ownershipRepository.records[liveRecord.ownerSessionId] = liveRecord;
      ownershipRepository.records[missingMarkerRecord.ownerSessionId] = missingMarkerRecord;
      processService.inspectResults[501] = <ProcessIdentity?>[_opencodeIdentity(pid: 501, startMarker: "open-live")];
      bridge.liveBridgeResults[902] = <bool>[true];

      await _service(
        ownershipRepository: ownershipRepository,
        processService: processService,
        bridge: bridge,
        clock: clock,
      ).cleanupStaleOwnedRuntimes(terminatedBridgeIdentities: const <ProcessIdentity>[]);

      expect(processService.signalRequests, isEmpty);
      expect(ownershipRepository.records.keys, contains("live-owner"));
    });

    test("stale cleanup kill-authorizes persisted records missing a start marker when bridge is dead", () async {
      final missingMarkerRecord = _record(
        ownerSessionId: "missing-marker",
        openCodePid: 503,
        openCodeStartMarker: null,
        bridgePid: 903,
        bridgeStartMarker: "dead-bridge-start",
      );
      ownershipRepository.records[missingMarkerRecord.ownerSessionId] = missingMarkerRecord;
      processService.inspectResults[503] = <ProcessIdentity?>[
        _opencodeIdentity(pid: 503, startMarker: null),
        _opencodeIdentity(pid: 503, startMarker: null),
        null,
      ];
      bridge.liveBridgeResults[903] = <bool>[false];

      await _service(
        ownershipRepository: ownershipRepository,
        processService: processService,
        bridge: bridge,
        clock: clock,
      ).cleanupStaleOwnedRuntimes(terminatedBridgeIdentities: const <ProcessIdentity>[]);

      expect(processService.signalRequests, equals(<String>["graceful:503"]));
      expect(ownershipRepository.records, isEmpty);
    });

    test("replacement bridge identity authorizes stale OpenCode cleanup", () async {
      final record = _record(
        ownerSessionId: "replaced-owner",
        openCodePid: 601,
        openCodeStartMarker: "open-replaced",
        bridgePid: 904,
        bridgeStartMarker: "replaced-bridge-start",
      );
      ownershipRepository.records[record.ownerSessionId] = record;
      processService.inspectResults[601] = <ProcessIdentity?>[
        _opencodeIdentity(pid: 601, startMarker: "open-replaced"),
        _opencodeIdentity(pid: 601, startMarker: "open-replaced"),
        null,
        null,
      ];

      await _service(
        ownershipRepository: ownershipRepository,
        processService: processService,
        bridge: bridge,
        clock: clock,
      ).cleanupStaleOwnedRuntimes(
        terminatedBridgeIdentities: <ProcessIdentity>[
          _identity(
            pid: 904,
            startMarker: "replaced-bridge-start",
            executablePath: "/usr/local/bin/sesori-bridge",
            commandLine: "sesori-bridge",
          ),
        ],
      );

      expect(processService.signalRequests, equals(<String>["graceful:601"]));
      expect(ownershipRepository.records, isEmpty);
    });

    test("shutdown revalidates identity before force kill", () async {
      final record = _record(
        ownerSessionId: "current-owner",
        openCodePid: 701,
        openCodeStartMarker: "open-current",
        bridgePid: 900,
        bridgeStartMarker: "bridge-start",
      );
      ownershipRepository.records[record.ownerSessionId] = record;
      processService.inspectResults[701] = <ProcessIdentity?>[
        _opencodeIdentity(pid: 701, startMarker: "open-current"),
        _opencodeIdentity(pid: 701, startMarker: "open-current"),
        null,
      ];

      await _service(
        ownershipRepository: ownershipRepository,
        processService: processService,
        bridge: bridge,
        clock: clock,
      ).stopOwnedRuntime(record: record);

      expect(processService.signalRequests, equals(<String>["graceful:701", "force:701"]));
      expect(ownershipRepository.upsertedStatuses.last, equals(_TestStatus.stopping));
      expect(ownershipRepository.records, isEmpty);
    });

    test("shutdown keeps ownership when current-owned missing-marker child survives force", () async {
      final spawnedProcess = _FakeSpawnedProcess(
        identity: _opencodeIdentity(pid: 702, startMarker: null, port: 50131),
        exitImmediately: false,
      );
      final record = _record(
        ownerSessionId: "current-owner",
        openCodePid: 702,
        openCodeStartMarker: null,
        bridgePid: 900,
        bridgeStartMarker: "bridge-start",
        port: 50131,
      );
      ownershipRepository.records[record.ownerSessionId] = record;
      processService.inspectResults[702] = <ProcessIdentity?>[null, null, null];
      final service = _service(
        ownershipRepository: ownershipRepository,
        processService: processService,
        bridge: bridge,
        clock: clock,
      );
      service.trackOwnedRuntime(ownerSessionId: record.ownerSessionId, process: spawnedProcess);

      await service.stopOwnedRuntime(record: record);

      expect(processService.signalRequests, equals(<String>["graceful:702", "force:702"]));
      expect(ownershipRepository.records.keys, contains("current-owner"));
      expect(ownershipRepository.records.values.single.status, equals(_TestStatus.stopping));
      expect(clock.delays, equals(<Duration>[_gracefulShutdownWait]));
      expect(service.isTrackingOwnedRuntime(ownerSessionId: record.ownerSessionId), isTrue);
    });

    test("shutdown does not signal an exited current-owned missing-marker child", () async {
      final spawnedProcess = _FakeSpawnedProcess(
        identity: _opencodeIdentity(pid: 703, startMarker: null, port: 50132),
        exitImmediately: false,
      );
      final record = _record(
        ownerSessionId: "current-owner",
        openCodePid: 703,
        openCodeStartMarker: null,
        bridgePid: 900,
        bridgeStartMarker: "bridge-start",
        port: 50132,
      );
      ownershipRepository.records[record.ownerSessionId] = record;
      processService.inspectResults[703] = <ProcessIdentity?>[null];
      final service = _service(
        ownershipRepository: ownershipRepository,
        processService: processService,
        bridge: bridge,
        clock: clock,
      );
      service.trackOwnedRuntime(ownerSessionId: record.ownerSessionId, process: spawnedProcess);
      spawnedProcess.completeExit();

      await service.stopOwnedRuntime(record: record);

      expect(processService.signalRequests, isEmpty);
      expect(ownershipRepository.records, isEmpty);
      expect(clock.delays, isEmpty);
      expect(service.isTrackingOwnedRuntime(ownerSessionId: record.ownerSessionId), isFalse);
    });

    test("stop path never calls child process kill directly", () async {
      final spawnedProcess = _FakeSpawnedProcess(
        identity: _opencodeIdentity(pid: 211, startMarker: "open-start-211", port: 50129),
        exitImmediately: true,
      );
      final record = _record(
        ownerSessionId: "current-owner",
        openCodePid: 211,
        openCodeStartMarker: "open-start-211",
        bridgePid: 900,
        bridgeStartMarker: "bridge-start",
        port: 50129,
      );
      ownershipRepository.records[record.ownerSessionId] = record;
      processService.inspectResults[211] = <ProcessIdentity?>[
        _opencodeIdentity(pid: 211, startMarker: "open-start-211", port: 50129),
        null,
        null,
      ];
      final service = _service(
        ownershipRepository: ownershipRepository,
        processService: processService,
        bridge: bridge,
        clock: clock,
      );
      service.trackOwnedRuntime(ownerSessionId: record.ownerSessionId, process: spawnedProcess);

      await service.stopOwnedRuntime(record: record);

      expect(processService.signalRequests, equals(<String>["graceful:211"]));
      expect(spawnedProcess.killSignals, isEmpty);
    });

    test("stop path force stops current-owned child without a start marker", () async {
      final spawnedProcess = _FakeSpawnedProcess(
        identity: _opencodeIdentity(pid: 212, startMarker: null, port: 50130),
        exitImmediately: false,
      );
      final record = _record(
        ownerSessionId: "current-owner",
        openCodePid: 212,
        openCodeStartMarker: null,
        bridgePid: 900,
        bridgeStartMarker: "bridge-start",
        port: 50130,
      );
      ownershipRepository.records[record.ownerSessionId] = record;
      processService.inspectResults[212] = <ProcessIdentity?>[null, null, null];
      processService.forceHooks[212] = spawnedProcess.completeExit;
      final service = _service(
        ownershipRepository: ownershipRepository,
        processService: processService,
        bridge: bridge,
        clock: clock,
      );
      service.trackOwnedRuntime(ownerSessionId: record.ownerSessionId, process: spawnedProcess);

      await service.stopOwnedRuntime(record: record);

      expect(processService.signalRequests, equals(<String>["graceful:212", "force:212"]));
      expect(clock.delays, equals(<Duration>[_gracefulShutdownWait]));
      expect(ownershipRepository.records, isEmpty);
      expect(spawnedProcess.killSignals, isEmpty);
    });
  });
}

ManagedProcessService<_TestRecord> _service({
  required _FakeOwnershipRepository ownershipRepository,
  required _FakeHostProcessService processService,
  required _FakeBridgeHostInfo bridge,
  required _FakeServerClock clock,
}) {
  return ManagedProcessService<_TestRecord>(
    ownershipRepository: ownershipRepository,
    mapper: const _TestRecordMapper(),
    processes: processService,
    bridge: bridge,
    clock: clock,
    runtimeId: "OPENCODE",
    gracefulShutdownWait: _gracefulShutdownWait,
  );
}

_TestRecord _record({
  required String ownerSessionId,
  required int openCodePid,
  required String? openCodeStartMarker,
  required int bridgePid,
  required String? bridgeStartMarker,
  int port = 50123,
}) {
  return _TestRecord(
    ownerSessionId: ownerSessionId,
    openCodePid: openCodePid,
    openCodeStartMarker: openCodeStartMarker,
    openCodeExecutablePath: "/usr/local/bin/opencode",
    openCodeCommand: "/usr/local/bin/opencode",
    openCodeArgs: <String>["serve", "--port", "$port", "--hostname", "127.0.0.1"],
    port: port,
    bridgePid: bridgePid,
    bridgeStartMarker: bridgeStartMarker,
    startedAt: DateTime.utc(2026, 5, 15, 12),
    status: _TestStatus.ready,
  );
}

ProcessIdentity _opencodeIdentity({required int pid, required String? startMarker, int port = 50123}) {
  return _identity(
    pid: pid,
    startMarker: startMarker,
    executablePath: "/usr/local/bin/opencode",
    commandLine: "/usr/local/bin/opencode serve --port $port --hostname 127.0.0.1",
  );
}

ProcessIdentity _identity({
  required int pid,
  required String? startMarker,
  required String executablePath,
  required String commandLine,
}) {
  return ProcessIdentity(
    pid: pid,
    startMarker: startMarker,
    executablePath: executablePath,
    commandLine: commandLine,
    ownerUser: ProcessUser.fromRawUser("alex"),
    platform: "macos",
    capturedAt: DateTime.utc(2026, 5, 15, 12),
  );
}

enum _TestStatus { ready, stopping }

class _TestRecord {
  const _TestRecord({
    required this.ownerSessionId,
    required this.openCodePid,
    required this.openCodeStartMarker,
    required this.openCodeExecutablePath,
    required this.openCodeCommand,
    required this.openCodeArgs,
    required this.port,
    required this.bridgePid,
    required this.bridgeStartMarker,
    required this.startedAt,
    required this.status,
  });

  final String ownerSessionId;
  final int openCodePid;
  final String? openCodeStartMarker;
  final String openCodeExecutablePath;
  final String openCodeCommand;
  final List<String> openCodeArgs;
  final int port;
  final int bridgePid;
  final String? bridgeStartMarker;
  final DateTime startedAt;
  final _TestStatus status;
}

class _TestRecordMapper implements RuntimeRecordMapper<_TestRecord> {
  const _TestRecordMapper();

  @override
  Map<String, dynamic> toJson({required _TestRecord record}) {
    return <String, dynamic>{
      "ownerSessionId": record.ownerSessionId,
      "openCodePid": record.openCodePid,
      "openCodeStartMarker": record.openCodeStartMarker,
      "openCodeExecutablePath": record.openCodeExecutablePath,
      "openCodeCommand": record.openCodeCommand,
      "openCodeArgs": record.openCodeArgs,
      "port": record.port,
      "bridgePid": record.bridgePid,
      "bridgeStartMarker": record.bridgeStartMarker,
      "startedAt": record.startedAt.toIso8601String(),
      "status": record.status.name,
    };
  }

  @override
  _TestRecord fromJson({required Map<String, dynamic> json}) => throw UnimplementedError();

  @override
  String ownerSessionIdOf({required _TestRecord record}) => record.ownerSessionId;

  @override
  int runtimePidOf({required _TestRecord record}) => record.openCodePid;

  @override
  String? runtimeStartMarkerOf({required _TestRecord record}) => record.openCodeStartMarker;

  @override
  String? runtimeExecutablePathOf({required _TestRecord record}) => record.openCodeExecutablePath;

  @override
  String? runtimeCommandLineOf({required _TestRecord record}) {
    return <String>[record.openCodeCommand, ...record.openCodeArgs].join(" ");
  }

  @override
  int bridgePidOf({required _TestRecord record}) => record.bridgePid;

  @override
  String? bridgeStartMarkerOf({required _TestRecord record}) => record.bridgeStartMarker;

  @override
  _TestRecord markStopping({required _TestRecord record}) {
    return _TestRecord(
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
      status: _TestStatus.stopping,
    );
  }
}

class _FakeOwnershipRepository implements RuntimeOwnershipRepository<_TestRecord> {
  final Map<String, _TestRecord> records = <String, _TestRecord>{};
  final List<_TestStatus> upsertedStatuses = <_TestStatus>[];

  @override
  Future<void> deleteByOwnerSessionId({required String ownerSessionId}) async {
    records.remove(ownerSessionId);
  }

  @override
  Future<List<_TestRecord>> readAll() async => records.values.toList(growable: false);

  @override
  Future<_TestRecord?> readByOwnerSessionId({required String ownerSessionId}) async => records[ownerSessionId];

  @override
  Future<void> upsert({required _TestRecord record}) async {
    records[record.ownerSessionId] = record;
    upsertedStatuses.add(record.status);
  }
}

class _FakeHostProcessService implements HostProcessService {
  final Map<int, List<ProcessIdentity?>> inspectResults = <int, List<ProcessIdentity?>>{};
  final Map<int, void Function()> gracefulHooks = <int, void Function()>{};
  final Map<int, void Function()> forceHooks = <int, void Function()>{};
  final List<String> signalRequests = <String>[];

  @override
  Future<ProcessIdentity?> inspect({required int pid}) async {
    final results = inspectResults[pid];
    if (results == null || results.isEmpty) {
      return null;
    }
    return results.removeAt(0);
  }

  @override
  Future<List<ProcessIdentity>> list({required int? excludePid}) async => const <ProcessIdentity>[];

  @override
  Future<SignalResult> signalForce({required int pid}) async {
    signalRequests.add("force:$pid");
    forceHooks[pid]?.call();
    return _shutdown(pid: pid, signal: ShutdownSignal.force);
  }

  @override
  Future<SignalResult> signalGraceful({required int pid}) async {
    signalRequests.add("graceful:$pid");
    gracefulHooks[pid]?.call();
    return _shutdown(pid: pid, signal: ShutdownSignal.graceful);
  }

  @override
  Future<SpawnedProcess> spawn({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
  }) async {
    throw UnimplementedError();
  }

  SignalResult _shutdown({required int pid, required ShutdownSignal signal}) {
    return SignalResult(
      pid: pid,
      requestedSignal: signal,
      deliveredSignal: signal == ShutdownSignal.graceful ? ProcessSignal.sigterm : ProcessSignal.sigkill,
      wasRequested: true,
      attemptedAt: DateTime.utc(2026, 5, 15, 12),
    );
  }
}

class _FakeBridgeHostInfo implements BridgeHostInfo {
  _FakeBridgeHostInfo({required ProcessIdentity identity}) : _identity = identity;

  final ProcessIdentity _identity;
  final Map<int, List<bool>> liveBridgeResults = <int, List<bool>>{};

  @override
  ProcessIdentity get identity => _identity;

  @override
  String get ownerSessionId => "current-owner";

  @override
  Future<bool> isLiveBridgeProcess({required int pid, required String? startMarker}) async {
    final results = liveBridgeResults[pid];
    if (results == null || results.isEmpty) {
      return false;
    }
    return results.removeAt(0);
  }
}

class _FakeServerClock implements ServerClock {
  final List<Duration> delays = <Duration>[];

  @override
  Future<void> delay({required Duration duration}) async {
    delays.add(duration);
  }

  @override
  DateTime now() => DateTime.utc(2026, 5, 15, 12, 30);
}

class _FakeSpawnedProcess implements SpawnedProcess {
  _FakeSpawnedProcess({required ProcessIdentity identity, required bool exitImmediately}) : _identity = identity {
    if (exitImmediately) {
      _exitCodeCompleter.complete(0);
    }
  }

  final ProcessIdentity _identity;
  final Completer<int> _exitCodeCompleter = Completer<int>();
  final List<ProcessSignal> killSignals = <ProcessSignal>[];

  @override
  Future<int> get exitCode => _exitCodeCompleter.future;

  @override
  ProcessIdentity get identity => _identity;

  @override
  int get pid => _identity.pid;

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  Stream<List<int>> get stderr => Stream<List<int>>.value(utf8.encode(""));

  @override
  Stream<List<int>> get stdout => Stream<List<int>>.value(utf8.encode(""));

  void completeExit([int code = 0]) {
    if (!_exitCodeCompleter.isCompleted) {
      _exitCodeCompleter.complete(code);
    }
  }
}
