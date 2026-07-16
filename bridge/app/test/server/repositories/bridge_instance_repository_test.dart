import 'package:sesori_bridge/src/server/api/process_id_lookup_api.dart';
import 'package:sesori_bridge/src/server/api/system_process_api.dart';
import 'package:sesori_bridge/src/server/repositories/bridge_instance_repository.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart';
import 'package:test/test.dart';

void main() {
  group('BridgeInstanceRepository', () {
    late _FakeProcessIdLookupApi processIdLookupApi;
    late _FakeSystemProcessApi processApi;
    late BridgeInstanceRepository repository;

    setUp(() {
      processIdLookupApi = _FakeProcessIdLookupApi();
      processApi = _FakeSystemProcessApi();
      repository = BridgeInstanceRepository(
        processIdLookupApi: processIdLookupApi,
        processApi: processApi,
        currentUser: ProcessUser.fromRawUser('alex'),
      );
    });

    test('returns inspected current-user release binaries and excludes the current pid', () async {
      processIdLookupApi.processIds = <int>[10, 11, 12];
      processApi.inspectionFacts.addAll(<int, ProcessIdentity>{
        10: _fact(pid: 10, executablePath: '/Users/alex/.local/bin/sesori-bridge'),
        12: _fact(pid: 12, executablePath: '/Users/alex/.local/bin/sesori-bridge'),
      });

      final candidates = await repository.listLiveBridgeCandidates(currentPid: 11);

      expect(candidates.map((candidate) => candidate.pid), equals(<int>[10, 12]));
      expect(candidates.first.startMarker, equals('Fri May 15 12:00:00 2026'));
      expect(processIdLookupApi.executableNames, equals(<String>['sesori-bridge']));
      expect(processApi.inspectedPids, equals(<int>[10, 12]));
      expect(processApi.listCallCount, equals(0));
    });

    test('filters other-user and pid-recycled non-bridge processes', () async {
      processIdLookupApi.processIds = <int>[20, 21];
      processApi.inspectionFacts.addAll(<int, ProcessIdentity>{
        20: _fact(
          pid: 20,
          executablePath: 'sesori-bridge.exe',
          ownerUser: 'other',
        ),
        21: _fact(pid: 21, executablePath: '/usr/local/bin/opencode'),
      });

      final candidates = await repository.listLiveBridgeCandidates(currentPid: 999);

      expect(candidates, isEmpty);
      expect(processApi.inspectedPids, equals(<int>[20, 21]));
    });

    test('keeps a release bridge when its owner cannot be resolved', () async {
      processIdLookupApi.processIds = <int>[30];
      processApi.inspectionFacts[30] = _fact(
        pid: 30,
        executablePath: 'sesori-bridge.exe',
        ownerUser: null,
      );

      final candidates = await repository.listLiveBridgeCandidates(currentPid: 999);

      expect(candidates.single.pid, equals(30));
    });

    test('keeps a release bridge when the current user cannot be resolved', () async {
      repository = BridgeInstanceRepository(
        processIdLookupApi: processIdLookupApi,
        processApi: processApi,
        currentUser: null,
      );
      processIdLookupApi.processIds = <int>[31];
      processApi.inspectionFacts[31] = _fact(
        pid: 31,
        executablePath: '/usr/local/bin/sesori-bridge',
        ownerUser: 'other',
      );

      final candidates = await repository.listLiveBridgeCandidates(currentPid: 999);

      expect(candidates.single.pid, equals(31));
    });

    test('skips a candidate that exits before targeted inspection', () async {
      processIdLookupApi.processIds = <int>[40];

      final candidates = await repository.listLiveBridgeCandidates(currentPid: 999);

      expect(candidates, isEmpty);
      expect(processApi.inspectedPids, equals(<int>[40]));
    });

    test('does not discover source-run bridges', () async {
      processApi.inspectionFacts[50] = _fact(
        pid: 50,
        executablePath: '/usr/local/bin/dart',
        commandLine: 'dart run bridge/app/bin/bridge.dart',
      );

      final candidates = await repository.listLiveBridgeCandidates(currentPid: 999);

      expect(candidates, isEmpty);
      expect(processApi.inspectedPids, isEmpty);
    });
  });
}

ProcessIdentity _fact({
  required int pid,
  required String? executablePath,
  String? ownerUser = 'alex',
  String? commandLine,
}) {
  return ProcessIdentity(
    pid: pid,
    startMarker: 'Fri May 15 12:00:00 2026',
    executablePath: executablePath,
    commandLine: commandLine ?? executablePath ?? '',
    ownerUser: ProcessUser.fromRawUser(ownerUser),
    platform: 'macos',
    capturedAt: DateTime.utc(2026, 5, 15, 12),
  );
}

class _FakeProcessIdLookupApi implements ProcessIdLookupApi {
  List<int> processIds = <int>[];
  final List<String> executableNames = <String>[];

  @override
  Future<List<int>> listProcessIdsByExecutableName({required String executableName}) async {
    executableNames.add(executableName);
    return processIds;
  }
}

class _FakeSystemProcessApi implements SystemProcessApi {
  final Map<int, ProcessIdentity?> inspectionFacts = <int, ProcessIdentity?>{};
  final List<int> inspectedPids = <int>[];
  int listCallCount = 0;

  @override
  Future<ProcessIdentity?> inspectProcess({required int pid}) async {
    inspectedPids.add(pid);
    return inspectionFacts[pid];
  }

  @override
  Future<List<ProcessIdentity>> listProcesses() async {
    listCallCount += 1;
    return const <ProcessIdentity>[];
  }

  @override
  Future<List<int>> listProcessIdsByExecutableName({required String executableName}) {
    throw UnimplementedError();
  }

  @override
  Future<int> startDetached({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SignalResult> sendForceSignal({required int pid}) {
    throw UnimplementedError();
  }

  @override
  Future<SignalResult> sendGracefulSignal({required int pid}) {
    throw UnimplementedError();
  }
}
