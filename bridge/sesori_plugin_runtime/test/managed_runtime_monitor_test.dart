import "dart:async";
import "dart:convert";
import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

const _gracefulShutdownWait = Duration(seconds: 5);
const _legacyHealthPolicy = RuntimeHealthPolicy.attemptCount(attempts: 5, delay: Duration(milliseconds: 500));

void main() {
  group("ManagedRuntimeMonitor", () {
    late _Fakes fakes;

    setUp(() {
      fakes = _Fakes();
    });

    test("arming an attached (un-owned) handle never watches or restarts", () async {
      final status = PluginStatusController(initial: const PluginReady());
      final tags = _collect(status);
      final monitor = fakes.monitor(status: status, restartPolicy: _bounded());

      monitor.arm(
        const ManagedRuntimeHandle<_TestRecord>(
          port: 50100,
          record: null,
          process: null,
          identity: null,
          health: RuntimeHealthProbe(healthy: true),
        ),
      );
      await pumpEventQueue();

      expect(monitor.currentHandle, isNotNull);
      expect(fakes.spawn.spawnedPorts, isEmpty);
      expect(tags, equals(<String>["ready"]));
    });

    test("a disabled restart policy fails terminally on an unexpected exit", () async {
      final status = PluginStatusController(initial: const PluginReady());
      final tags = _collect(status);
      final monitor = fakes.monitor(status: status, restartPolicy: const RuntimeRestartPolicy.disabled());
      final child = _child(pid: 101);

      monitor.arm(_handle(port: 4096, process: child));
      child.completeExit(1);
      await pumpEventQueue();

      expect(tags, equals(<String>["ready", "failed"]));
      expect(fakes.spawn.spawnedPorts, isEmpty);
    });

    test("an unexpected exit restarts on the pinned port and returns to ready", () async {
      final status = PluginStatusController(initial: const PluginReady());
      final tags = _collect(status);
      final monitor = fakes.monitor(status: status, restartPolicy: _bounded());
      final child = _child(pid: 101);
      final restarted = _child(pid: 102);

      fakes.bindable.byPort[4096] = true;
      fakes.spawn.results.add(restarted);
      fakes.probe.results.add(const RuntimeHealthProbe(healthy: true));

      monitor.arm(_handle(port: 4096, process: child));
      child.completeExit(1);
      await pumpEventQueue();

      expect(tags, equals(<String>["ready", "restarting(1)", "ready"]));
      // Pinned: the restart spawned on the same port it started on.
      expect(fakes.spawn.spawnedPorts, equals(<int>[4096]));
      expect(monitor.currentHandle!.process, same(restarted));
      expect(fakes.ownership.records.values.single.status, equals(_TestStatus.ready));
    });

    test("a restarted child that exits again starts a fresh episode at attempt 1", () async {
      final status = PluginStatusController(initial: const PluginReady());
      final tags = _collect(status);
      final monitor = fakes.monitor(status: status, restartPolicy: _bounded());
      final child = _child(pid: 101);
      final restarted = _child(pid: 102);
      final restartedAgain = _child(pid: 103);

      fakes.bindable.byPort[4096] = true;
      fakes.spawn.results.addAll(<SpawnedProcess>[restarted, restartedAgain]);
      fakes.probe.results.addAll(<RuntimeHealthProbe>[
        const RuntimeHealthProbe(healthy: true),
        const RuntimeHealthProbe(healthy: true),
      ]);

      monitor.arm(_handle(port: 4096, process: child));
      child.completeExit(1);
      await pumpEventQueue();
      restarted.completeExit(1);
      await pumpEventQueue();

      expect(tags, equals(<String>["ready", "restarting(1)", "ready", "restarting(1)", "ready"]));
      expect(monitor.currentHandle!.process, same(restartedAgain));
    });

    test("exhausting the restart attempts fails terminally", () async {
      final status = PluginStatusController(initial: const PluginReady());
      final tags = _collect(status);
      final monitor = fakes.monitor(status: status, restartPolicy: _bounded(maxAttempts: 2));
      final child = _child(pid: 101);

      fakes.bindable.byPort[4096] = true;
      // Both restart attempts fail to spawn.
      fakes.spawn.results.addAll(<Object>[
        const ProcessException("opencode", <String>["serve"]),
        const ProcessException("opencode", <String>["serve"]),
      ]);

      monitor.arm(_handle(port: 4096, process: child));
      child.completeExit(1);
      await pumpEventQueue();

      expect(tags, equals(<String>["ready", "restarting(1)", "restarting(2)", "failed"]));
      expect(fakes.spawn.spawnedPorts, equals(<int>[4096, 4096]));
    });

    test("a port that never frees fails the restart", () async {
      final status = PluginStatusController(initial: const PluginReady());
      final tags = _collect(status);
      final monitor = fakes.monitor(status: status, restartPolicy: _bounded(maxAttempts: 1));
      final child = _child(pid: 101);

      // The address-frozen port is held by the dying child and never frees.
      fakes.bindable.byPort[4096] = false;

      monitor.arm(_handle(port: 4096, process: child));
      child.completeExit(1);
      await pumpEventQueue();

      expect(tags, equals(<String>["ready", "restarting(1)", "failed"]));
      // It never got far enough to spawn — the address was never reclaimable.
      expect(fakes.spawn.spawnedPorts, isEmpty);
    });

    test("the port-release wait terminates on its maxPolls backstop under a stuck clock", () async {
      final clock = _StuckServerClock();
      final stuckFakes = _Fakes(clock: clock);
      final status = PluginStatusController(initial: const PluginReady());
      final tags = _collect(status);
      final monitor = stuckFakes.monitor(status: status, restartPolicy: _bounded(maxAttempts: 1));
      final child = _child(pid: 101);

      // The port never frees AND the clock never advances, so the deadline can
      // never be reached: only the maxPolls backstop can terminate the wait.
      stuckFakes.bindable.byPort[4096] = false;

      monitor.arm(_handle(port: 4096, process: child));
      child.completeExit(1);
      await pumpEventQueue();

      expect(tags, equals(<String>["ready", "restarting(1)", "failed"]));
      expect(stuckFakes.spawn.spawnedPorts, isEmpty);
      // It actually polled (and was bounded) rather than hanging or bailing early.
      expect(clock.delays, greaterThan(0));
    });

    test("a restart stands down when the status machine has already moved to a terminal state", () async {
      final status = PluginStatusController(initial: const PluginReady());
      final tags = _collect(status);
      final monitor = fakes.monitor(status: status, restartPolicy: _bounded());
      final child = _child(pid: 101);

      monitor.arm(_handle(port: 4096, process: child));
      // The owner moved the plugin to Stopping without disarming the monitor:
      // the rejected PluginRestarting transition must stop the episode.
      status.set(const PluginStopping());
      child.completeExit(1);
      await pumpEventQueue();

      expect(fakes.spawn.spawnedPorts, isEmpty);
      expect(tags, isNot(contains("restarting(1)")));
      expect(tags, isNot(contains("failed")));
    });

    test("disarming before the exit suppresses any restart or failure", () async {
      final status = PluginStatusController(initial: const PluginReady());
      final tags = _collect(status);
      final monitor = fakes.monitor(status: status, restartPolicy: _bounded());
      final child = _child(pid: 101);

      monitor.arm(_handle(port: 4096, process: child));
      await monitor.disarm();
      child.completeExit(137);
      await pumpEventQueue();

      // A deliberate shutdown is never mistaken for a crash.
      expect(tags, equals(<String>["ready"]));
      expect(fakes.spawn.spawnedPorts, isEmpty);
    });

    test("disarming during an in-flight restart stops the new child instead of failing", () async {
      final status = PluginStatusController(initial: const PluginReady());
      final tags = _collect(status);
      final monitor = fakes.monitor(status: status, restartPolicy: _bounded());
      final child = _child(pid: 101);
      final restarted = _child(pid: 102);

      fakes.bindable.byPort[4096] = true;
      fakes.spawn.results.add(restarted);
      // The restart spawn blocks until the test releases the gate.
      final gate = Completer<void>();
      final reached = Completer<void>();
      fakes.spawn.gate = gate;
      fakes.spawn.reached = reached;
      fakes.probe.results.add(const RuntimeHealthProbe(healthy: true));
      fakes.processes.forceHooks[102] = restarted.completeExit;

      monitor.arm(_handle(port: 4096, process: child));
      child.completeExit(1);
      await reached.future; // the restart has reached the (blocked) spawn
      final disarm = monitor.disarm(); // disarm mid-restart -> aborts the in-flight start
      var disarmSettled = false;
      unawaited(disarm.whenComplete(() => disarmSettled = true));
      await pumpEventQueue();
      expect(
        disarmSettled,
        isFalse,
        reason: "disarm must wait the in-flight restart episode out, or the owner's "
            "shutdown reads a stale handle while the respawn is still in flight",
      );
      gate.complete();
      await disarm;

      // By the time disarm returns the rollback has already happened: the
      // aborted restart stopped its freshly spawned child (the post-spawn
      // abort checkpoint) and wrote no record — the owner's shutdown can
      // never race the respawn.
      expect(tags, isNot(contains("failed")));
      expect(fakes.processes.signalRequests, equals(<String>["graceful:102", "force:102"]));
      expect(fakes.ownership.records, isEmpty);
    });

    test("a disarm racing the committing restart still adopts the live child", () async {
      final status = PluginStatusController(initial: const PluginReady());
      final tags = _collect(status);
      final monitor = fakes.monitor(status: status, restartPolicy: _bounded());
      final child = _child(pid: 101);
      final restarted = _child(pid: 102);

      fakes.bindable.byPort[4096] = true;
      fakes.spawn.results.add(restarted);
      fakes.probe.results.add(const RuntimeHealthProbe(healthy: true));
      // Block the final "ready" ownership write so a disarm can land in the
      // window after the restart commits but before it is announced.
      final gate = Completer<void>();
      final reached = Completer<void>();
      fakes.ownership.readyUpsertGate = gate;
      fakes.ownership.readyUpsertReached = reached;

      monitor.arm(_handle(port: 4096, process: child));
      child.completeExit(1);
      await reached.future; // the restart has passed health and is committing
      final disarm = monitor.disarm(); // disarm races the commit (after the last abort checkpoint)
      var disarmSettled = false;
      unawaited(disarm.whenComplete(() => disarmSettled = true));
      await pumpEventQueue();
      expect(disarmSettled, isFalse, reason: "disarm must wait for the committing restart to settle");
      gate.complete();
      await disarm;

      // By the time disarm returns the committed child has already been
      // adopted, so the owner stops the *live* child, not the dead one — and
      // no terminal failure surfaced.
      expect(monitor.currentHandle!.process, same(restarted));
      expect(tags, isNot(contains("failed")));
    });

    test("a disarm during the restart backoff settles without waiting the backoff out", () async {
      final clock = _NeverElapsingServerClock();
      final parkedFakes = _Fakes(clock: clock);
      final status = PluginStatusController(initial: const PluginReady());
      final monitor = parkedFakes.monitor(status: status, restartPolicy: _bounded());
      final child = _child(pid: 101);

      monitor.arm(_handle(port: 4096, process: child));
      child.completeExit(1);
      await pumpEventQueue(); // the episode is parked in its backoff sleep
      expect(clock.pendingDelays, equals(1));

      // The backoff sleep races the abort signal: disarm settles promptly even
      // though the backoff delay itself never completes, instead of stalling
      // the owner's shutdown for up to maxBackoff.
      await monitor.disarm().timeout(const Duration(seconds: 5));

      expect(parkedFakes.spawn.spawnedPorts, isEmpty);
    });

    test("consumes the child's stderr so a full pipe cannot block it", () async {
      final status = PluginStatusController(initial: const PluginReady());
      final monitor = fakes.monitor(status: status, restartPolicy: const RuntimeRestartPolicy.disabled());
      final stderr = StreamController<List<int>>();
      final child = _child(pid: 101, stderr: stderr.stream);

      monitor.arm(_handle(port: 4096, process: child));
      await pumpEventQueue();

      expect(stderr.hasListener, isTrue);
      stderr.add(utf8.encode("opencode: warming up\n"));
      await pumpEventQueue();
      await stderr.close();
    });
  });
}

