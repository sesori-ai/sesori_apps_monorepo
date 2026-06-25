import 'dart:io';

import 'package:sesori_bridge/src/bridge/runtime/bridge_logout_runner.dart';
import 'package:sesori_bridge/src/server/foundation/process_match.dart';
import 'package:sesori_bridge/src/server/foundation/terminal_prompt_decision.dart';
import 'package:sesori_bridge/src/server/models/bridge_startup_lock.dart';
import 'package:sesori_bridge/src/server/repositories/bridge_instance_repository.dart';
import 'package:sesori_bridge/src/server/repositories/terminal_prompt_repository.dart';
import 'package:sesori_bridge/src/server/services/bridge_instance_service.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart';
import 'package:test/test.dart';

void main() {
  group('BridgeLogoutRunner', () {
    late _FakeBridgeInstanceRepository bridgeInstanceRepository;
    late _FakeBridgeInstanceService bridgeInstanceService;
    late _FakeTerminalPromptRepository terminalPromptRepository;
    late int unregisterBridgeCalls;
    late Object? unregisterBridgeError;
    late int clearTokensCalls;
    late int clearTokensCallsAtLastUnregister;
    late Object? clearTokensError;
    late BridgeLogoutRunner service;

    setUp(() {
      bridgeInstanceRepository = _FakeBridgeInstanceRepository();
      bridgeInstanceService = _FakeBridgeInstanceService();
      terminalPromptRepository = _FakeTerminalPromptRepository();
      unregisterBridgeCalls = 0;
      unregisterBridgeError = null;
      clearTokensCalls = 0;
      clearTokensCallsAtLastUnregister = -1;
      clearTokensError = null;
      service = BridgeLogoutRunner(
        bridgeInstanceRepository: bridgeInstanceRepository,
        bridgeInstanceService: bridgeInstanceService,
        terminalPromptRepository: terminalPromptRepository,
        unregisterBridge: () async {
          unregisterBridgeCalls += 1;
          clearTokensCallsAtLastUnregister = clearTokensCalls;
          if (unregisterBridgeError != null) {
            throw unregisterBridgeError!;
          }
        },
        clearTokens: () async {
          clearTokensCalls += 1;
          if (clearTokensError != null) {
            throw clearTokensError!;
          }
        },
      );
    });

    test('clears tokens without prompting when no bridge is running', () async {
      final result = await service.logout(currentPid: 100);

      expect(result.status, equals(BridgeLogoutStatus.loggedOut));
      expect(result.runningBridgeCount, equals(0));
      expect(clearTokensCalls, equals(1));
      expect(terminalPromptRepository.askCount, equals(0));
      expect(bridgeInstanceService.terminateRequests, isEmpty);
    });

    test('decline keeps tokens and does not terminate bridges', () async {
      bridgeInstanceRepository.liveBridges = <ProcessIdentity>[_candidate(pid: 200)];
      terminalPromptRepository.decision = TerminalPromptDecision.decline;

      final result = await service.logout(currentPid: 100);

      expect(result.status, equals(BridgeLogoutStatus.cancelled));
      expect(result.runningBridgeCount, equals(1));
      expect(clearTokensCalls, equals(0));
      expect(bridgeInstanceService.terminateRequests, isEmpty);
    });

    test('non-interactive clears tokens and reports running bridges', () async {
      bridgeInstanceRepository.liveBridges = <ProcessIdentity>[
        _candidate(pid: 200),
        _candidate(pid: 201),
      ];
      terminalPromptRepository.decision = TerminalPromptDecision.nonInteractive;

      final result = await service.logout(currentPid: 100);

      expect(result.status, equals(BridgeLogoutStatus.loggedOutWithRunningBridges));
      expect(result.runningBridgeCount, equals(2));
      expect(clearTokensCalls, equals(1));
      expect(bridgeInstanceService.terminateRequests, isEmpty);
    });

    test('accepting the prompt terminates bridges before clearing tokens', () async {
      final bridge = _candidate(pid: 200);
      bridgeInstanceRepository.liveBridges = <ProcessIdentity>[bridge];
      terminalPromptRepository.decision = TerminalPromptDecision.replace;
      bridgeInstanceService.terminatedBridges = <ProcessIdentity>[bridge];

      final result = await service.logout(currentPid: 100);

      expect(result.status, equals(BridgeLogoutStatus.loggedOut));
      expect(result.runningBridgeCount, equals(0));
      expect(clearTokensCalls, equals(1));
      expect(bridgeInstanceService.terminateRequests.single.map((b) => b.pid), equals(<int>[200]));
      expect(terminalPromptRepository.bridgeCounts, equals(<int>[1]));
    });

    test('reports bridges that survived termination', () async {
      final first = _candidate(pid: 200);
      final second = _candidate(pid: 201);
      bridgeInstanceRepository.liveBridges = <ProcessIdentity>[first, second];
      terminalPromptRepository.decision = TerminalPromptDecision.replace;
      bridgeInstanceService.terminatedBridges = <ProcessIdentity>[first];

      final result = await service.logout(currentPid: 100);

      expect(result.status, equals(BridgeLogoutStatus.loggedOutWithRunningBridges));
      expect(result.runningBridgeCount, equals(1));
      expect(clearTokensCalls, equals(1));
    });

    test('reports failure when clearing tokens throws', () async {
      clearTokensError = const FileSystemException('cannot delete token file');

      final result = await service.logout(currentPid: 100);

      expect(result.status, equals(BridgeLogoutStatus.failed));
      expect(result.error, equals(clearTokensError));
    });

    test('unregisters the bridge before clearing tokens', () async {
      final result = await service.logout(currentPid: 100);

      expect(result.status, equals(BridgeLogoutStatus.loggedOut));
      expect(unregisterBridgeCalls, equals(1));
      expect(clearTokensCallsAtLastUnregister, equals(0));
      expect(clearTokensCalls, equals(1));
    });

    test('still clears tokens when unregistering the bridge fails', () async {
      unregisterBridgeError = Exception('auth server unreachable');

      final result = await service.logout(currentPid: 100);

      expect(result.status, equals(BridgeLogoutStatus.loggedOut));
      expect(unregisterBridgeCalls, equals(1));
      expect(clearTokensCalls, equals(1));
    });

    test('does not unregister the bridge when logout is declined', () async {
      bridgeInstanceRepository.liveBridges = <ProcessIdentity>[_candidate(pid: 200)];
      terminalPromptRepository.decision = TerminalPromptDecision.decline;

      final result = await service.logout(currentPid: 100);

      expect(result.status, equals(BridgeLogoutStatus.cancelled));
      expect(unregisterBridgeCalls, equals(0));
      expect(clearTokensCalls, equals(0));
    });
  });
}

