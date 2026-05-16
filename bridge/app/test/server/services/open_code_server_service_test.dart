import "dart:async";
import "dart:convert";
import "dart:io";

import "package:sesori_bridge/src/server/foundation/process_identity.dart";
import "package:sesori_bridge/src/server/foundation/process_match.dart";
import "package:sesori_bridge/src/server/foundation/server_clock.dart";
import "package:sesori_bridge/src/server/foundation/shutdown_result.dart";
import "package:sesori_bridge/src/server/repositories/open_code_ownership_record.dart";
import "package:sesori_bridge/src/server/repositories/open_code_ownership_repository.dart";
import "package:sesori_bridge/src/server/repositories/open_code_process_repository.dart";
import "package:sesori_bridge/src/server/repositories/port_repository.dart";
import "package:sesori_bridge/src/server/repositories/process_repository.dart";
import "package:sesori_bridge/src/server/services/open_code_server_service.dart";
import "package:test/test.dart";

void main() {
  group("OpenCodeServerService", () {
    late _FakeOpenCodeProcessRepository openCodeRepository;
    late _FakeProcessRepository processRepository;
    late _FakePortRepository portRepository;
    late _FakeOwnershipRepository ownershipRepository;
    late _FakeServerClock clock;
    late ProcessIdentity bridgeIdentity;

    setUp(() {
      openCodeRepository = _FakeOpenCodeProcessRepository();
      processRepository = _FakeProcessRepository();
      portRepository = _FakePortRepository();
      ownershipRepository = _FakeOwnershipRepository();
      clock = _FakeServerClock();
      bridgeIdentity = _identity(
        pid: 900,
        startMarker: "bridge-start",
        executablePath: "/usr/local/bin/sesori-bridge",
        commandLine: "sesori-bridge",
      );
    });

    test("omitted port retries dynamic candidates after a start race", () async {
      portRepository.availabilityByPort.addAll(<int, bool>{
        49152: true,
        49153: true,
      });
      openCodeRepository.startResults.addAll(<Object>[
        StateError("bind race"),
        _startResult(pid: 101, port: 49153),
      ]);
      openCodeRepository.healthResults.add(
        _health(port: 49153, healthy: true),
      );
      final service = _service(
        openCodeRepository: openCodeRepository,
        processRepository: processRepository,
        portRepository: portRepository,
        ownershipRepository: ownershipRepository,
        clock: clock,
        bridgeIdentity: bridgeIdentity,
        candidatePorts: <int>[4096, 49152, 49153],
      );

      final runtime = await service.start(
        executablePath: "/usr/local/bin/opencode",
        requestedPort: null,
        password: null,
        terminatedBridgeIdentities: const <ProcessIdentity>[],
      );

      expect(runtime.port, equals(49153));
      expect(runtime.serverPassword, equals("generated-password"));
      expect(portRepository.probedPorts, equals(<int>[49152, 49153]));
      expect(openCodeRepository.startedPorts, equals(<int>[49152, 49153]));
      expect(ownershipRepository.records.values.single.status, equals(OpenCodeOwnershipStatus.ready));
      expect(ownershipRepository.records.values.single.port, equals(49153));
    });

    test("dynamic discovery stops after twenty five candidates", () async {
      for (var port = 49152; port < 49182; port += 1) {
        portRepository.availabilityByPort[port] = false;
      }
      final service = _service(
        openCodeRepository: openCodeRepository,
        processRepository: processRepository,
        portRepository: portRepository,
        ownershipRepository: ownershipRepository,
        clock: clock,
        bridgeIdentity: bridgeIdentity,
        candidatePorts: List<int>.generate(30, (index) => 49152 + index),
      );

      await expectLater(
        service.start(
          executablePath: "/usr/local/bin/opencode",
          requestedPort: null,
          password: null,
          terminatedBridgeIdentities: const <ProcessIdentity>[],
        ),
        throwsA(isA<OpenCodeServerStartException>()),
      );

      expect(portRepository.probedPorts, hasLength(25));
      expect(openCodeRepository.startedPorts, isEmpty);
      expect(processRepository.signalRequests, isEmpty);
    });

    test("explicit ports bypass discovery and do not retry health failure", () async {
      openCodeRepository.startResults.add(_startResult(pid: 201, port: 4096));
      openCodeRepository.healthResults.add(
        _health(port: 4096, healthy: false, error: "not ready"),
      );
      processRepository.inspectResults[201] = <ProcessIdentity?>[
        null,
        _identity(
          pid: 201,
          startMarker: "open-start-201",
          executablePath: "/usr/local/bin/opencode",
          commandLine: "/usr/local/bin/opencode serve --port 4096 --hostname 127.0.0.1",
        ),
        null,
      ];
      final service = _service(
        openCodeRepository: openCodeRepository,
        processRepository: processRepository,
        portRepository: portRepository,
        ownershipRepository: ownershipRepository,
        clock: clock,
        bridgeIdentity: bridgeIdentity,
        candidatePorts: <int>[49152, 49153],
      );

      await expectLater(
        service.start(
          executablePath: "/usr/local/bin/opencode",
          requestedPort: 4096,
          password: "explicit-password",
          terminatedBridgeIdentities: const <ProcessIdentity>[],
        ),
        throwsA(isA<OpenCodeServerStartException>()),
      );

      expect(portRepository.probedPorts, isEmpty);
      expect(openCodeRepository.startedPorts, equals(<int>[4096]));
      expect(openCodeRepository.healthProbePorts, equals(<int>[4096]));
      expect(processRepository.signalRequests, equals(<String>["graceful:201"]));
      expect(ownershipRepository.records, isEmpty);
    });

    test("explicit non-4096 bind failure does not retry or signal other processes", () async {
      openCodeRepository.startResults.add(StateError("bind failed"));
      final service = _service(
        openCodeRepository: openCodeRepository,
        processRepository: processRepository,
        portRepository: portRepository,
        ownershipRepository: ownershipRepository,
        clock: clock,
        bridgeIdentity: bridgeIdentity,
        candidatePorts: <int>[49152, 49153],
      );

      await expectLater(
        service.start(
          executablePath: "/usr/local/bin/opencode",
          requestedPort: 50128,
          password: "explicit-password",
          terminatedBridgeIdentities: const <ProcessIdentity>[],
        ),
        throwsA(isA<StateError>()),
      );

      expect(portRepository.probedPorts, isEmpty);
      expect(openCodeRepository.startedPorts, equals(<int>[50128]));
      expect(openCodeRepository.healthProbePorts, isEmpty);
      expect(processRepository.signalRequests, isEmpty);
      expect(ownershipRepository.writeCallCount, equals(0));
      expect(ownershipRepository.deleteCallCount, equals(0));
      expect(ownershipRepository.records, isEmpty);
    });

    test("failed startup cleanup never calls Process.kill directly", () async {
      final spawnedProcess = _FakeProcess(pidValue: 211);
      openCodeRepository.startResults.add(
        OpenCodeStartResult(
          process: spawnedProcess,
          password: "password",
          identity: _identity(
            pid: 211,
            startMarker: "open-start-211",
            executablePath: "/usr/local/bin/opencode",
            commandLine: "/usr/local/bin/opencode serve --port 50129 --hostname 127.0.0.1",
          ),
        ),
      );
      openCodeRepository.healthResults.add(
        _health(port: 50129, healthy: false, error: "not ready"),
      );
      processRepository.inspectResults[211] = <ProcessIdentity?>[
        null,
        _identity(
          pid: 211,
          startMarker: "open-start-211",
          executablePath: "/usr/local/bin/opencode",
          commandLine: "/usr/local/bin/opencode serve --port 50129 --hostname 127.0.0.1",
        ),
        null,
      ];
      final service = _service(
        openCodeRepository: openCodeRepository,
        processRepository: processRepository,
        portRepository: portRepository,
        ownershipRepository: ownershipRepository,
        clock: clock,
        bridgeIdentity: bridgeIdentity,
        candidatePorts: null,
      );

      await expectLater(
        service.start(
          executablePath: "/usr/local/bin/opencode",
          requestedPort: 50129,
          password: "explicit-password",
          terminatedBridgeIdentities: const <ProcessIdentity>[],
        ),
        throwsA(isA<OpenCodeServerStartException>()),
      );

      expect(processRepository.signalRequests, equals(<String>["graceful:211"]));
      expect(spawnedProcess.killSignals, isEmpty);
    });

    test("failed startup cleanup force stops current-owned child without a start marker", () async {
      final spawnedProcess = _FakeProcess(pidValue: 212, exitImmediately: false);
      openCodeRepository.startResults.add(
        OpenCodeStartResult(
          process: spawnedProcess,
          password: "password",
          identity: _identity(
            pid: 212,
            startMarker: null,
            executablePath: "/usr/local/bin/opencode",
            commandLine: "/usr/local/bin/opencode serve --port 50130 --hostname 127.0.0.1",
          ),
        ),
      );
      openCodeRepository.healthResults.add(
        _health(port: 50130, healthy: false, error: "not ready"),
      );
      processRepository.inspectResults[212] = <ProcessIdentity?>[
        null,
        null,
        null,
      ];
      processRepository.forceHooks[212] = spawnedProcess.completeExit;
      final service = _service(
        openCodeRepository: openCodeRepository,
        processRepository: processRepository,
        portRepository: portRepository,
        ownershipRepository: ownershipRepository,
        clock: clock,
        bridgeIdentity: bridgeIdentity,
        candidatePorts: null,
      );

      await expectLater(
        service.start(
          executablePath: "/usr/local/bin/opencode",
          requestedPort: 50130,
          password: "explicit-password",
          terminatedBridgeIdentities: const <ProcessIdentity>[],
        ),
        throwsA(isA<OpenCodeServerStartException>()),
      );

      expect(processRepository.signalRequests, equals(<String>["graceful:212", "force:212"]));
      expect(ownershipRepository.records, isEmpty);
      expect(clock.delays, equals(<Duration>[openCodeGracefulShutdownWait]));
      expect(spawnedProcess.killSignals, isEmpty);
    });

    test("ownership timing records starting then ready", () async {
      openCodeRepository.startResults.add(_startResult(pid: 301, port: 50123));
      openCodeRepository.healthResults.add(_health(port: 50123, healthy: true));
      final service = _service(
        openCodeRepository: openCodeRepository,
        processRepository: processRepository,
        portRepository: portRepository,
        ownershipRepository: ownershipRepository,
        clock: clock,
        bridgeIdentity: bridgeIdentity,
        candidatePorts: null,
      );

      await service.start(
        executablePath: "/usr/local/bin/opencode",
        requestedPort: 50123,
        password: "secret",
        terminatedBridgeIdentities: const <ProcessIdentity>[],
      );

      expect(
        ownershipRepository.upsertedStatuses,
        equals(<OpenCodeOwnershipStatus>[OpenCodeOwnershipStatus.starting, OpenCodeOwnershipStatus.ready]),
      );
      expect(ownershipRepository.records.values.single.openCodePid, equals(301));
    });

    test("auto-start ownership and runtime prefer inspected post-spawn identity", () async {
      openCodeRepository.startResults.add(_startResult(pid: 302, port: 50124, startMarkerMissing: true));
      openCodeRepository.healthResults.add(_health(port: 50124, healthy: true));
      processRepository.inspectResults[302] = <ProcessIdentity?>[
        _identity(
          pid: 302,
          startMarker: "inspected-open-start",
          executablePath: "/usr/local/bin/opencode",
          commandLine: "/usr/local/bin/opencode serve --port 50124 --hostname 127.0.0.1",
        ),
      ];
      final service = _service(
        openCodeRepository: openCodeRepository,
        processRepository: processRepository,
        portRepository: portRepository,
        ownershipRepository: ownershipRepository,
        clock: clock,
        bridgeIdentity: bridgeIdentity,
        candidatePorts: null,
      );

      final runtime = await service.start(
        executablePath: "/usr/local/bin/opencode",
        requestedPort: 50124,
        password: "secret",
        terminatedBridgeIdentities: const <ProcessIdentity>[],
      );

      expect(ownershipRepository.records.values.single.openCodeStartMarker, equals("inspected-open-start"));
      expect(runtime.identity!.startMarker, equals("inspected-open-start"));
    });

    test("auto-start rejects inspected identity with different command line", () async {
      openCodeRepository.startResults.add(_startResult(pid: 303, port: 50127, startMarkerMissing: true));
      openCodeRepository.healthResults.add(_health(port: 50127, healthy: true));
      processRepository.inspectResults[303] = <ProcessIdentity?>[
        _identity(
          pid: 303,
          startMarker: "wrong-command-start",
          executablePath: "/usr/local/bin/opencode",
          commandLine: "/usr/local/bin/opencode serve --port 59999 --hostname 127.0.0.1",
        ),
      ];
      final service = _service(
        openCodeRepository: openCodeRepository,
        processRepository: processRepository,
        portRepository: portRepository,
        ownershipRepository: ownershipRepository,
        clock: clock,
        bridgeIdentity: bridgeIdentity,
        candidatePorts: null,
      );

      final runtime = await service.start(
        executablePath: "/usr/local/bin/opencode",
        requestedPort: 50127,
        password: "secret",
        terminatedBridgeIdentities: const <ProcessIdentity>[],
      );

      expect(ownershipRepository.records.values.single.openCodeStartMarker, isNull);
      expect(runtime.identity!.startMarker, isNull);
      expect(runtime.identity!.commandLine, equals("/usr/local/bin/opencode serve --port 50127 --hostname 127.0.0.1"));
    });

    test("no-auto-start reachable explicit port probes health without ownership", () async {
      openCodeRepository.healthResults.add(_health(port: 50125, healthy: true));
      final service = _service(
        openCodeRepository: openCodeRepository,
        processRepository: processRepository,
        portRepository: portRepository,
        ownershipRepository: ownershipRepository,
        clock: clock,
        bridgeIdentity: bridgeIdentity,
        candidatePorts: null,
      );

      final runtime = await service.validateExistingServer(
        port: 50125,
        password: "existing-password",
      );

      expect(runtime.port, equals(50125));
      expect(runtime.serverUri, equals(Uri.parse("http://127.0.0.1:50125")));
      expect(runtime.serverPassword, equals("existing-password"));
      expect(runtime.process, isNull);
      expect(runtime.identity, isNull);
      expect(openCodeRepository.healthProbePorts, equals(<int>[50125]));
      expect(openCodeRepository.startedPorts, isEmpty);
      expect(ownershipRepository.writeCallCount, equals(0));
      expect(ownershipRepository.deleteCallCount, equals(0));
      expect(processRepository.signalRequests, isEmpty);
    });

    test("no-auto-start unreachable explicit port fails without ownership or signals", () async {
      openCodeRepository.healthResults.add(_health(port: 50126, healthy: false, error: "connection refused"));
      final service = _service(
        openCodeRepository: openCodeRepository,
        processRepository: processRepository,
        portRepository: portRepository,
        ownershipRepository: ownershipRepository,
        clock: clock,
        bridgeIdentity: bridgeIdentity,
        candidatePorts: null,
      );

      await expectLater(
        service.validateExistingServer(
          port: 50126,
          password: null,
        ),
        throwsA(isA<OpenCodeServerStartException>()),
      );

      expect(openCodeRepository.healthProbePorts, equals(<int>[50126]));
      expect(openCodeRepository.startedPorts, isEmpty);
      expect(ownershipRepository.writeCallCount, equals(0));
      expect(ownershipRepository.deleteCallCount, equals(0));
      expect(processRepository.signalRequests, isEmpty);
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
      processRepository.inspectResults[401] = <ProcessIdentity?>[
        _identity(
          pid: 401,
          startMarker: "open-start",
          executablePath: "/usr/local/bin/opencode",
          commandLine: "/usr/local/bin/opencode serve --port 50123 --hostname 127.0.0.1",
        ),
        _identity(
          pid: 401,
          startMarker: "open-start",
          executablePath: "/usr/local/bin/opencode",
          commandLine: "/usr/local/bin/opencode serve --port 50123 --hostname 127.0.0.1",
        ),
        _identity(
          pid: 401,
          startMarker: "open-start",
          executablePath: "/usr/local/bin/opencode",
          commandLine: "/usr/local/bin/opencode serve --port 50123 --hostname 127.0.0.1",
        ),
        null,
      ];
      processRepository.matchResults[901] = <ProcessMatch?>[null];
      final service = _service(
        openCodeRepository: openCodeRepository,
        processRepository: processRepository,
        portRepository: portRepository,
        ownershipRepository: ownershipRepository,
        clock: clock,
        bridgeIdentity: bridgeIdentity,
        candidatePorts: null,
      );

      await service.cleanupStaleOwnedServers(
        terminatedBridgeIdentities: const <ProcessIdentity>[],
      );

      expect(processRepository.signalRequests, equals(<String>["graceful:401", "force:401"]));
      expect(ownershipRepository.records, isEmpty);
      expect(clock.delays, equals(<Duration>[openCodeGracefulShutdownWait]));
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
      processRepository.inspectResults[402] = <ProcessIdentity?>[
        _identity(
          pid: 402,
          startMarker: "open-start",
          executablePath: "/usr/local/bin/opencode",
          commandLine: "/usr/local/bin/opencode serve --port 50123 --hostname 127.0.0.1",
        ),
        _identity(
          pid: 402,
          startMarker: "different-start",
          executablePath: "/usr/local/bin/opencode",
          commandLine: "/usr/local/bin/opencode serve --port 50123 --hostname 127.0.0.1",
        ),
      ];
      processRepository.matchResults[901] = <ProcessMatch?>[null];
      final service = _service(
        openCodeRepository: openCodeRepository,
        processRepository: processRepository,
        portRepository: portRepository,
        ownershipRepository: ownershipRepository,
        clock: clock,
        bridgeIdentity: bridgeIdentity,
        candidatePorts: null,
      );

      await service.cleanupStaleOwnedServers(
        terminatedBridgeIdentities: const <ProcessIdentity>[],
      );

      expect(processRepository.signalRequests, isEmpty);
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
      processRepository.inspectResults[501] = <ProcessIdentity?>[
        _identity(
          pid: 501,
          startMarker: "open-live",
          executablePath: "/usr/local/bin/opencode",
          commandLine: "/usr/local/bin/opencode serve --port 50123 --hostname 127.0.0.1",
        ),
      ];
      processRepository.matchResults[902] = <ProcessMatch?>[
        ProcessMatch(
          identity: _identity(
            pid: 902,
            startMarker: "live-bridge-start",
            executablePath: "/usr/local/bin/sesori-bridge",
            commandLine: "sesori-bridge",
          ),
          kind: ProcessMatchKind.sesoriBridge,
          isCurrentUserProcess: true,
        ),
      ];
      final service = _service(
        openCodeRepository: openCodeRepository,
        processRepository: processRepository,
        portRepository: portRepository,
        ownershipRepository: ownershipRepository,
        clock: clock,
        bridgeIdentity: bridgeIdentity,
        candidatePorts: null,
      );

      await service.cleanupStaleOwnedServers(
        terminatedBridgeIdentities: const <ProcessIdentity>[],
      );

      expect(processRepository.signalRequests, isEmpty);
      expect(ownershipRepository.records.keys, containsAll(<String>["live-owner", "missing-marker"]));
    });

    test("stale cleanup never kill-authorizes persisted records missing a start marker", () async {
      final missingMarkerRecord = _record(
        ownerSessionId: "missing-marker",
        openCodePid: 503,
        openCodeStartMarker: null,
        bridgePid: 903,
        bridgeStartMarker: "dead-bridge-start",
      );
      ownershipRepository.records[missingMarkerRecord.ownerSessionId] = missingMarkerRecord;
      processRepository.inspectResults[503] = <ProcessIdentity?>[
        _identity(
          pid: 503,
          startMarker: null,
          executablePath: "/usr/local/bin/opencode",
          commandLine: "/usr/local/bin/opencode serve --port 50123 --hostname 127.0.0.1",
        ),
      ];
      processRepository.matchResults[903] = <ProcessMatch?>[null];
      final service = _service(
        openCodeRepository: openCodeRepository,
        processRepository: processRepository,
        portRepository: portRepository,
        ownershipRepository: ownershipRepository,
        clock: clock,
        bridgeIdentity: bridgeIdentity,
        candidatePorts: null,
      );

      await service.cleanupStaleOwnedServers(
        terminatedBridgeIdentities: const <ProcessIdentity>[],
      );

      expect(processRepository.signalRequests, isEmpty);
      expect(ownershipRepository.records.keys, contains("missing-marker"));
      expect(clock.delays, isEmpty);
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
      processRepository.inspectResults[601] = <ProcessIdentity?>[
        _identity(
          pid: 601,
          startMarker: "open-replaced",
          executablePath: "/usr/local/bin/opencode",
          commandLine: "/usr/local/bin/opencode serve --port 50123 --hostname 127.0.0.1",
        ),
        _identity(
          pid: 601,
          startMarker: "open-replaced",
          executablePath: "/usr/local/bin/opencode",
          commandLine: "/usr/local/bin/opencode serve --port 50123 --hostname 127.0.0.1",
        ),
        null,
        null,
      ];
      final service = _service(
        openCodeRepository: openCodeRepository,
        processRepository: processRepository,
        portRepository: portRepository,
        ownershipRepository: ownershipRepository,
        clock: clock,
        bridgeIdentity: bridgeIdentity,
        candidatePorts: null,
      );

      await service.cleanupStaleOwnedServers(
        terminatedBridgeIdentities: <ProcessIdentity>[
          _identity(
            pid: 904,
            startMarker: "replaced-bridge-start",
            executablePath: "/usr/local/bin/sesori-bridge",
            commandLine: "sesori-bridge",
          ),
        ],
      );

      expect(processRepository.signalRequests, equals(<String>["graceful:601"]));
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
      processRepository.inspectResults[701] = <ProcessIdentity?>[
        _identity(
          pid: 701,
          startMarker: "open-current",
          executablePath: "/usr/local/bin/opencode",
          commandLine: "/usr/local/bin/opencode serve --port 50123 --hostname 127.0.0.1",
        ),
        _identity(
          pid: 701,
          startMarker: "open-current",
          executablePath: "/usr/local/bin/opencode",
          commandLine: "/usr/local/bin/opencode serve --port 50123 --hostname 127.0.0.1",
        ),
        null,
      ];
      ownershipRepository.records[record.ownerSessionId] = record;
      final service = _service(
        openCodeRepository: openCodeRepository,
        processRepository: processRepository,
        portRepository: portRepository,
        ownershipRepository: ownershipRepository,
        clock: clock,
        bridgeIdentity: bridgeIdentity,
        candidatePorts: null,
      );

      await service.stopOwnedServer(record: record);

      expect(processRepository.signalRequests, equals(<String>["graceful:701", "force:701"]));
      expect(ownershipRepository.upsertedStatuses.last, equals(OpenCodeOwnershipStatus.stopping));
      expect(ownershipRepository.records, isEmpty);
    });

    test("shutdown keeps ownership when current-owned missing-marker child survives force", () async {
      final spawnedProcess = _FakeProcess(pidValue: 702, exitImmediately: false);
      openCodeRepository.startResults.add(
        OpenCodeStartResult(
          process: spawnedProcess,
          password: "password",
          identity: _identity(
            pid: 702,
            startMarker: null,
            executablePath: "/usr/local/bin/opencode",
            commandLine: "/usr/local/bin/opencode serve --port 50131 --hostname 127.0.0.1",
          ),
        ),
      );
      openCodeRepository.healthResults.add(_health(port: 50131, healthy: true));
      processRepository.inspectResults[702] = <ProcessIdentity?>[
        null,
        null,
        null,
        null,
      ];
      final service = _service(
        openCodeRepository: openCodeRepository,
        processRepository: processRepository,
        portRepository: portRepository,
        ownershipRepository: ownershipRepository,
        clock: clock,
        bridgeIdentity: bridgeIdentity,
        candidatePorts: null,
      );

      await service.start(
        executablePath: "/usr/local/bin/opencode",
        requestedPort: 50131,
        password: "secret",
        terminatedBridgeIdentities: const <ProcessIdentity>[],
      );

      final record = ownershipRepository.records.values.single;
      await service.stopOwnedServer(record: record);

      expect(processRepository.signalRequests, equals(<String>["graceful:702", "force:702"]));
      expect(ownershipRepository.records.keys, contains("current-owner"));
      expect(ownershipRepository.records.values.single.status, equals(OpenCodeOwnershipStatus.stopping));
      expect(clock.delays, equals(<Duration>[openCodeGracefulShutdownWait]));
      expect(spawnedProcess.killSignals, isEmpty);
    });

    test("shutdown does not signal an exited current-owned missing-marker child", () async {
      final spawnedProcess = _FakeProcess(pidValue: 703, exitImmediately: false);
      openCodeRepository.startResults.add(
        OpenCodeStartResult(
          process: spawnedProcess,
          password: "password",
          identity: _identity(
            pid: 703,
            startMarker: null,
            executablePath: "/usr/local/bin/opencode",
            commandLine: "/usr/local/bin/opencode serve --port 50132 --hostname 127.0.0.1",
          ),
        ),
      );
      openCodeRepository.healthResults.add(_health(port: 50132, healthy: true));
      processRepository.inspectResults[703] = <ProcessIdentity?>[
        null,
      ];
      final service = _service(
        openCodeRepository: openCodeRepository,
        processRepository: processRepository,
        portRepository: portRepository,
        ownershipRepository: ownershipRepository,
        clock: clock,
        bridgeIdentity: bridgeIdentity,
        candidatePorts: null,
      );

      await service.start(
        executablePath: "/usr/local/bin/opencode",
        requestedPort: 50132,
        password: "secret",
        terminatedBridgeIdentities: const <ProcessIdentity>[],
      );

      final record = ownershipRepository.records.values.single;
      spawnedProcess.completeExit();

      await service.stopOwnedServer(record: record);

      expect(processRepository.signalRequests, isEmpty);
      expect(ownershipRepository.records, isEmpty);
      expect(clock.delays, isEmpty);
      expect(spawnedProcess.killSignals, isEmpty);
    });
  });
}