String _tag(PluginStatus status) {
  return switch (status) {
    PluginStarting() => "starting",
    PluginReady() => "ready",
    PluginDegraded() => "degraded",
    PluginRestarting(:final attempt) => "restarting($attempt)",
    PluginFailed() => "failed",
    PluginStopping() => "stopping",
    PluginStopped() => "stopped",
  };
}

List<String> _collect(PluginStatusController controller) {
  final tags = <String>[];
  controller.stream.listen((status) => tags.add(_tag(status)));
  return tags;
}

RuntimeRestartPolicy _bounded({int maxAttempts = 3}) {
  return RuntimeRestartPolicy.bounded(
    maxAttempts: maxAttempts,
    initialBackoff: const Duration(milliseconds: 100),
    maxBackoff: const Duration(seconds: 1),
    portReleaseTimeout: const Duration(seconds: 2),
    portReleasePollInterval: const Duration(milliseconds: 250),
  );
}

ManagedRuntimeHandle<_TestRecord> _handle({required int port, required SpawnedProcess process}) {
  return ManagedRuntimeHandle<_TestRecord>(
    port: port,
    record: _record(pid: process.pid, port: port),
    process: process,
    identity: process.identity,
    health: const RuntimeHealthProbe(healthy: true),
  );
}

_MonitorSpawnedProcess _child({
  required int pid,
  bool exitImmediately = false,
  Stream<List<int>>? stderr,
}) {
  return _MonitorSpawnedProcess(
    identity: _identity(pid: pid),
    exitImmediately: exitImmediately,
    stderr: stderr,
  );
}

