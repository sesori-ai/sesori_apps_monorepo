import 'dart:io';

import 'package:sesori_bridge/src/server/foundation/process_match.dart';
import 'package:sesori_bridge/src/server/foundation/terminal_prompt_decision.dart';
import 'package:sesori_bridge/src/server/models/bridge_startup_lock.dart';
import 'package:sesori_bridge/src/server/repositories/bridge_instance_repository.dart';
import 'package:sesori_bridge/src/server/repositories/process_repository.dart';
import 'package:sesori_bridge/src/server/repositories/terminal_prompt_repository.dart';
import 'package:sesori_bridge/src/server/services/bridge_instance_service.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart';
import 'package:test/test.dart';

void main() {
  group('BridgeInstanceService', () {
    late _FakeBridgeInstanceRepository bridgeInstanceRepository;
    late _FakeTerminalPromptRepository terminalPromptRepository;
    late _FakeProcessRepository processRepository;
    late _FakeServerClock clock;
    late BridgeInstanceService service;

    setUp(() {
      bridgeInstanceRepository = _FakeBridgeInstanceRepository();
      terminalPromptRepository = _FakeTerminalPromptRepository();
      processRepository = _FakeProcessRepository();
      clock = _FakeServerClock();
      service = BridgeInstanceService(
        bridgeInstanceRepository: bridgeInstanceRepository,
        terminalPromptRepository: terminalPromptRepository,
        processRepository: processRepository,
        clock: clock,
      );
    });

    test('allows startup without prompt when no live bridge exists', () async {
      bridgeInstanceRepository.snapshots = <List<ProcessIdentity>>[<ProcessIdentity>[]];

      final result = await service.enforceSingleLiveBridge(currentPid: 100);

      expect(result.status, equals(BridgeInstanceResolutionStatus.allowed));
      expect(result.terminatedBridges, isEmpty);
      expect(terminalPromptRepository.askCount, equals(0));
      expect(processRepository.signalRequests, isEmpty);
    });

    test('interactive decline aborts without killing existing bridge', () async {
      bridgeInstanceRepository.snapshots = <List<ProcessIdentity>>[
        <ProcessIdentity>[_candidate(pid: 200)],
      ];
      terminalPromptRepository.decision = TerminalPromptDecision.decline;

      final result = await service.enforceSingleLiveBridge(currentPid: 100);

      expect(result.status, equals(BridgeInstanceResolutionStatus.declined));
      expect(result.existingBridges.single.pid, equals(200));
      expect(result.terminatedBridges, isEmpty);
      expect(terminalPromptRepository.bridgeCounts, equals(<int>[1]));
      expect(processRepository.signalRequests, isEmpty);
      expect(clock.delays, isEmpty);
    });

    test('non-interactive conflict fails without prompt hang or kill', () async {
      bridgeInstanceRepository.snapshots = <List<ProcessIdentity>>[
        <ProcessIdentity>[_candidate(pid: 201)],
      ];
      terminalPromptRepository.decision = TerminalPromptDecision.nonInteractive;

      final result = await service.enforceSingleLiveBridge(currentPid: 100);

      expect(result.status, equals(BridgeInstanceResolutionStatus.nonInteractive));
      expect(result.existingBridges.single.pid, equals(201));
      expect(result.terminatedBridges, isEmpty);
      expect(processRepository.signalRequests, isEmpty);
    });

    test('interactive replace returns bridge terminated after graceful shutdown', () async {
      final existing = _candidate(pid: 202);
      bridgeInstanceRepository.snapshots = <List<ProcessIdentity>>[
        <ProcessIdentity>[existing],
        <ProcessIdentity>[],
      ];
      terminalPromptRepository.decision = TerminalPromptDecision.replace;

      final result = await service.enforceSingleLiveBridge(currentPid: 100);

      expect(result.status, equals(BridgeInstanceResolutionStatus.allowed));
      expect(result.terminatedBridges.single.pid, equals(202));
      expect(result.terminatedBridges.single.startMarker, equals('Fri May 15 12:00:00 2026'));
      expect(processRepository.signalRequests, equals(<String>['graceful:202']));
      expect(clock.delays, equals(<Duration>[const Duration(seconds: 5)]));
    });

    test('interactive replace force kills bridge that remains after graceful wait', () async {
      final existing = _candidate(pid: 203);
      bridgeInstanceRepository.snapshots = <List<ProcessIdentity>>[
        <ProcessIdentity>[existing],
        <ProcessIdentity>[existing],
        <ProcessIdentity>[],
      ];
      terminalPromptRepository.decision = TerminalPromptDecision.replace;

      final result = await service.enforceSingleLiveBridge(currentPid: 100);
      expect(result.terminatedBridges.single.pid, equals(203));
      expect(processRepository.signalRequests, equals(<String>['graceful:203', 'force:203']));
    });

    test('interactive replace does not force kill or report terminated when pid identity changes', () async {
      final existing = _candidate(pid: 206, startMarker: 'original-start');
      final reusedPid = _candidate(pid: 206, startMarker: 'different-start');
      bridgeInstanceRepository.snapshots = <List<ProcessIdentity>>[
        <ProcessIdentity>[existing],
        <ProcessIdentity>[reusedPid],
      ];
      terminalPromptRepository.decision = TerminalPromptDecision.replace;

      final result = await service.enforceSingleLiveBridge(currentPid: 100);

      expect(result.status, equals(BridgeInstanceResolutionStatus.allowed));
      expect(result.terminatedBridges, isEmpty);
      expect(processRepository.signalRequests, equals(<String>['graceful:206']));
      expect(clock.delays, equals(<Duration>[const Duration(seconds: 5)]));
    });

    test('interactive replace handles multiple bridges independently', () async {
      final first = _candidate(pid: 204);
      final second = _candidate(pid: 205);
      bridgeInstanceRepository.snapshots = <List<ProcessIdentity>>[
        <ProcessIdentity>[first, second],
        <ProcessIdentity>[second],
        <ProcessIdentity>[],
      ];
      terminalPromptRepository.decision = TerminalPromptDecision.replace;

      final result = await service.enforceSingleLiveBridge(currentPid: 100);

      expect(result.terminatedBridges.map((bridge) => bridge.pid), equals(<int>[204, 205]));
      expect(processRepository.signalRequests, equals(<String>['graceful:204', 'graceful:205', 'force:205']));
      expect(clock.delays, equals(<Duration>[const Duration(seconds: 5)]));
    });

    test('service does not reference OpenCodeServerService', () async {
      final serviceFile = File('app/lib/src/server/services/bridge_instance_service.dart');
      final resolvedServiceFile = serviceFile.existsSync()
          ? serviceFile
          : File('lib/src/server/services/bridge_instance_service.dart');
      final contents = await resolvedServiceFile.readAsString();

      expect(contents, isNot(contains('OpenCodeServerService')));
      expect(contents, isNot(contains("../api/")));
    });

    test('startup lock replace graceful-kill verified holder returns allowed', () async {
      const lock = BridgeStartupLock(bridgePid: 300, bridgeStartMarker: 'holder-start');
      final holder = _match(pid: 300, startMarker: 'holder-start');
      processRepository.matchSnapshots[300] = <ProcessMatch?>[holder, null];
      terminalPromptRepository.decision = TerminalPromptDecision.replace;

      final status = await service.resolveStartupLockContention(
        lock: lock,
        holder: holder,
        currentPid: 100,
      );

      expect(status, equals(BridgeInstanceResolutionStatus.allowed));
      expect(terminalPromptRepository.startingBridgePids, equals(<int>[300]));
      expect(processRepository.signalRequests, equals(<String>['graceful:300']));
      expect(clock.delays, equals(<Duration>[const Duration(seconds: 5)]));
    });

    test('startup lock matching current pid returns allowed without prompt or signals', () async {
      const lock = BridgeStartupLock(bridgePid: 300, bridgeStartMarker: 'holder-start');
      final holder = _match(pid: 300, startMarker: 'holder-start');

      final status = await service.resolveStartupLockContention(
        lock: lock,
        holder: holder,
        currentPid: 300,
      );

      expect(status, equals(BridgeInstanceResolutionStatus.allowed));
      expect(terminalPromptRepository.askCount, equals(0));
      expect(processRepository.signalRequests, isEmpty);
    });

    test('startup lock holder already dead at revalidation returns allowed without signals', () async {
      const lock = BridgeStartupLock(bridgePid: 301, bridgeStartMarker: 'holder-start');
      final holder = _match(pid: 301, startMarker: 'holder-start');
      processRepository.matchSnapshots[301] = <ProcessMatch?>[null];
      terminalPromptRepository.decision = TerminalPromptDecision.replace;

      final status = await service.resolveStartupLockContention(
        lock: lock,
        holder: holder,
        currentPid: 100,
      );

      expect(status, equals(BridgeInstanceResolutionStatus.allowed));
      expect(processRepository.signalRequests, isEmpty);
    });

    test('startup lock identity mismatch declines and sends no kill signals', () async {
      const lock = BridgeStartupLock(bridgePid: 302, bridgeStartMarker: 'original-start');
      final holder = _match(pid: 302, startMarker: 'original-start');
      processRepository.matchSnapshots[302] = <ProcessMatch?>[_match(pid: 302, startMarker: 'reused-start')];
      terminalPromptRepository.decision = TerminalPromptDecision.replace;

      final status = await service.resolveStartupLockContention(
        lock: lock,
        holder: holder,
        currentPid: 100,
      );

      expect(status, equals(BridgeInstanceResolutionStatus.declined));
      expect(processRepository.signalRequests, isEmpty);
    });

    test('startup lock decline returns declined', () async {
      const lock = BridgeStartupLock(bridgePid: 303, bridgeStartMarker: 'holder-start');
      final holder = _match(pid: 303, startMarker: 'holder-start');
      terminalPromptRepository.decision = TerminalPromptDecision.decline;

      final status = await service.resolveStartupLockContention(
        lock: lock,
        holder: holder,
        currentPid: 100,
      );

      expect(status, equals(BridgeInstanceResolutionStatus.declined));
      expect(processRepository.signalRequests, isEmpty);
    });

    test('startup lock nonInteractive returns nonInteractive', () async {
      const lock = BridgeStartupLock(bridgePid: 304, bridgeStartMarker: 'holder-start');
      final holder = _match(pid: 304, startMarker: 'holder-start');
      terminalPromptRepository.decision = TerminalPromptDecision.nonInteractive;

      final status = await service.resolveStartupLockContention(
        lock: lock,
        holder: holder,
        currentPid: 100,
      );

      expect(status, equals(BridgeInstanceResolutionStatus.nonInteractive));
      expect(processRepository.signalRequests, isEmpty);
    });

    test('startup lock survives graceful then force-killed returns allowed', () async {
      const lock = BridgeStartupLock(bridgePid: 305, bridgeStartMarker: 'holder-start');
      final holder = _match(pid: 305, startMarker: 'holder-start');
      processRepository.matchSnapshots[305] = <ProcessMatch?>[holder, holder, null];
      terminalPromptRepository.decision = TerminalPromptDecision.replace;

      final status = await service.resolveStartupLockContention(
        lock: lock,
        holder: holder,
        currentPid: 100,
      );

      expect(status, equals(BridgeInstanceResolutionStatus.allowed));
      expect(processRepository.signalRequests, equals(<String>['graceful:305', 'force:305']));
      expect(clock.delays, equals(<Duration>[const Duration(seconds: 5), const Duration(seconds: 1)]));
    });

    test('startup lock survives force returns declined', () async {
      const lock = BridgeStartupLock(bridgePid: 306, bridgeStartMarker: 'holder-start');
      final holder = _match(pid: 306, startMarker: 'holder-start');
      processRepository.matchSnapshots[306] = <ProcessMatch?>[holder, holder, holder];
      terminalPromptRepository.decision = TerminalPromptDecision.replace;

      final status = await service.resolveStartupLockContention(
        lock: lock,
        holder: holder,
        currentPid: 100,
      );

      expect(status, equals(BridgeInstanceResolutionStatus.declined));
      expect(processRepository.signalRequests, equals(<String>['graceful:306', 'force:306']));
    });

    test('startup lock graceful signal failure proceeds to force path without escaping', () async {
      const lock = BridgeStartupLock(bridgePid: 307, bridgeStartMarker: 'holder-start');
      final holder = _match(pid: 307, startMarker: 'holder-start');
      processRepository.matchSnapshots[307] = <ProcessMatch?>[holder, holder, holder];
      processRepository.throwGraceful = true;
      terminalPromptRepository.decision = TerminalPromptDecision.replace;

      final status = await service.resolveStartupLockContention(
        lock: lock,
        holder: holder,
        currentPid: 100,
      );

      expect(status, equals(BridgeInstanceResolutionStatus.declined));
      expect(processRepository.signalRequests, equals(<String>['graceful:307', 'force:307']));
    });

    test('startup lock force signal failure returns declined without escaping', () async {
      const lock = BridgeStartupLock(bridgePid: 308, bridgeStartMarker: 'holder-start');
      final holder = _match(pid: 308, startMarker: 'holder-start');
      processRepository.matchSnapshots[308] = <ProcessMatch?>[holder, holder, holder];
      processRepository.throwForce = true;
      terminalPromptRepository.decision = TerminalPromptDecision.replace;

      final status = await service.resolveStartupLockContention(
        lock: lock,
        holder: holder,
        currentPid: 100,
      );

      expect(status, equals(BridgeInstanceResolutionStatus.declined));
      expect(processRepository.signalRequests, equals(<String>['graceful:308', 'force:308']));
    });
  });
}

