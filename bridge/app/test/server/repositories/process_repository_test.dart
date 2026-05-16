import "dart:async";

import "package:sesori_bridge/src/server/api/system_process_api.dart";
import "package:sesori_bridge/src/server/foundation/process_identity.dart";
import "package:sesori_bridge/src/server/foundation/process_match.dart";
import "package:sesori_bridge/src/server/foundation/shutdown_result.dart";
import "package:sesori_bridge/src/server/repositories/process_repository.dart";
import "package:test/test.dart";

void main() {
  group("ProcessRepository", () {
    late _FakeSystemProcessApi api;
    late ProcessRepository repository;

    setUp(() {
      api = _FakeSystemProcessApi();
      repository = ProcessRepository(api: api, currentUser: "alex");
    });

    test("process inspection returns typed identity", () async {
      final capturedAt = DateTime.utc(2026, 5, 15, 11, 30);
      api.inspectFact = ProcessIdentity(
        pid: 321,
        startMarker: "Fri May 15 11:30:00 2026",
        executablePath: "/usr/local/bin/opencode",
        commandLine: "/usr/local/bin/opencode serve --port 53111",
        ownerUser: "alex",
        platform: "macos",
        capturedAt: capturedAt,
      );

      final identity = await repository.inspectProcess(pid: 321);

      expect(api.inspectPid, equals(321));
      expect(identity, isNotNull);
      expect(identity!.pid, equals(321));
      expect(identity.startMarker, equals("Fri May 15 11:30:00 2026"));
      expect(identity.executablePath, equals("/usr/local/bin/opencode"));
      expect(identity.commandLine, contains("opencode serve"));
      expect(identity.ownerUser, equals("alex"));
      expect(identity.platform, equals("macos"));
      expect(identity.capturedAt, equals(capturedAt));
    });

    test("process inspection classifies bridge, OpenCode, and unknown matches", () async {
      api.listFacts = <ProcessIdentity>[
        ProcessIdentity(
          pid: 10,
          startMarker: null,
          executablePath: "/Users/alex/.local/bin/sesori-bridge",
          commandLine: "/Users/alex/.local/bin/sesori-bridge --relay wss://relay.sesori.com",
          ownerUser: "alex",
          platform: "macos",
          capturedAt: DateTime.utc(2026, 5, 15, 12),
        ),
        ProcessIdentity(
          pid: 11,
          startMarker: null,
          executablePath: "/usr/local/bin/opencode",
          commandLine: "/usr/local/bin/opencode serve --port 45111",
          ownerUser: "alex",
          platform: "macos",
          capturedAt: DateTime.utc(2026, 5, 15, 12, 1),
        ),
        ProcessIdentity(
          pid: 12,
          startMarker: null,
          executablePath: "/usr/bin/python3",
          commandLine: "python3 worker.py",
          ownerUser: "other",
          platform: "macos",
          capturedAt: DateTime.utc(2026, 5, 15, 12, 2),
        ),
      ];

      final matches = await repository.listProcesses(excludePid: 11);

      expect(matches, hasLength(2));
      expect(matches.first.kind, equals(ProcessMatchKind.sesoriBridge));
      expect(matches.first.isCurrentUserProcess, isTrue);
      expect(matches.first.identity.pid, equals(10));
      expect(matches.last.kind, equals(ProcessMatchKind.unknown));
      expect(matches.last.isCurrentUserProcess, isFalse);
      expect(matches.last.identity.startMarker, isNull);
    });

    test("process repository exposes graceful and force signal primitives", () async {
      api.gracefulResult = ShutdownResult(
        pid: 44,
        requestedSignal: ShutdownSignal.graceful,
        deliveredSignal: .sigterm,
        wasRequested: true,
        attemptedAt: DateTime.utc(2026, 5, 15, 12, 30),
      );
      api.forceResult = ShutdownResult(
        pid: 44,
        requestedSignal: ShutdownSignal.force,
        deliveredSignal: .sigkill,
        wasRequested: true,
        attemptedAt: DateTime.utc(2026, 5, 15, 12, 30, 1),
      );

      final graceful = await repository.sendGracefulSignal(pid: 44);
      final force = await repository.sendForceSignal(pid: 44);

      expect(graceful.requestedSignal, equals(ShutdownSignal.graceful));
      expect(force.requestedSignal, equals(ShutdownSignal.force));
      expect(api.signalRequests, equals(<String>["graceful:44", "force:44"]));
      expect(api.inspectPid, isNull);
      expect(api.listCallCount, equals(0));
    });
  });
}

class _FakeSystemProcessApi implements SystemProcessApi {
  ProcessIdentity? inspectFact;
  List<ProcessIdentity> listFacts = <ProcessIdentity>[];
  ShutdownResult? gracefulResult;
  ShutdownResult? forceResult;
  int? inspectPid;
  int listCallCount = 0;
  final List<String> signalRequests = <String>[];

  @override
  Future<ProcessIdentity?> inspectProcess({required int pid}) async {
    inspectPid = pid;
    return inspectFact;
  }

  @override
  Future<List<ProcessIdentity>> listProcesses() async {
    listCallCount += 1;
    return listFacts;
  }

  @override
  Future<ShutdownResult> sendForceSignal({required int pid}) async {
    signalRequests.add("force:$pid");
    return forceResult!;
  }

  @override
  Future<ShutdownResult> sendGracefulSignal({required int pid}) async {
    signalRequests.add("graceful:$pid");
    return gracefulResult!;
  }
}