ProcessIdentity _identity({required int pid}) {
  return ProcessIdentity(
    pid: pid,
    startMarker: "open-start-$pid",
    executablePath: "/usr/local/bin/opencode",
    commandLine: "/usr/local/bin/opencode serve --port 4096 --hostname 127.0.0.1",
    ownerUser: ProcessUser.fromRawUser("alex"),
    platform: "macos",
    capturedAt: DateTime.utc(2026, 5, 15, 12),
  );
}

_TestRecord _record({required int pid, required int port}) {
  return _TestRecord(
    ownerSessionId: "current-owner",
    openCodePid: pid,
    openCodeStartMarker: "open-start-$pid",
    openCodeExecutablePath: "/usr/local/bin/opencode",
    commandLine: "/usr/local/bin/opencode serve --port $port --hostname 127.0.0.1",
    port: port,
    bridgePid: 900,
    bridgeStartMarker: "bridge-start",
    status: _TestStatus.starting,
  );
}

class _Fakes {
  _Fakes({ServerClock? clock}) : clock = clock ?? _AdvancingServerClock();

  final _FakeOwnershipRepository ownership = _FakeOwnershipRepository();
  final _FakeHostProcessService processes = _FakeHostProcessService();
  final _FakeBridgeHostInfo bridge = _FakeBridgeHostInfo();
  final ServerClock clock;
  final _SpawnPlan spawn = _SpawnPlan();
  final _ProbePlan probe = _ProbePlan();
  final _BindablePlan bindable = _BindablePlan();