OpenCodeServerService _service({
  required _FakeOpenCodeProcessRepository openCodeRepository,
  required _FakeProcessRepository processRepository,
  required _FakePortRepository portRepository,
  required _FakeOwnershipRepository ownershipRepository,
  required _FakeServerClock clock,
  required ProcessIdentity bridgeIdentity,
  required Iterable<int>? candidatePorts,
}) {
  return OpenCodeServerService(
    openCodeProcessRepository: openCodeRepository,
    processRepository: processRepository,
    portRepository: portRepository,
    ownershipRepository: ownershipRepository,
    clock: clock,
    currentBridgeIdentity: bridgeIdentity,
    ownerSessionId: "current-owner",
    candidatePorts: candidatePorts,
    random: null,
  );
}

OpenCodeStartResult _startResult({
  required int pid,
  required int port,
  bool startMarkerMissing = false,
}) {
  return OpenCodeStartResult(
    process: _FakeProcess(pidValue: pid),
    password: "password",
    identity: _identity(
      pid: pid,
      startMarker: startMarkerMissing ? null : "open-start-$pid",
      executablePath: "/usr/local/bin/opencode",
      commandLine: "/usr/local/bin/opencode serve --port $port --hostname 127.0.0.1",
    ),
  );
}

OpenCodeHealthProbeResult _health({
  required int port,
  required bool healthy,
  Object? error,
}) {
  return OpenCodeHealthProbeResult(
    uri: Uri.parse("http://127.0.0.1:$port/global/health"),
    statusCode: healthy ? 200 : null,
    isHealthy: healthy,
    checkedAt: DateTime.utc(2026, 5, 15, 13),
    error: error,
  );
}

