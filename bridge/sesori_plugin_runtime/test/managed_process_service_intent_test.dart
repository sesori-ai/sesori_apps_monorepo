import "dart:async";
import "dart:convert";
import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

const _ownershipFile = "opencode-processes.json";
const _intentFile = "OPENCODE-start-intent.json";
const _gracefulShutdownWait = Duration(seconds: 5);
const _legacyHealthPolicy = RuntimeHealthPolicy.attemptCount(attempts: 5, delay: Duration(milliseconds: 500));

void main() {
  group("ManagedProcessService intent side-file timing", () {
    late _Harness harness;

    setUp(() {
      harness = _Harness();
    });

    test("writes the intent before spawn and resolves it after the starting record", () async {
      harness.spawn.results.add(_spawned(pid: 301, port: 50123, exitImmediately: false));
      harness.probe.results.add(const RuntimeHealthProbe(healthy: true));

      final handle = await harness.service().start(
        spec: harness.spec(port: 50123),
        terminatedBridgeIdentities: const <ProcessIdentity>[],
      );

      // The intent existed on disk at the moment the child was spawned...
      expect(harness.intentPresentAtSpawn, isTrue);
      final spawnTimeIntent = harness.intentAtSpawn;
      expect(spawnTimeIntent, isNotNull);
      expect(spawnTimeIntent!["port"], equals(50123));
      expect(spawnTimeIntent["ownerSessionId"], equals("current-owner"));
      expect(spawnTimeIntent["bridgePid"], equals(900));
      // ...and it is gone once the ownership record exists.
      expect(harness.store.files.containsKey(_intentFile), isFalse);

      // The frozen ownership file holds exactly the ready record.
      final ownership = harness.decodeOwnership();
      expect(ownership.keys, equals(<String>["current-owner"]));
      expect(ownership["current-owner"]!["status"], equals("ready"));
      expect(handle.port, equals(50123));
    });

    test("clears the intent when the spawn itself fails", () async {
      harness.spawn.results.add(const ProcessException("opencode", <String>["serve"]));

      await expectLater(
        harness.service().start(
          spec: harness.spec(port: 50124),
          terminatedBridgeIdentities: const <ProcessIdentity>[],
        ),
        throwsA(isA<ProcessException>()),
      );

      expect(harness.intentPresentAtSpawn, isTrue);
      expect(harness.store.files.containsKey(_intentFile), isFalse);
      // The frozen ownership file was never created by the failed attempt.
      expect(harness.store.files.containsKey(_ownershipFile), isFalse);
    });

    test("clears the intent and the record when the start rolls back after spawn", () async {
      harness.spawn.results.add(_spawned(pid: 302, port: 50125, exitImmediately: true));
      harness.probe.results.addAll(<RuntimeHealthProbe>[
        for (var i = 0; i < 5; i += 1) const RuntimeHealthProbe(healthy: false, error: "not ready"),
      ]);
      harness.processes.inspectResults[302] = <ProcessIdentity?>[null];

      await expectLater(
        harness.service().start(
          spec: harness.spec(port: 50125),
          terminatedBridgeIdentities: const <ProcessIdentity>[],
        ),
        throwsA(isA<PluginStartException>()),
      );

      expect(harness.intentPresentAtSpawn, isTrue);
      expect(harness.store.files.containsKey(_intentFile), isFalse);
      // The rolled-back record leaves the ownership file empty/absent.
      expect(harness.decodeOwnership(), isEmpty);
    });

    test("an intent write leaves the frozen ownership file untouched (mixed-version inertness)", () async {
      // A pre-migration bridge only ever reads the ownership file. Writing the
      // bridge-private intent side file must be invisible to it.
      final intentStore = RuntimeStartIntentStore(store: harness.store, fileName: _intentFile);
      await intentStore.write(
        RuntimeStartIntent(
          ownerSessionId: "current-owner",
          port: 4096,
          bridgePid: 900,
          bridgeStartMarker: "bridge-start",
          recordedAt: DateTime.utc(2026, 5, 15, 12, 30),
        ),
      );

      // The side file is its own, separately named file...
      expect(harness.store.files.containsKey(_intentFile), isTrue);
      // ...and the ownership file an old bridge reads is still absent.
      expect(await harness.store.read(name: _ownershipFile), isNull);

      // The round-trip preserves the intent for a future bridge that resolves it.
      final readBack = await intentStore.read();
      expect(readBack, isNotNull);
      expect(readBack!.port, equals(4096));
      expect(readBack.ownerSessionId, equals("current-owner"));

      await intentStore.clear();
      expect(harness.store.files.containsKey(_intentFile), isFalse);
      // clear() is idempotent.
      await intentStore.clear();
    });
  });
}