  ManagedProcessService<_TestRecord> service() {
    return ManagedProcessService<_TestRecord>(
      ownershipRepository: ownership,
      mapper: const _TestRecordMapper(),
      processes: processes,
      bridge: bridge,
      clock: clock,
      runtimeId: "OPENCODE",
      gracefulShutdownWait: _gracefulShutdownWait,
    );
  }

  ManagedRuntimeSpec<_TestRecord> spec() {
    return ManagedRuntimeSpec<_TestRecord>(
      spawn: spawn.spawn,
      probeHealth: probe.probe,
      probePortBindable: bindable.bindable,
      buildRecord: (draft) => _record(pid: draft.runtimeIdentity.pid, port: draft.port),
      portPolicy: const ExplicitPortPolicy(port: 4096),
      healthPolicy: _legacyHealthPolicy,
    );
  }

  ManagedRuntimeMonitor<_TestRecord> monitor({
    required PluginStatusController status,
    required RuntimeRestartPolicy restartPolicy,
  }) {
    return ManagedRuntimeMonitor<_TestRecord>(
      service: service(),
      spec: spec(),
      status: status,
      clock: clock,
      runtimeId: "OPENCODE",
      restartPolicy: restartPolicy,
    );
  }
}

class _SpawnPlan {
  final List<Object> results = <Object>[];
  final List<int> spawnedPorts = <int>[];
  Completer<void>? gate;
  Completer<void>? reached;