OpenCodeOwnershipRecord _record({
  required String ownerSessionId,
  required int openCodePid,
  required String? openCodeStartMarker,
  required int bridgePid,
  required String? bridgeStartMarker,
}) {
  return OpenCodeOwnershipRecord(
    ownerSessionId: ownerSessionId,
    openCodePid: openCodePid,
    openCodeStartMarker: openCodeStartMarker,
    openCodeExecutablePath: "/usr/local/bin/opencode",
    openCodeCommand: "/usr/local/bin/opencode",
    openCodeArgs: const <String>["serve", "--port", "50123", "--hostname", "127.0.0.1"],
    port: 50123,
    bridgePid: bridgePid,
    bridgeStartMarker: bridgeStartMarker,
    startedAt: DateTime.utc(2026, 5, 15, 12),
    status: OpenCodeOwnershipStatus.ready,
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
    ownerUser: "alex",
    platform: "macos",
    capturedAt: DateTime.utc(2026, 5, 15, 12),
  );
}

class _FakeOpenCodeProcessRepository implements OpenCodeProcessRepository {
  final List<Object> startResults = <Object>[];
  final List<OpenCodeHealthProbeResult> healthResults = <OpenCodeHealthProbeResult>[];
  final List<int> startedPorts = <int>[];
  final List<int> healthProbePorts = <int>[];

