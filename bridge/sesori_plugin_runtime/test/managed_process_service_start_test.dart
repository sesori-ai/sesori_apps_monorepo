import "dart:async";
import "dart:convert";
import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

const _gracefulShutdownWait = Duration(seconds: 5);
const _legacyHealthPolicy = RuntimeHealthPolicy.attemptCount(
  attempts: 5,
  delay: Duration(milliseconds: 500),
);

void main() {
  group("ManagedProcessService.start (dynamic port)", () {
    late _Fakes fakes;

    setUp(() {
      fakes = _Fakes();
    });

    test("retries dynamic candidates after a start race and skips the reserved port", () async {
      fakes.bindable.byPort.addAll(<int, bool>{49152: true, 49153: true});
      fakes.spawn.results.addAll(<Object>[
        StateError("bind race"),
        _spawned(pid: 101, port: 49153),
      ]);
      fakes.probe.results.add(const RuntimeHealthProbe(healthy: true));

      final handle = await fakes.service().start(
        spec: fakes.spec(portPolicy: _dynamic(<int>[4096, 49152, 49153])),
        terminatedBridgeIdentities: const <ProcessIdentity>[],
      );

      expect(handle.port, equals(49153));
      expect(handle.isOwned, isTrue);
      expect(fakes.bindable.probedPorts, equals(<int>[49152, 49153]));
      expect(fakes.spawn.spawnedPorts, equals(<int>[49152, 49153]));
      expect(fakes.ownership.records.values.single.status, equals(_TestStatus.ready));
      expect(fakes.ownership.records.values.single.port, equals(49153));
    });

    test("retries the health probe and succeeds on a later attempt", () async {
      fakes.bindable.byPort[49152] = true;
      fakes.spawn.results.add(_spawned(pid: 101, port: 49152));
      fakes.probe.results.addAll(<RuntimeHealthProbe>[
        const RuntimeHealthProbe(healthy: false, error: "not ready"),
        const RuntimeHealthProbe(healthy: false, error: "not ready"),
        const RuntimeHealthProbe(healthy: true),
      ]);

      final handle = await fakes.service().start(
        spec: fakes.spec(portPolicy: _dynamic(<int>[49152])),
        terminatedBridgeIdentities: const <ProcessIdentity>[],
      );

      expect(handle.port, equals(49152));
      expect(fakes.probe.probedPorts, equals(<int>[49152, 49152, 49152]));
      expect(
        fakes.clock.delays,
        equals(<Duration>[
          const Duration(milliseconds: 500),
          const Duration(milliseconds: 500),
          const Duration(milliseconds: 500),
        ]),
      );
      expect(fakes.ownership.upsertedStatuses.last, equals(_TestStatus.ready));
    });

    test("exhausts all health retries on one port and moves to the next", () async {
      fakes.bindable.byPort.addAll(<int, bool>{49152: true, 49153: true});
      fakes.spawn.results.addAll(<Object>[
        _spawned(pid: 101, port: 49152),
        _spawned(pid: 102, port: 49153),
      ]);
      fakes.probe.results.addAll(<RuntimeHealthProbe>[
        for (var i = 0; i < 5; i += 1) const RuntimeHealthProbe(healthy: false, error: "not ready"),
        const RuntimeHealthProbe(healthy: true),
      ]);
      // The first port's failed-start cleanup finds the child already gone.
      fakes.processes.inspectResults[101] = <ProcessIdentity?>[null];

      final handle = await fakes.service().start(
        spec: fakes.spec(portPolicy: _dynamic(<int>[49152, 49153])),
        terminatedBridgeIdentities: const <ProcessIdentity>[],
      );

      expect(handle.port, equals(49153));
      expect(fakes.spawn.spawnedPorts, equals(<int>[49152, 49153]));
      expect(
        fakes.probe.probedPorts,
        equals(<int>[49152, 49152, 49152, 49152, 49152, 49153]),
      );
      expect(
        fakes.clock.delays,
        equals(<Duration>[for (var i = 0; i < 6; i += 1) const Duration(milliseconds: 500)]),
      );
      expect(fakes.ownership.records.values.single.status, equals(_TestStatus.ready));
      expect(fakes.ownership.records.values.single.port, equals(49153));
    });

    test("stops dynamic discovery after the configured candidate cap", () async {
      for (var port = 49152; port < 49162; port += 1) {
        fakes.bindable.byPort[port] = false;
      }

      await expectLater(
        fakes.service().start(
          spec: fakes.spec(
            portPolicy: _dynamic(List<int>.generate(10, (index) => 49152 + index)),
          ),
          terminatedBridgeIdentities: const <ProcessIdentity>[],
        ),
        throwsA(isA<PluginStartException>()),
      );

      expect(fakes.bindable.probedPorts, hasLength(5));
      expect(fakes.spawn.spawnedPorts, isEmpty);
      expect(fakes.processes.signalRequests, isEmpty);
    });

    test("caps an unbounded source that only ever yields the reserved port", () async {
      // A lazy candidate generator that never yields an in-range port must
      // still terminate at maxAttempts — the cap counts raw candidates.
      await expectLater(
        fakes.service().start(
          spec: fakes.spec(
            portPolicy: RuntimePortPolicy.dynamic(
              candidates: _endless(4096),
              maxAttempts: 5,
              reservedPort: 4096,
              minPort: 49152,
              maxPort: 65535,
            ),
          ),
          terminatedBridgeIdentities: const <ProcessIdentity>[],
        ),
        throwsA(isA<PluginStartException>()),
      );

      expect(fakes.bindable.probedPorts, isEmpty);
      expect(fakes.spawn.spawnedPorts, isEmpty);
    });

    test("fail-fast policy stops on a spawn error instead of retrying", () async {
      fakes.bindable.byPort.addAll(<int, bool>{49152: true, 49153: true});
      fakes.spawn.results.add(const ProcessException("opencode", <String>["serve"]));

      await expectLater(
        fakes.service().start(
          spec: fakes.spec(
            portPolicy: _dynamic(<int>[49152, 49153], failFastOnSpawnError: true),
          ),
          terminatedBridgeIdentities: const <ProcessIdentity>[],
        ),
        throwsA(isA<ProcessException>()),
      );

      expect(fakes.spawn.spawnedPorts, equals(<int>[49152]));
      expect(fakes.ownership.records, isEmpty);
    });
  });

  group("ManagedProcessService.start (explicit port)", () {
    late _Fakes fakes;

    setUp(() {
      fakes = _Fakes();
    });

    test("bypasses discovery but still retries health on the single port", () async {
      fakes.spawn.results.add(_spawned(pid: 201, port: 4096));
      fakes.probe.results.addAll(<RuntimeHealthProbe>[
        for (var i = 0; i < 5; i += 1) const RuntimeHealthProbe(healthy: false, error: "not ready"),
      ]);
      fakes.processes.inspectResults[201] = <ProcessIdentity?>[
        _runtimeIdentity(pid: 201, port: 4096),
        null,
        null,
      ];

      await expectLater(
        fakes.service().start(
          spec: fakes.spec(portPolicy: const ExplicitPortPolicy(port: 4096)),
          terminatedBridgeIdentities: const <ProcessIdentity>[],
        ),
        throwsA(isA<PluginStartException>()),
      );

      expect(fakes.bindable.probedPorts, isEmpty);
      expect(fakes.spawn.spawnedPorts, equals(<int>[4096]));
      expect(fakes.probe.probedPorts, equals(<int>[4096, 4096, 4096, 4096, 4096]));
      expect(fakes.processes.signalRequests, equals(<String>["graceful:201"]));
      expect(fakes.ownership.records, isEmpty);
    });

    test("propagates a raw spawn error without writing or signaling", () async {
      fakes.spawn.results.add(StateError("bind failed"));

      await expectLater(
        fakes.service().start(
          spec: fakes.spec(portPolicy: const ExplicitPortPolicy(port: 50128)),
          terminatedBridgeIdentities: const <ProcessIdentity>[],
        ),
        throwsA(isA<StateError>()),
      );

      expect(fakes.bindable.probedPorts, isEmpty);
      expect(fakes.spawn.spawnedPorts, equals(<int>[50128]));
      expect(fakes.probe.probedPorts, isEmpty);
      expect(fakes.processes.signalRequests, isEmpty);
      expect(fakes.ownership.writeCallCount, equals(0));
      expect(fakes.ownership.deleteCallCount, equals(0));
      expect(fakes.ownership.records, isEmpty);
    });

    test("records starting then ready in order", () async {
      fakes.spawn.results.add(_spawned(pid: 301, port: 50123));
      fakes.probe.results.add(const RuntimeHealthProbe(healthy: true, version: "1.2.3"));

      final handle = await fakes.service().start(
        spec: fakes.spec(portPolicy: const ExplicitPortPolicy(port: 50123)),
        terminatedBridgeIdentities: const <ProcessIdentity>[],
      );

      expect(
        fakes.ownership.upsertedStatuses,
        equals(<_TestStatus>[_TestStatus.starting, _TestStatus.ready]),
      );
      expect(fakes.ownership.records.values.single.openCodePid, equals(301));
      expect(handle.health.version, equals("1.2.3"));
      expect(handle.identity!.pid, equals(301));
    });

    test("failed-start cleanup force-stops a surviving markerless child via host signals", () async {
      final spawned = _spawned(pid: 212, port: 50130, startMarker: null, exitImmediately: false);
      fakes.spawn.results.add(spawned);
      fakes.probe.results.addAll(<RuntimeHealthProbe>[
        for (var i = 0; i < 5; i += 1) const RuntimeHealthProbe(healthy: false, error: "not ready"),
      ]);
      fakes.processes.inspectResults[212] = <ProcessIdentity?>[null, null, null];
      fakes.processes.forceHooks[212] = spawned.completeExit;

      await expectLater(
        fakes.service().start(
          spec: fakes.spec(portPolicy: const ExplicitPortPolicy(port: 50130)),
          terminatedBridgeIdentities: const <ProcessIdentity>[],
        ),
        throwsA(isA<PluginStartException>()),
      );

      expect(fakes.processes.signalRequests, equals(<String>["graceful:212", "force:212"]));
      expect(fakes.ownership.records, isEmpty);
      expect(
        fakes.clock.delays,
        equals(<Duration>[
          for (var i = 0; i < 5; i += 1) const Duration(milliseconds: 500),
          _gracefulShutdownWait,
        ]),
      );
    });

    test("a cleanup failure does not mask the original start failure", () async {
      fakes.spawn.results.add(_spawned(pid: 220, port: 50133, exitImmediately: true));
      fakes.probe.results.addAll(<RuntimeHealthProbe>[
        for (var i = 0; i < 5; i += 1) const RuntimeHealthProbe(healthy: false, error: "not ready"),
      ]);
      fakes.processes.inspectResults[220] = <ProcessIdentity?>[null];
      // The record delete during rollback fails; the health-check failure that
      // triggered the rollback must still be what surfaces.
      fakes.ownership.deleteError = StateError("ownership store offline");

      await expectLater(
        fakes.service().start(
          spec: fakes.spec(portPolicy: const ExplicitPortPolicy(port: 50133)),
          terminatedBridgeIdentities: const <ProcessIdentity>[],
        ),
        throwsA(isA<PluginStartException>()),
      );
    });

    test("optional pre-probe rejects an unbindable explicit port without spawning", () async {
      fakes.bindable.byPort[4096] = false;

      await expectLater(
        fakes.service().start(
          spec: fakes.spec(
            portPolicy: const ExplicitPortPolicy(port: 4096, preProbeBindable: true),
          ),
          terminatedBridgeIdentities: const <ProcessIdentity>[],
        ),
        throwsA(isA<PluginStartException>()),
      );

      expect(fakes.bindable.probedPorts, equals(<int>[4096]));
      expect(fakes.spawn.spawnedPorts, isEmpty);
      expect(fakes.ownership.records, isEmpty);
    });

    test("optional pre-probe proceeds when the explicit port is bindable", () async {
      fakes.bindable.byPort[4096] = true;
      fakes.spawn.results.add(_spawned(pid: 501, port: 4096));
      fakes.probe.results.add(const RuntimeHealthProbe(healthy: true));

      final handle = await fakes.service().start(
        spec: fakes.spec(
          portPolicy: const ExplicitPortPolicy(port: 4096, preProbeBindable: true),
        ),
        terminatedBridgeIdentities: const <ProcessIdentity>[],
      );

      expect(fakes.bindable.probedPorts, equals(<int>[4096]));
      expect(handle.port, equals(4096));
      expect(fakes.ownership.records.values.single.status, equals(_TestStatus.ready));
    });
  });

  group("ManagedProcessService.start (squatter defense & validation)", () {
    late _Fakes fakes;

    setUp(() {
      fakes = _Fakes();
    });

    test("treats a child exit before the first healthy probe as authoritative failure", () async {
      // Child exits immediately; the probe would report healthy, but it can
      // only be an unrelated process holding the port.
      fakes.spawn.results.add(_spawned(pid: 601, port: 50140, exitImmediately: true));
      fakes.probe.results.add(const RuntimeHealthProbe(healthy: true));
      fakes.processes.inspectResults[601] = <ProcessIdentity?>[null];

      await expectLater(
        fakes.service().start(
          spec: fakes.spec(
            portPolicy: const ExplicitPortPolicy(port: 50140),
            failOnEarlyChildExit: true,
          ),
          terminatedBridgeIdentities: const <ProcessIdentity>[],
        ),
        throwsA(isA<PluginStartException>()),
      );

      expect(fakes.probe.probedPorts, isEmpty);
      expect(fakes.ownership.records, isEmpty);
    });

    test("a failing validateRuntime rolls back the start", () async {
      fakes.spawn.results.add(_spawned(pid: 701, port: 50141));
      fakes.probe.results.add(const RuntimeHealthProbe(healthy: true));
      fakes.processes.inspectResults[701] = <ProcessIdentity?>[null];

      await expectLater(
        fakes.service().start(
          spec: fakes.spec(
            portPolicy: const ExplicitPortPolicy(port: 50141),
            validateRuntime: ({required int port}) => Future<void>.error(StateError("bad version")),
          ),
          terminatedBridgeIdentities: const <ProcessIdentity>[],
        ),
        throwsA(isA<PluginStartException>()),
      );

      expect(fakes.ownership.records, isEmpty);
      expect(fakes.ownership.upsertedStatuses, equals(<_TestStatus>[_TestStatus.starting]));
    });

    test("rejects the not-yet-available intent side-file record timing", () async {
      fakes.spawn.results.add(_spawned(pid: 801, port: 50142));

      await expectLater(
        fakes.service().start(
          spec: fakes.spec(
            portPolicy: const ExplicitPortPolicy(port: 50142),
            recordTiming: RuntimeRecordTiming.intentSideFile,
          ),
          terminatedBridgeIdentities: const <ProcessIdentity>[],
        ),
        throwsA(isA<UnsupportedError>()),
      );

      expect(fakes.spawn.spawnedPorts, isEmpty);
      expect(fakes.ownership.records, isEmpty);
    });

    test("rejects intent side-file timing once, never retrying across dynamic candidates", () async {
      fakes.bindable.byPort.addAll(<int, bool>{49152: true, 49153: true});

      await expectLater(
        fakes.service().start(
          spec: fakes.spec(
            portPolicy: _dynamic(<int>[49152, 49153]),
            recordTiming: RuntimeRecordTiming.intentSideFile,
          ),
          terminatedBridgeIdentities: const <ProcessIdentity>[],
        ),
        throwsA(isA<UnsupportedError>()),
      );

      // Rejected before the candidate loop: nothing probed or spawned.
      expect(fakes.bindable.probedPorts, isEmpty);
      expect(fakes.spawn.spawnedPorts, isEmpty);
    });

    test("stops the spawned child when the record factory throws", () async {
      final spawned = _spawned(pid: 230, port: 50143, exitImmediately: false);
      fakes.spawn.results.add(spawned);
      fakes.processes.forceHooks[230] = spawned.completeExit;

      await expectLater(
        fakes.service().start(
          spec: fakes.spec(
            portPolicy: const ExplicitPortPolicy(port: 50143),
            buildRecord: (draft) => throw StateError("malformed record"),
          ),
          terminatedBridgeIdentities: const <ProcessIdentity>[],
        ),
        throwsA(isA<StateError>()),
      );

      // The orphaned child is stopped via host signals; no record is ever written.
      expect(fakes.spawn.spawnedPorts, equals(<int>[50143]));
      expect(fakes.processes.signalRequests, equals(<String>["graceful:230", "force:230"]));
      expect(fakes.ownership.writeCallCount, equals(0));
      expect(fakes.ownership.records, isEmpty);
    });
  });

  group("ManagedProcessService.start (deadline health policy)", () {
    late _Fakes fakes;

    setUp(() {
      fakes = _Fakes(clock: _AdvancingServerClock());
    });

    test("polls until healthy before the deadline", () async {
      fakes.spawn.results.add(_spawned(pid: 901, port: 50150));
      fakes.probe.results.addAll(<RuntimeHealthProbe>[
        const RuntimeHealthProbe(healthy: false, error: "warming up"),
        const RuntimeHealthProbe(healthy: true),
      ]);

      final handle = await fakes.service().start(
        spec: fakes.spec(
          portPolicy: const ExplicitPortPolicy(port: 50150),
          healthPolicy: RuntimeHealthPolicy.deadline(
            deadline: const Duration(seconds:5),
            pollInterval: const Duration(seconds: 1),
          ),
        ),
        terminatedBridgeIdentities: const <ProcessIdentity>[],
      );

      expect(handle.port, equals(50150));
      expect(fakes.probe.probedPorts, equals(<int>[50150, 50150]));
      expect(fakes.ownership.records.values.single.status, equals(_TestStatus.ready));
    });

    test("fails once the deadline elapses", () async {
      fakes.spawn.results.add(_spawned(pid: 902, port: 50151));
      fakes.probe.results.addAll(<RuntimeHealthProbe>[
        const RuntimeHealthProbe(healthy: false, error: "still down"),
        const RuntimeHealthProbe(healthy: false, error: "still down"),
      ]);
      fakes.processes.inspectResults[902] = <ProcessIdentity?>[null];

      await expectLater(
        fakes.service().start(
          spec: fakes.spec(
            portPolicy: const ExplicitPortPolicy(port: 50151),
            healthPolicy: RuntimeHealthPolicy.deadline(
              deadline: const Duration(seconds:2),
              pollInterval: const Duration(seconds: 1),
            ),
          ),
          terminatedBridgeIdentities: const <ProcessIdentity>[],
        ),
        throwsA(isA<PluginStartException>()),
      );

      expect(fakes.probe.probedPorts, equals(<int>[50151, 50151]));
      expect(fakes.ownership.records, isEmpty);
    });

    test("rejects a non-positive poll interval or negative deadline", () {
      expect(
        () => RuntimeHealthPolicy.deadline(deadline: const Duration(seconds: 5), pollInterval: Duration.zero),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => RuntimeHealthPolicy.deadline(
          deadline: const Duration(seconds: -1),
          pollInterval: const Duration(seconds: 1),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group("ManagedProcessService.start (cooperative abort)", () {
    late _Fakes fakes;

    setUp(() {
      fakes = _Fakes();
    });

    test("aborting before port selection throws without spawning", () async {
      final controller = StartAbortController()..abort();

      await expectLater(
        fakes.service().start(
          spec: fakes.spec(portPolicy: _dynamic(<int>[49152])),
          terminatedBridgeIdentities: const <ProcessIdentity>[],
          startAborted: controller.signal,
        ),
        throwsA(isA<PluginStartAbortedException>()),
      );

      expect(fakes.spawn.spawnedPorts, isEmpty);
      expect(fakes.bindable.probedPorts, isEmpty);
    });

    test("aborting after spawn rolls back the record and child", () async {
      final controller = StartAbortController();
      final spawned = _spawned(pid: 401, port: 50160, exitImmediately: true);
      fakes.spawn.results.add(spawned);
      fakes.spawn.onSpawn = controller.abort;
      fakes.processes.inspectResults[401] = <ProcessIdentity?>[null];

      await expectLater(
        fakes.service().start(
          spec: fakes.spec(portPolicy: const ExplicitPortPolicy(port: 50160)),
          terminatedBridgeIdentities: const <ProcessIdentity>[],
          startAborted: controller.signal,
        ),
        throwsA(isA<PluginStartAbortedException>()),
      );

      expect(fakes.spawn.spawnedPorts, equals(<int>[50160]));
      expect(fakes.ownership.upsertedStatuses, equals(<_TestStatus>[_TestStatus.starting]));
      expect(fakes.ownership.records, isEmpty);
    });

    test("aborting during the health loop rolls back and never retries the next port", () async {
      final controller = StartAbortController();
      fakes.bindable.byPort.addAll(<int, bool>{49152: true, 49153: true});
      final spawned = _spawned(pid: 111, port: 49152, exitImmediately: true);
      fakes.spawn.results.add(spawned);
      fakes.probe.results.add(const RuntimeHealthProbe(healthy: false, error: "warming up"));
      fakes.probe.onProbe = controller.abort;
      fakes.processes.inspectResults[111] = <ProcessIdentity?>[null];

      await expectLater(
        fakes.service().start(
          spec: fakes.spec(portPolicy: _dynamic(<int>[49152, 49153])),
          terminatedBridgeIdentities: const <ProcessIdentity>[],
          startAborted: controller.signal,
        ),
        throwsA(isA<PluginStartAbortedException>()),
      );

      expect(fakes.spawn.spawnedPorts, equals(<int>[49152]));
      expect(fakes.probe.probedPorts, equals(<int>[49152]));
      expect(fakes.ownership.records, isEmpty);
    });

    test("aborting settles as an abort even when the remaining candidates are all invalid", () async {
      // The first candidate's spawn aborts the start and fails; every later
      // candidate is the reserved port, so the loop would otherwise skip them
      // all and end as a generic exhaustion failure instead of an abort.
      final controller = StartAbortController();
      fakes.bindable.byPort[49152] = true;
      fakes.spawn.results.add(StateError("bind race"));
      fakes.spawn.onSpawn = controller.abort;

      await expectLater(
        fakes.service().start(
          spec: fakes.spec(portPolicy: _dynamic(<int>[49152, 4096, 4096, 4096])),
          terminatedBridgeIdentities: const <ProcessIdentity>[],
          startAborted: controller.signal,
        ),
        throwsA(isA<PluginStartAbortedException>()),
      );

      expect(fakes.spawn.spawnedPorts, equals(<int>[49152]));
    });

    test("aborting after validation rolls back before marking ready", () async {
      final controller = StartAbortController();
      fakes.spawn.results.add(_spawned(pid: 121, port: 50161, exitImmediately: true));
      fakes.probe.results.add(const RuntimeHealthProbe(healthy: true));
      fakes.processes.inspectResults[121] = <ProcessIdentity?>[null];

      await expectLater(
        fakes.service().start(
          spec: fakes.spec(
            portPolicy: const ExplicitPortPolicy(port: 50161),
            validateRuntime: ({required int port}) async => controller.abort(),
          ),
          terminatedBridgeIdentities: const <ProcessIdentity>[],
          startAborted: controller.signal,
        ),
        throwsA(isA<PluginStartAbortedException>()),
      );

      // The ready record is never written; the starting record is rolled back.
      expect(fakes.ownership.upsertedStatuses, equals(<_TestStatus>[_TestStatus.starting]));
      expect(fakes.ownership.records, isEmpty);
    });
  });

  group("ManagedProcessService.attach", () {
    late _Fakes fakes;

    setUp(() {
      fakes = _Fakes();
    });

    test("returns an un-owned handle when the existing server is healthy", () async {
      fakes.probe.results.add(const RuntimeHealthProbe(healthy: true));

      final handle = await fakes.service().attach(
        spec: fakes.spec(portPolicy: const ExplicitPortPolicy(port: 50125)),
        port: 50125,
      );

      expect(handle.port, equals(50125));
      expect(handle.isOwned, isFalse);
      expect(handle.record, isNull);
      expect(handle.process, isNull);
      expect(handle.identity, isNull);
      expect(fakes.probe.probedPorts, equals(<int>[50125]));
      expect(fakes.spawn.spawnedPorts, isEmpty);
      expect(fakes.ownership.writeCallCount, equals(0));
      expect(fakes.ownership.deleteCallCount, equals(0));
      expect(fakes.processes.signalRequests, isEmpty);
    });

    test("fails without ownership or signals when the existing server is unreachable", () async {
      fakes.probe.results.add(const RuntimeHealthProbe(healthy: false, error: "connection refused"));

      await expectLater(
        fakes.service().attach(
          spec: fakes.spec(portPolicy: const ExplicitPortPolicy(port: 50126)),
          port: 50126,
        ),
        throwsA(isA<PluginStartException>()),
      );

      expect(fakes.probe.probedPorts, equals(<int>[50126]));
      expect(fakes.spawn.spawnedPorts, isEmpty);
      expect(fakes.ownership.writeCallCount, equals(0));
      expect(fakes.ownership.deleteCallCount, equals(0));
      expect(fakes.processes.signalRequests, isEmpty);
    });

    test("honors an abort that fires while the health probe is in flight", () async {
      final controller = StartAbortController();
      fakes.probe.results.add(const RuntimeHealthProbe(healthy: true));
      fakes.probe.onProbe = controller.abort;

      await expectLater(
        fakes.service().attach(
          spec: fakes.spec(portPolicy: const ExplicitPortPolicy(port: 50128)),
          port: 50128,
          startAborted: controller.signal,
        ),
        throwsA(isA<PluginStartAbortedException>()),
      );

      expect(fakes.probe.probedPorts, equals(<int>[50128]));
    });

    test("treats a thrown probe as an unreachable server", () async {
      fakes.probe.throwError = Exception("connection refused");

      await expectLater(
        fakes.service().attach(
          spec: fakes.spec(portPolicy: const ExplicitPortPolicy(port: 50127)),
          port: 50127,
        ),
        throwsA(isA<PluginStartException>()),
      );

      expect(fakes.probe.probedPorts, equals(<int>[50127]));
      expect(fakes.ownership.writeCallCount, equals(0));
      expect(fakes.processes.signalRequests, isEmpty);
    });
  });
}

/// An unbounded source that keeps yielding [value] — used to prove the
/// dynamic-start cap terminates even when every candidate is filtered out.
Iterable<int> _endless(int value) sync* {
  while (true) {
    yield value;
  }
}

RuntimePortPolicy _dynamic(List<int> candidates, {bool failFastOnSpawnError = false}) {
  return RuntimePortPolicy.dynamic(
    candidates: candidates,
    maxAttempts: 5,
    reservedPort: 4096,
    minPort: 49152,
    maxPort: 65535,
    failFastOnSpawnError: failFastOnSpawnError,
  );
}

_FakeSpawnedProcess _spawned({
  required int pid,
  required int port,
  String? startMarker = "open-start",
  bool exitImmediately = true,
}) {
  return _FakeSpawnedProcess(
    identity: _runtimeIdentity(pid: pid, port: port, startMarker: startMarker),
    exitImmediately: exitImmediately,
  );
}

ProcessIdentity _runtimeIdentity({required int pid, required int port, String? startMarker = "open-start"}) {
  return ProcessIdentity(
    pid: pid,
    startMarker: startMarker,
    executablePath: "/usr/local/bin/opencode",
    commandLine: "/usr/local/bin/opencode serve --port $port --hostname 127.0.0.1",
    ownerUser: ProcessUser.fromRawUser("alex"),
    platform: "macos",
    capturedAt: DateTime.utc(2026, 5, 15, 12),
  );
}

_TestRecord _buildRecord(RuntimeRecordDraft draft) {
  return _TestRecord(
    ownerSessionId: draft.ownerSessionId,
    openCodePid: draft.runtimeIdentity.pid,
    openCodeStartMarker: draft.runtimeIdentity.startMarker,
    openCodeExecutablePath: draft.runtimeIdentity.executablePath ?? "",
    openCodeCommand: draft.runtimeIdentity.executablePath ?? "opencode",
    openCodeArgs: <String>["serve", "--port", "${draft.port}", "--hostname", "127.0.0.1"],
    port: draft.port,
    bridgePid: draft.bridgeIdentity.pid,
    bridgeStartMarker: draft.bridgeIdentity.startMarker,
    startedAt: draft.startedAt,
    status: _TestStatus.starting,
  );
}

class _Fakes {
  _Fakes({_RecordingClock? clock}) : clock = clock ?? _FakeServerClock();

  final _FakeOwnershipRepository ownership = _FakeOwnershipRepository();
  final _FakeHostProcessService processes = _FakeHostProcessService();
  final _FakeBridgeHostInfo bridge = _FakeBridgeHostInfo(
    identity: ProcessIdentity(
      pid: 900,
      startMarker: "bridge-start",
      executablePath: "/usr/local/bin/sesori-bridge",
      commandLine: "sesori-bridge",
      ownerUser: ProcessUser.fromRawUser("alex"),
      platform: "macos",
      capturedAt: DateTime.utc(2026, 5, 15, 12),
    ),
  );
  final _RecordingClock clock;
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

  ManagedRuntimeSpec<_TestRecord> spec({
    required RuntimePortPolicy portPolicy,
    RuntimeHealthPolicy healthPolicy = _legacyHealthPolicy,
    RuntimeRecordTiming recordTiming = RuntimeRecordTiming.afterSpawn,
    Future<void> Function({required int port})? validateRuntime,
    bool failOnEarlyChildExit = false,
    _TestRecord Function(RuntimeRecordDraft draft)? buildRecord,
  }) {
    return ManagedRuntimeSpec<_TestRecord>(
      spawn: spawn.spawn,
      probeHealth: probe.probe,
      probePortBindable: bindable.bindable,
      buildRecord: buildRecord ?? _buildRecord,
      portPolicy: portPolicy,
      healthPolicy: healthPolicy,
      recordTiming: recordTiming,
      validateRuntime: validateRuntime,
      failOnEarlyChildExit: failOnEarlyChildExit,
    );
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
  final List<int> probedPorts = <int>[];
  void Function()? onProbe;
  Object? throwError;

  Future<RuntimeHealthProbe> probe({required int port}) async {
    probedPorts.add(port);
    onProbe?.call();
    final error = throwError;
    if (error != null) {
      throw error;
    }
    if (results.isEmpty) {
      return const RuntimeHealthProbe(healthy: false, error: "no probe configured");
    }
    return results.removeAt(0);
  }
}

class _BindablePlan {
  final Map<int, bool> byPort = <int, bool>{};
  final List<int> probedPorts = <int>[];

  Future<bool> bindable({required int port}) async {
    probedPorts.add(port);
    final value = byPort[port];
    if (value == null) {
      throw StateError("No bindability configured for $port");
    }
    return value;
  }
}

enum _TestStatus { starting, ready, stopping }

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

  _TestRecord copyWith({required _TestStatus status}) {
    return _TestRecord(
      ownerSessionId: ownerSessionId,
      openCodePid: openCodePid,
      openCodeStartMarker: openCodeStartMarker,
      openCodeExecutablePath: openCodeExecutablePath,
      openCodeCommand: openCodeCommand,
      openCodeArgs: openCodeArgs,
      port: port,
      bridgePid: bridgePid,
      bridgeStartMarker: bridgeStartMarker,
      startedAt: startedAt,
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
  String runtimeCommandLineOf({required _TestRecord record}) {
    return <String>[record.openCodeCommand, ...record.openCodeArgs].join(" ");
  }

  @override
  int bridgePidOf({required _TestRecord record}) => record.bridgePid;

  @override
  String? bridgeStartMarkerOf({required _TestRecord record}) => record.bridgeStartMarker;

  @override
  _TestRecord markReady({required _TestRecord record}) => record.copyWith(status: _TestStatus.ready);

  @override
  _TestRecord markStopping({required _TestRecord record}) => record.copyWith(status: _TestStatus.stopping);
}

class _FakeOwnershipRepository implements RuntimeOwnershipRepository<_TestRecord> {
  final Map<String, _TestRecord> records = <String, _TestRecord>{};
  final List<_TestStatus> upsertedStatuses = <_TestStatus>[];
  int writeCallCount = 0;
  int deleteCallCount = 0;
  Object? deleteError;

  @override
  Future<void> deleteByOwnerSessionId({required String ownerSessionId}) async {
    deleteCallCount += 1;
    final error = deleteError;
    if (error != null) {
      throw error;
    }
    records.remove(ownerSessionId);
  }

  @override
  Future<List<_TestRecord>> readAll() async => records.values.toList(growable: false);

  @override
  Future<_TestRecord?> readByOwnerSessionId({required String ownerSessionId}) async => records[ownerSessionId];

  @override
  Future<void> upsert({required _TestRecord record}) async {
    writeCallCount += 1;
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
    return _signal(pid: pid, signal: ShutdownSignal.force);
  }

  @override
  Future<SignalResult> signalGraceful({required int pid}) async {
    signalRequests.add("graceful:$pid");
    gracefulHooks[pid]?.call();
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

abstract interface class _RecordingClock implements ServerClock {
  List<Duration> get delays;
}

class _FakeServerClock implements _RecordingClock {
  @override
  final List<Duration> delays = <Duration>[];

  @override
  Future<void> delay({required Duration duration}) async {
    delays.add(duration);
  }

  @override
  DateTime now() => DateTime.utc(2026, 5, 15, 12, 30);
}

class _AdvancingServerClock implements _RecordingClock {
  _AdvancingServerClock({DateTime? start}) : _now = start ?? DateTime.utc(2026, 5, 15, 12);

  DateTime _now;

  @override
  final List<Duration> delays = <Duration>[];

  @override
  Future<void> delay({required Duration duration}) async {
    delays.add(duration);
    _now = _now.add(duration);
  }

  @override
  DateTime now() => _now;
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

  void completeExit([int code = 0]) {
    if (!_exitCodeCompleter.isCompleted) {
      _exitCodeCompleter.complete(code);
    }
  }
}
