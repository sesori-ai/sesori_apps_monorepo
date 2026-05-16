import 'dart:io';

import 'package:sesori_bridge/src/server/foundation/process_identity.dart';
import 'package:sesori_bridge/src/server/foundation/process_match.dart';
import 'package:sesori_bridge/src/server/foundation/server_clock.dart';
import 'package:sesori_bridge/src/server/foundation/shutdown_result.dart';
import 'package:sesori_bridge/src/server/foundation/terminal_prompt_decision.dart';
import 'package:sesori_bridge/src/server/repositories/bridge_instance_repository.dart';
import 'package:sesori_bridge/src/server/repositories/process_repository.dart';
import 'package:sesori_bridge/src/server/repositories/terminal_prompt_repository.dart';
import 'package:sesori_bridge/src/server/services/bridge_instance_service.dart';
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
      expect(processRepository.signalRequests, equals(<String>['graceful:204', 'graceful:205']));
      expect(clock.delays, equals(<Duration>[const Duration(seconds: 5), const Duration(seconds: 5)]));
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
    ownerUser: 'alex',
    platform: 'macos',
    capturedAt: DateTime.utc(2026, 5, 15, 12),
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
  final List<int> bridgeCounts = <int>[];

  @override
  Future<TerminalPromptDecision> askReplaceExistingBridge({required int bridgeCount}) async {
    askCount += 1;
    bridgeCounts.add(bridgeCount);
    return decision;
  }
}

class _FakeProcessRepository implements ProcessRepository {
  final List<String> signalRequests = <String>[];

  @override
  Future<ProcessIdentity?> inspectProcess({required int pid}) async {
    return null;
  }

  @override
  Future<ProcessMatch?> inspectProcessMatch({required int pid}) async {
    return null;
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
  Future<ShutdownResult> sendGracefulSignal({required int pid}) async {
    signalRequests.add('graceful:$pid');
    return ShutdownResult(
      pid: pid,
      requestedSignal: ShutdownSignal.graceful,
      deliveredSignal: .sigterm,
      wasRequested: true,
      attemptedAt: DateTime.utc(2026, 5, 15, 12),
    );
  }

  @override
  Future<ShutdownResult> sendForceSignal({required int pid}) async {
    signalRequests.add('force:$pid');
    return ShutdownResult(
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