  @override
  String generatePassword() {
    return "generated-password";
  }

  @override
  Future<OpenCodeHealthProbeResult> probeHealth({required Uri serverUri, required String password}) async {
    healthProbePorts.add(serverUri.port);
    return healthResults.removeAt(0);
  }

  @override
  Future<OpenCodeStartResult> startProcess({
    required String executablePath,
    required int port,
    required String password,
  }) async {
    startedPorts.add(port);
    final result = startResults.removeAt(0);
    if (result is OpenCodeStartResult) {
      return result;
    }
    throw result;
  }
}

class _FakeProcessRepository implements ProcessRepository {
  final Map<int, List<ProcessIdentity?>> inspectResults = <int, List<ProcessIdentity?>>{};
  final Map<int, List<ProcessMatch?>> matchResults = <int, List<ProcessMatch?>>{};
  final Map<int, void Function()> gracefulHooks = <int, void Function()>{};
  final Map<int, void Function()> forceHooks = <int, void Function()>{};
  final List<String> signalRequests = <String>[];

  @override
  Future<ProcessIdentity?> inspectProcess({required int pid}) async {
    final results = inspectResults[pid];
    if (results == null || results.isEmpty) {
      return null;
    }
    return results.removeAt(0);
  }

  @override
  Future<ProcessMatch?> inspectProcessMatch({required int pid}) async {
    final results = matchResults[pid];
    if (results == null || results.isEmpty) {
      return null;
    }
    return results.removeAt(0);
  }