_FakeSpawnedProcess _spawned({required int pid, required int port, required bool exitImmediately}) {
  return _FakeSpawnedProcess(
    identity: ProcessIdentity(
      pid: pid,
      startMarker: "open-start",
      executablePath: "/usr/local/bin/opencode",
      commandLine: "/usr/local/bin/opencode serve --port $port --hostname 127.0.0.1",
      ownerUser: ProcessUser.fromRawUser("alex"),
      platform: "macos",
      capturedAt: DateTime.utc(2026, 5, 15, 12),
    ),
    exitImmediately: exitImmediately,
  );
}

class _Harness {
  _Harness() {
    intentStore = RuntimeStartIntentStore(store: store, fileName: _intentFile);
    spawn.onSpawn = () {
      final contents = store.files[_intentFile];
      intentPresentAtSpawn = contents != null;
      intentAtSpawn = contents == null ? null : Map<String, dynamic>.from(jsonDecode(contents) as Map);
    };
  }

  final _InMemoryHostJsonStore store = _InMemoryHostJsonStore();
  final _SpawnPlan spawn = _SpawnPlan();
  final _ProbePlan probe = _ProbePlan();
  final _FakeHostProcessService processes = _FakeHostProcessService();
  final _FakeServerClock clock = _FakeServerClock();
  final _FakeBridgeHostInfo bridge = _FakeBridgeHostInfo();
  late final RuntimeStartIntentStore intentStore;

  bool intentPresentAtSpawn = false;
  Map<String, dynamic>? intentAtSpawn;

  ManagedProcessService<_IntentRecord> service() {
    return ManagedProcessService<_IntentRecord>(
      ownershipRepository: HostJsonRuntimeOwnershipRepository<_IntentRecord>(
        store: store,
        mapper: const _IntentRecordMapper(),
        fileName: _ownershipFile,
        clock: clock,
      ),
      mapper: const _IntentRecordMapper(),
      processes: processes,
      bridge: bridge,
      clock: clock,
      runtimeId: "OPENCODE",
      gracefulShutdownWait: _gracefulShutdownWait,
      intentStore: intentStore,
    );
  }

  ManagedRuntimeSpec<_IntentRecord> spec({required int port}) {
    return ManagedRuntimeSpec<_IntentRecord>(
      spawn: spawn.spawn,
      probeHealth: probe.probe,
      probePortBindable: ({required int port}) async => true,
      buildRecord: (draft) => _IntentRecord(
        ownerSessionId: draft.ownerSessionId,
        openCodePid: draft.runtimeIdentity.pid,
        openCodeStartMarker: draft.runtimeIdentity.startMarker,
        openCodeExecutablePath: draft.runtimeIdentity.executablePath ?? "",
        commandLine: draft.runtimeIdentity.commandLine,
        port: draft.port,
        bridgePid: draft.bridgeIdentity.pid,
        bridgeStartMarker: draft.bridgeIdentity.startMarker,
        status: "starting",
      ),
      portPolicy: ExplicitPortPolicy(port: port),
      healthPolicy: _legacyHealthPolicy,
      recordTiming: RuntimeRecordTiming.intentSideFile,
    );
  }

  Map<String, Map<String, dynamic>> decodeOwnership() {
    final contents = store.files[_ownershipFile];
    if (contents == null) {
      return <String, Map<String, dynamic>>{};
    }
    final decoded = Map<String, dynamic>.from(jsonDecode(contents) as Map);
    return decoded.map((key, value) => MapEntry(key, Map<String, dynamic>.from(value as Map)));
  }
}

class _InMemoryHostJsonStore implements HostJsonStore {
  final Map<String, String> files = <String, String>{};

  @override
  Future<String?> read({required String name}) async => files[name];

  @override
  Future<void> write({required String name, required String contents}) async {
    files[name] = contents;
  }

  @override
  Future<void> delete({required String name}) async {
    files.remove(name);
  }

  @override
  Future<void> quarantine({required String name, required String quarantinedName}) async {
    final contents = files.remove(name);
    if (contents != null) {
      files[quarantinedName] = contents;
    }
  }

  @override
  Future<String?> update({
    required String name,
    required FutureOr<String?> Function(String? current) transform,
  }) async {
    final next = await transform(files[name]);
    if (next == null) {
      files.remove(name);
    } else {
      files[name] = next;
    }
    return next;
  }
}

class _SpawnPlan {
  final List<Object> results = <Object>[];
  final List<int> spawnedPorts = <int>[];
  void Function()? onSpawn;

  Future<SpawnedProcess> spawn({required int port}) async {
    spawnedPorts.add(port);
    onSpawn?.call();
    final result = results.removeAt(0);
    if (result is SpawnedProcess) {
      return result;
    }
    throw result;
  }
}

class _ProbePlan {
  final List<RuntimeHealthProbe> results = <RuntimeHealthProbe>[];