ProcessIdentity _candidate({
  required int pid,
  String? startMarker,
}) {
  return ProcessIdentity(
    pid: pid,
    startMarker: startMarker ?? 'Fri May 15 12:00:00 2026',
    executablePath: '/Users/alex/.local/bin/sesori-bridge',
    commandLine: '/Users/alex/.local/bin/sesori-bridge',
    ownerUser: ProcessUser.fromRawUser("alex"),
    platform: 'macos',
    capturedAt: DateTime.utc(2026, 5, 15, 12),
  );
}

ProcessMatch _match({
  required int pid,
  required String? startMarker,
  ProcessMatchKind kind = ProcessMatchKind.sesoriBridge,
  bool isCurrentUserProcess = true,
}) {
  return ProcessMatch(
    identity: _candidate(pid: pid, startMarker: startMarker),
    kind: kind,
    isCurrentUserProcess: isCurrentUserProcess,
  );
}

class _FakeBridgeInstanceRepository implements BridgeInstanceRepository {
  List<List<ProcessIdentity>> snapshots = <List<ProcessIdentity>>[];
  final List<int> currentPids = <int>[];

  @override
  Future<List<ProcessIdentity>> listLiveBridgeCandidates({required int currentPid}) async {
    currentPids.add(currentPid);
    if (snapshots.isEmpty) {
      return <ProcessIdentity>[];
    }
    return snapshots.removeAt(0);
  }
}