  @override
  Future<List<ProcessIdentity>> listProcessIdentities({required int? excludePid}) async {
    return const <ProcessIdentity>[];
  }

  @override
  Future<List<ProcessMatch>> listProcesses({required int? excludePid}) async {
    return const <ProcessMatch>[];
  }

  @override
  Future<ShutdownResult> sendForceSignal({required int pid}) async {
    signalRequests.add("force:$pid");
    forceHooks[pid]?.call();
    return _shutdown(pid: pid, signal: ShutdownSignal.force);
  }

  @override
  Future<ShutdownResult> sendGracefulSignal({required int pid}) async {
    signalRequests.add("graceful:$pid");
    gracefulHooks[pid]?.call();
    return _shutdown(pid: pid, signal: ShutdownSignal.graceful);
  }

  ShutdownResult _shutdown({required int pid, required ShutdownSignal signal}) {
    return ShutdownResult(
      pid: pid,
      requestedSignal: signal,
      deliveredSignal: signal == .graceful ? .sigterm : .sigkill,
      wasRequested: true,
      attemptedAt: DateTime.utc(2026, 5, 15, 12),
    );
  }
}

class _FakePortRepository implements PortRepository {
  final Map<int, bool> availabilityByPort = <int, bool>{};
  final List<int> probedPorts = <int>[];

