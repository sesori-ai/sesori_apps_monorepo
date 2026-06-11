import 'package:sesori_bridge/src/server/foundation/process_match.dart';
import 'package:sesori_bridge/src/server/host/bridge_host_info_impl.dart';
import 'package:sesori_bridge/src/server/repositories/process_repository.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart';
import 'package:test/test.dart';

void main() {
  group('BridgeHostInfoImpl', () {
    late _FakeProcessRepository processRepository;
    late BridgeHostInfoImpl hostInfo;

    final bridgeIdentity = _identity(
      pid: 100,
      startMarker: 'bridge-start-marker',
      executablePath: '/usr/local/bin/sesori-bridge',
      commandLine: '/usr/local/bin/sesori-bridge --port 4096',
    );

    setUp(() {
      processRepository = _FakeProcessRepository();
      hostInfo = BridgeHostInfoImpl(
        identity: bridgeIdentity,
        ownerSessionId: '100:bridge-start-marker',
        processRepository: processRepository,
      );
    });

    test('exposes the bridge identity and owner session id', () {
      expect(hostInfo.identity, same(bridgeIdentity));
      expect(hostInfo.ownerSessionId, '100:bridge-start-marker');
    });

    test('isLiveBridgeProcess is false when the pid is not running', () async {
      expect(
        await hostInfo.isLiveBridgeProcess(pid: 211, startMarker: 'other-marker'),
        isFalse,
      );
    });

    test('isLiveBridgeProcess is false when the pid is not a sesori bridge', () async {
      processRepository.matchResults[211] = ProcessMatch(
        identity: _identity(
          pid: 211,
          startMarker: 'other-marker',
          executablePath: '/usr/bin/vim',
          commandLine: '/usr/bin/vim notes.txt',
        ),
        kind: ProcessMatchKind.unknown,
        isCurrentUserProcess: true,
      );

      expect(
        await hostInfo.isLiveBridgeProcess(pid: 211, startMarker: 'other-marker'),
        isFalse,
      );
    });

    test('isLiveBridgeProcess requires matching markers when either side has one', () async {
      processRepository.matchResults[211] = _bridgeMatch(pid: 211, startMarker: 'marker-a');

      expect(await hostInfo.isLiveBridgeProcess(pid: 211, startMarker: 'marker-a'), isTrue);
      processRepository.matchResults[211] = _bridgeMatch(pid: 211, startMarker: 'marker-a');
      expect(await hostInfo.isLiveBridgeProcess(pid: 211, startMarker: 'marker-b'), isFalse);
      processRepository.matchResults[211] = _bridgeMatch(pid: 211, startMarker: 'marker-a');
      expect(await hostInfo.isLiveBridgeProcess(pid: 211, startMarker: null), isFalse);
      processRepository.matchResults[211] = _bridgeMatch(pid: 211, startMarker: null);
      expect(await hostInfo.isLiveBridgeProcess(pid: 211, startMarker: 'marker-a'), isFalse);
    });

    test('isLiveBridgeProcess accepts marker-less records for a marker-less live bridge', () async {
      processRepository.matchResults[211] = _bridgeMatch(pid: 211, startMarker: null);

      expect(await hostInfo.isLiveBridgeProcess(pid: 211, startMarker: null), isTrue);
    });

    test('isLiveBridgeProcess spares live bridges owned by another user', () async {
      processRepository.matchResults[211] = ProcessMatch(
        identity: _identity(
          pid: 211,
          startMarker: 'marker-a',
          executablePath: '/usr/local/bin/sesori-bridge',
          commandLine: '/usr/local/bin/sesori-bridge',
        ),
        kind: ProcessMatchKind.sesoriBridge,
        isCurrentUserProcess: false,
      );

      expect(await hostInfo.isLiveBridgeProcess(pid: 211, startMarker: 'marker-a'), isTrue);
    });
  });
}

ProcessMatch _bridgeMatch({required int pid, required String? startMarker}) {
  return ProcessMatch(
    identity: _identity(
      pid: pid,
      startMarker: startMarker,
      executablePath: '/usr/local/bin/sesori-bridge',
      commandLine: '/usr/local/bin/sesori-bridge --port 4097',
    ),
    kind: ProcessMatchKind.sesoriBridge,
    isCurrentUserProcess: true,
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
    ownerUser: ProcessUser.fromRawUser('alex'),
    platform: 'macos',
    capturedAt: DateTime.utc(2026, 5, 15, 12),
  );
}

class _FakeProcessRepository implements ProcessRepository {
  final Map<int, ProcessMatch?> matchResults = <int, ProcessMatch?>{};

  @override
  Future<ProcessMatch?> inspectProcessMatch({required int pid}) async {
    return matchResults[pid];
  }

  @override
  Future<ProcessIdentity?> inspectProcess({required int pid}) {
    throw UnimplementedError();
  }

  @override
  Future<List<ProcessIdentity>> listProcessIdentities({required int? excludePid}) {
    throw UnimplementedError();
  }

  @override
  Future<List<ProcessMatch>> listProcesses({required int? excludePid}) {
    throw UnimplementedError();
  }

  @override
  Future<SignalResult> sendGracefulSignal({required int pid}) {
    throw UnimplementedError();
  }

  @override
  Future<SignalResult> sendForceSignal({required int pid}) {
    throw UnimplementedError();
  }
}