  Future<RuntimeHealthProbe> probe({required int port}) async {
    if (results.isEmpty) {
      return const RuntimeHealthProbe(healthy: false, error: "no probe configured");
    }
    return results.removeAt(0);
  }
}

class _IntentRecord {
  const _IntentRecord({
    required this.ownerSessionId,
    required this.openCodePid,
    required this.openCodeStartMarker,
    required this.openCodeExecutablePath,
    required this.commandLine,
    required this.port,
    required this.bridgePid,
    required this.bridgeStartMarker,
    required this.status,
  });

  final String ownerSessionId;
  final int openCodePid;
  final String? openCodeStartMarker;
  final String openCodeExecutablePath;
  final String commandLine;
  final int port;
  final int bridgePid;
  final String? bridgeStartMarker;
  final String status;

  _IntentRecord withStatus(String status) {
    return _IntentRecord(
      ownerSessionId: ownerSessionId,
      openCodePid: openCodePid,
      openCodeStartMarker: openCodeStartMarker,
      openCodeExecutablePath: openCodeExecutablePath,
      commandLine: commandLine,
      port: port,
      bridgePid: bridgePid,
      bridgeStartMarker: bridgeStartMarker,
      status: status,
    );
  }
}

class _IntentRecordMapper implements RuntimeRecordMapper<_IntentRecord> {
  const _IntentRecordMapper();

  @override
  Map<String, dynamic> toJson({required _IntentRecord record}) {
    return <String, dynamic>{
      "ownerSessionId": record.ownerSessionId,
      "openCodePid": record.openCodePid,
      "openCodeStartMarker": record.openCodeStartMarker,
      "openCodeExecutablePath": record.openCodeExecutablePath,
      "commandLine": record.commandLine,
      "port": record.port,
      "bridgePid": record.bridgePid,
      "bridgeStartMarker": record.bridgeStartMarker,
      "status": record.status,
    };
  }

  @override
  _IntentRecord fromJson({required Map<String, dynamic> json}) {
    return _IntentRecord(
      ownerSessionId: json["ownerSessionId"] as String,
      openCodePid: json["openCodePid"] as int,
      openCodeStartMarker: json["openCodeStartMarker"] as String?,
      openCodeExecutablePath: json["openCodeExecutablePath"] as String,
      commandLine: json["commandLine"] as String,
      port: json["port"] as int,
      bridgePid: json["bridgePid"] as int,
      bridgeStartMarker: json["bridgeStartMarker"] as String?,
      status: json["status"] as String,
    );
  }

  @override
  String ownerSessionIdOf({required _IntentRecord record}) => record.ownerSessionId;

  @override
  int runtimePidOf({required _IntentRecord record}) => record.openCodePid;

  @override
  String? runtimeStartMarkerOf({required _IntentRecord record}) => record.openCodeStartMarker;

  @override
  String? runtimeExecutablePathOf({required _IntentRecord record}) => record.openCodeExecutablePath;

  @override
  String runtimeCommandLineOf({required _IntentRecord record}) => record.commandLine;

  @override
  int bridgePidOf({required _IntentRecord record}) => record.bridgePid;

  @override
  String? bridgeStartMarkerOf({required _IntentRecord record}) => record.bridgeStartMarker;

  @override
  _IntentRecord markReady({required _IntentRecord record}) => record.withStatus("ready");

  @override
  _IntentRecord markStopping({required _IntentRecord record}) => record.withStatus("stopping");
}

class _FakeHostProcessService implements HostProcessService {
  final Map<int, List<ProcessIdentity?>> inspectResults = <int, List<ProcessIdentity?>>{};
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
    return _signal(pid: pid, signal: ShutdownSignal.force);
  }

  @override
  Future<SignalResult> signalGraceful({required int pid}) async {
    signalRequests.add("graceful:$pid");
    return _signal(pid: pid, signal: ShutdownSignal.graceful);
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

  SignalResult _signal({required int pid, required ShutdownSignal signal}) {
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
  @override
  List<ProcessIdentity> get terminatedBridgeIdentities => const [];

  @override
  ProcessIdentity get identity => ProcessIdentity(
    pid: 900,
    startMarker: "bridge-start",
    executablePath: "/usr/local/bin/sesori-bridge",
    commandLine: "sesori-bridge",
    ownerUser: ProcessUser.fromRawUser("alex"),
    platform: "macos",
    capturedAt: DateTime.utc(2026, 5, 15, 12),
  );

  @override
  String get ownerSessionId => "current-owner";

  @override
  Future<bool> isLiveBridgeProcess({required int pid, required String? startMarker}) async => false;
}

class _FakeServerClock implements ServerClock {
  @override
  Future<void> delay({required Duration duration}) async {}

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
}