  @override
  Future<PortAvailabilityFact> getAvailabilityFact({required int port}) async {
    probedPorts.add(port);
    final available = availabilityByPort[port];
    if (available == null) {
      throw StateError("No availability configured for $port");
    }
    return PortAvailabilityFact(
      host: loopbackPortHost,
      port: port,
      isAvailable: available,
    );
  }

  @override
  Future<List<PortAvailabilityFact>> getCandidateFacts({required Iterable<int> candidatePorts}) async {
    final facts = <PortAvailabilityFact>[];
    for (final port in candidatePorts) {
      facts.add(await getAvailabilityFact(port: port));
    }
    return facts;
  }
}

class _FakeOwnershipRepository implements OpenCodeOwnershipRepository {
  final Map<String, OpenCodeOwnershipRecord> records = <String, OpenCodeOwnershipRecord>{};
  final List<OpenCodeOwnershipStatus> upsertedStatuses = <OpenCodeOwnershipStatus>[];
  int writeCallCount = 0;
  int deleteCallCount = 0;

  @override
  Future<void> deleteByOwnerSessionId({required String ownerSessionId}) async {
    deleteCallCount += 1;
    records.remove(ownerSessionId);
  }

  @override
  Future<List<OpenCodeOwnershipRecord>> readAll() async {
    return records.values.toList(growable: false);
  }

