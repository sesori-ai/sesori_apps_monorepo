import 'package:sesori_bridge/src/server/api/system_process_api.dart';
import 'package:sesori_bridge/src/server/foundation/process_identity.dart';
import 'package:sesori_bridge/src/server/foundation/shutdown_result.dart';
import 'package:sesori_bridge/src/server/repositories/bridge_instance_repository.dart';
import 'package:test/test.dart';

void main() {
  group('BridgeInstanceRepository', () {
    late _FakeSystemProcessApi api;
    late BridgeInstanceRepository repository;

    setUp(() {
      api = _FakeSystemProcessApi();
      repository = BridgeInstanceRepository(api: api, currentUser: 'alex');
    });

    test('excludes current pid and returns multiple current-user bridge binaries', () async {
      api.facts = <ProcessIdentity>[
        _fact(
          pid: 10,
          executablePath: '/Users/alex/.local/bin/sesori-bridge',
          commandLine: '/Users/alex/.local/bin/sesori-bridge',
        ),
        _fact(
          pid: 11,
          executablePath: '/Users/alex/.local/bin/sesori-bridge',
          commandLine: '/Users/alex/.local/bin/sesori-bridge --relay wss://relay.sesori.com',
        ),
        _fact(
          pid: 12,
          executablePath: '/Users/alex/.local/bin/sesori-bridge',
          commandLine: '/Users/alex/.local/bin/sesori-bridge',
        ),
      ];

      final candidates = await repository.listLiveBridgeCandidates(currentPid: 11);

      expect(candidates.map((candidate) => candidate.pid), equals(<int>[10, 12]));
      expect(candidates.first.startMarker, equals('Fri May 15 12:00:00 2026'));
    });

    test('accepts source-run dart bridge command', () async {
      api.facts = <ProcessIdentity>[
        _fact(
          pid: 20,
          executablePath: '/opt/homebrew/bin/dart',
          commandLine: 'dart run bridge/app/bin/bridge.dart --relay wss://relay.sesori.com',
        ),
      ];

      final candidates = await repository.listLiveBridgeCandidates(currentPid: 999);

      expect(candidates.single.pid, equals(20));
    });

    test('filters false positives and other-user bridge commands', () async {
      api.facts = <ProcessIdentity>[
        _fact(
          pid: 30,
          executablePath: '/usr/bin/python3',
          commandLine: 'python bridge/app/bin/bridge.dart',
        ),
        _fact(
          pid: 31,
          executablePath: '/tmp/not-sesori-bridge',
          commandLine: '/tmp/not-sesori-bridge',
        ),
        _fact(
          pid: 32,
          executablePath: '/Users/alex/.local/bin/sesori-bridge',
          commandLine: '/Users/alex/.local/bin/sesori-bridge',
          ownerUser: 'other',
        ),
        _fact(
          pid: 33,
          executablePath: '/usr/local/bin/opencode',
          commandLine: '/usr/local/bin/opencode serve --port 45111',
        ),
      ];

      final candidates = await repository.listLiveBridgeCandidates(currentPid: 999);

      expect(candidates, isEmpty);
    });

    test('keeps bridge candidates when current or process owner is unknown', () async {
      repository = BridgeInstanceRepository(api: api, currentUser: null);
      api.facts = <ProcessIdentity>[
        _fact(
          pid: 40,
          executablePath: '/Users/alex/.local/bin/sesori-bridge',
          commandLine: '/Users/alex/.local/bin/sesori-bridge',
          ownerUser: null,
        ),
        _fact(
          pid: 41,
          executablePath: '/Users/alex/.local/bin/sesori-bridge',
          commandLine: '/Users/alex/.local/bin/sesori-bridge',
          ownerUser: 'other',
        ),
      ];

      final candidates = await repository.listLiveBridgeCandidates(currentPid: 999);

      expect(candidates.map((candidate) => candidate.pid), equals(<int>[40, 41]));
    });

    test('keeps unknown-owner bridge candidate when current user is known', () async {
      api.facts = <ProcessIdentity>[
        _fact(
          pid: 42,
          executablePath: '/Users/alex/.local/bin/sesori-bridge',
          commandLine: '/Users/alex/.local/bin/sesori-bridge',
          ownerUser: null,
        ),
      ];

      final candidates = await repository.listLiveBridgeCandidates(currentPid: 999);

      expect(candidates.single.pid, equals(42));
    });

    test('ignores stale JSON or lock state because it only uses process facts', () async {
      api.facts = <ProcessIdentity>[];

      final candidates = await repository.listLiveBridgeCandidates(currentPid: 999);

      expect(candidates, isEmpty);
      expect(api.listCallCount, equals(1));
    });
  });
}

ProcessIdentity _fact({
  required int pid,
  required String? executablePath,
  required String commandLine,
  String? ownerUser = 'alex',
}) {
  return ProcessIdentity(
    pid: pid,
    startMarker: 'Fri May 15 12:00:00 2026',
    executablePath: executablePath,
    commandLine: commandLine,
    ownerUser: ownerUser,
    platform: 'macos',
    capturedAt: DateTime.utc(2026, 5, 15, 12),
  );
}

class _FakeSystemProcessApi implements SystemProcessApi {
  List<ProcessIdentity> facts = <ProcessIdentity>[];
  int listCallCount = 0;

  @override
  Future<ProcessIdentity?> inspectProcess({required int pid}) async {
    return facts.where((fact) => fact.pid == pid).firstOrNull;
  }

  @override
  Future<List<ProcessIdentity>> listProcesses() async {
    listCallCount += 1;
    return facts;
  }

  @override
  Future<ShutdownResult> sendForceSignal({required int pid}) {
    throw UnimplementedError();
  }

  @override
  Future<ShutdownResult> sendGracefulSignal({required int pid}) {
    throw UnimplementedError();
  }
}