class _FakeTerminalPromptRepository implements TerminalPromptRepository {
  TerminalPromptDecision decision = TerminalPromptDecision.replace;
  int askCount = 0;
  int emailPromptCount = 0;
  final List<int> bridgeCounts = <int>[];
  final List<int> startingBridgePids = <int>[];

  @override
  Future<TerminalPromptDecision> askReplaceExistingBridge({required int bridgeCount}) async {
    askCount += 1;
    bridgeCounts.add(bridgeCount);
    return decision;
  }

  @override
  Future<TerminalPromptDecision> askReplaceStartingBridge({required int holderPid}) async {
    askCount += 1;
    startingBridgePids.add(holderPid);
    return decision;
  }

  @override
  Future<TerminalPromptDecision> askStopBridgesBeforeLogout({required int bridgeCount}) async {
    askCount += 1;
    bridgeCounts.add(bridgeCount);
    return decision;
  }

  @override
  ({String email, String password}) promptForEmailCredentials() {
    final newCount = emailPromptCount++;
    return (
      email: "email-$newCount",
      password: "pwd-$newCount",
    );
  }
}

class _FakeProcessRepository implements ProcessRepository {
  final List<String> signalRequests = <String>[];
  final Map<int, List<ProcessMatch?>> matchSnapshots = <int, List<ProcessMatch?>>{};
  bool throwGraceful = false;
  bool throwForce = false;