ProcessIdentity _candidate({required int pid}) {
  return ProcessIdentity(
    pid: pid,
    startMarker: 'Fri May 15 12:00:00 2026',
    executablePath: '/Users/alex/.local/bin/sesori-bridge',
    commandLine: '/Users/alex/.local/bin/sesori-bridge',
    ownerUser: ProcessUser.fromRawUser("alex"),
    platform: 'macos',
    capturedAt: DateTime.utc(2026, 5, 15, 12),
  );
}

class _FakeBridgeInstanceRepository implements BridgeInstanceRepository {
  List<ProcessIdentity> liveBridges = <ProcessIdentity>[];

  @override
  Future<List<ProcessIdentity>> listLiveBridgeCandidates({required int currentPid}) async {
    return liveBridges;
  }
}

class _FakeBridgeInstanceService implements BridgeInstanceService {
  @override
  Future<void> awaitPredecessorBridgeExit({
    required int predecessorPid,
    required Duration timeout,
  }) async {}

  List<ProcessIdentity> terminatedBridges = <ProcessIdentity>[];
  final List<List<ProcessIdentity>> terminateRequests = <List<ProcessIdentity>>[];

  @override
  Future<BridgeInstanceResolution> enforceSingleLiveBridge({required int currentPid}) async {
    throw UnimplementedError('not used by logout');
  }

  @override
  Future<List<ProcessIdentity>> terminateBridges({
    required int currentPid,
    required List<ProcessIdentity> existingBridges,
  }) async {
    terminateRequests.add(existingBridges);
    return terminatedBridges;
  }

  @override
  Future<BridgeInstanceResolutionStatus> resolveStartupLockContention({
    required BridgeStartupLock lock,
    required ProcessMatch holder,
    required int currentPid,
  }) async {
    throw UnimplementedError('not used by logout');
  }
}

class _FakeTerminalPromptRepository implements TerminalPromptRepository {
  TerminalPromptDecision decision = TerminalPromptDecision.replace;
  int askCount = 0;
  final List<int> bridgeCounts = <int>[];

  @override
  Future<TerminalPromptDecision> askReplaceExistingBridge({required int bridgeCount}) async {
    throw UnimplementedError('not used by logout');
  }

  @override
  Future<TerminalPromptDecision> askReplaceStartingBridge({required int holderPid}) async {
    throw UnimplementedError('not used by logout');
  }

  @override
  Future<TerminalPromptDecision> askStopBridgesBeforeLogout({required int bridgeCount}) async {
    askCount += 1;
    bridgeCounts.add(bridgeCount);
    return decision;
  }

  @override
  ({String email, String password}) promptForEmailCredentials() {
    throw UnimplementedError('not used by logout');
  }
}