  @override
  Future<OpenCodeOwnershipRecord?> readByOwnerSessionId({required String ownerSessionId}) async {
    return records[ownerSessionId];
  }

  @override
  Future<void> upsert({required OpenCodeOwnershipRecord record}) async {
    writeCallCount += 1;
    records[record.ownerSessionId] = record;
    upsertedStatuses.add(record.status);
  }
}

class _FakeServerClock implements ServerClock {
  final List<Duration> delays = <Duration>[];

  @override
  Future<void> delay({required Duration duration}) async {
    delays.add(duration);
  }

  @override
  DateTime now() {
    return DateTime.utc(2026, 5, 15, 12, 30);
  }
}

class _FakeProcess implements Process {
  _FakeProcess({required int pidValue, bool exitImmediately = true}) : _pidValue = pidValue {
    if (exitImmediately) {
      _exitCodeCompleter.complete(0);
    }
  }

  final int _pidValue;
  final Completer<int> _exitCodeCompleter = Completer<int>();
  final List<ProcessSignal> killSignals = <ProcessSignal>[];

  @override
  int get pid => _pidValue;

  @override
  Future<int> get exitCode => _exitCodeCompleter.future;

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  Stream<List<int>> get stderr => Stream<List<int>>.value(utf8.encode(""));

  @override
  Stream<List<int>> get stdout => Stream<List<int>>.value(utf8.encode(""));

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killSignals.add(signal);
    return true;
  }

  void completeExit([int code = 0]) {
    if (!_exitCodeCompleter.isCompleted) {
      _exitCodeCompleter.complete(code);
    }
  }
}