  @override
  Future<ProcessIdentity?> inspectProcess({required int pid}) async {
    return null;
  }

  @override
  Future<ProcessMatch?> inspectProcessMatch({required int pid}) async {
    final snapshots = matchSnapshots[pid];
    if (snapshots == null || snapshots.isEmpty) {
      return null;
    }
    return snapshots.removeAt(0);
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
  Future<SignalResult> sendGracefulSignal({required int pid}) async {
    signalRequests.add('graceful:$pid');
    if (throwGraceful) {
      throw StateError('graceful failed');
    }
    return SignalResult(
      pid: pid,
      requestedSignal: ShutdownSignal.graceful,
      deliveredSignal: .sigterm,
      wasRequested: true,
      attemptedAt: DateTime.utc(2026, 5, 15, 12),
    );
  }

  @override
  Future<SignalResult> sendForceSignal({required int pid}) async {
    signalRequests.add('force:$pid');
    if (throwForce) {
      throw StateError('force failed');
    }
    return SignalResult(
      pid: pid,
      requestedSignal: ShutdownSignal.force,
      deliveredSignal: .sigkill,
      wasRequested: true,
      attemptedAt: DateTime.utc(2026, 5, 15, 12, 0, 1),
    );
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
    return DateTime.utc(2026, 5, 15, 12);
  }
}