  Future<SpawnedProcess> spawn({required int port}) async {
    spawnedPorts.add(port);
    reached?.complete();
    reached = null;
    final gate = this.gate;
    if (gate != null) {
      this.gate = null;
      await gate.future;
    }
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

class _BindablePlan {
  final Map<int, bool> byPort = <int, bool>{};

  Future<bool> bindable({required int port}) async {
    return byPort[port] ?? false;
  }
}

enum _TestStatus { starting, ready, stopping }

class _TestRecord {
  const _TestRecord({
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
  final _TestStatus status;

  _TestRecord withStatus(_TestStatus status) {
    return _TestRecord(
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

class _TestRecordMapper implements RuntimeRecordMapper<_TestRecord> {
  const _TestRecordMapper();

  @override
  Map<String, dynamic> toJson({required _TestRecord record}) => throw UnimplementedError();

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
  String runtimeCommandLineOf({required _TestRecord record}) => record.commandLine;

  @override
  int bridgePidOf({required _TestRecord record}) => record.bridgePid;

  @override
  String? bridgeStartMarkerOf({required _TestRecord record}) => record.bridgeStartMarker;

  @override
  _TestRecord markReady({required _TestRecord record}) => record.withStatus(_TestStatus.ready);

  @override
  _TestRecord markStopping({required _TestRecord record}) => record.withStatus(_TestStatus.stopping);
}

class _FakeOwnershipRepository implements RuntimeOwnershipRepository<_TestRecord> {
  final Map<String, _TestRecord> records = <String, _TestRecord>{};
  Completer<void>? readyUpsertGate;
  Completer<void>? readyUpsertReached;

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
    if (record.status == _TestStatus.ready && readyUpsertGate != null) {
      readyUpsertReached?.complete();
      readyUpsertReached = null;
      final gate = readyUpsertGate!;
      readyUpsertGate = null;
      await gate.future;
    }
    records[record.ownerSessionId] = record;
  }
}

class _FakeHostProcessService implements HostProcessService {
  final Map<int, List<ProcessIdentity?>> inspectResults = <int, List<ProcessIdentity?>>{};
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

class _AdvancingServerClock implements ServerClock {
  DateTime _now = DateTime.utc(2026, 5, 15, 12);

  @override
  Future<void> delay({required Duration duration}) async {
    _now = _now.add(duration);
  }

  @override
  DateTime now() => _now;
}

/// A clock whose `now()` never moves, even across `delay()` calls — used to
/// prove the port-release wait terminates on its `maxPolls` backstop rather
/// than the (never-reached) deadline.
class _StuckServerClock implements ServerClock {
  int delays = 0;

  @override
  Future<void> delay({required Duration duration}) async {
    delays += 1;
  }

  @override
  DateTime now() => DateTime.utc(2026, 5, 15, 12, 30);
}

/// A clock whose `delay()` never completes — used to prove a disarm during the
/// restart backoff settles via the abort race instead of waiting the sleep out.
class _NeverElapsingServerClock implements ServerClock {
  int pendingDelays = 0;

  @override
  Future<void> delay({required Duration duration}) {
    pendingDelays += 1;
    return Completer<void>().future;
  }

  @override
  DateTime now() => DateTime.utc(2026, 5, 15, 12, 30);
}

class _MonitorSpawnedProcess implements SpawnedProcess {
  _MonitorSpawnedProcess({
    required ProcessIdentity identity,
    required bool exitImmediately,
    Stream<List<int>>? stderr,
  }) : _identity = identity,
       _stderr = stderr ?? const Stream<List<int>>.empty() {
    if (exitImmediately) {
      _exitCodeCompleter.complete(0);
    }
  }

  final ProcessIdentity _identity;
  final Stream<List<int>> _stderr;
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
  Stream<List<int>> get stderr => _stderr;

  @override
  Stream<List<int>> get stdout => const Stream<List<int>>.empty();

  void completeExit([int code = 0]) {
    if (!_exitCodeCompleter.isCompleted) {
      _exitCodeCompleter.complete(code);
    }
  }
}
