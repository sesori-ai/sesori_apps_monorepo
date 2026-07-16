import "package:sesori_bridge/src/server/api/system_process_api.dart";
import "package:sesori_bridge/src/server/foundation/process_match.dart";
import "package:sesori_bridge/src/server/repositories/process_repository.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("ProcessRepository", () {
    late _FakeSystemProcessApi api;
    late ProcessRepository repository;

    setUp(() {
      api = _FakeSystemProcessApi();
      repository = ProcessRepository(
        api: api,
        currentUser: ProcessUser.fromRawUser("alex"),
      );
    });

    test("process inspection returns typed identity", () async {
      final capturedAt = DateTime.utc(2026, 5, 15, 11, 30);
      api.inspectFact = ProcessIdentity(
        pid: 321,
        startMarker: "Fri May 15 11:30:00 2026",
        executablePath: "/usr/local/bin/opencode",
        commandLine: "/usr/local/bin/opencode serve --port 53111",
        ownerUser: ProcessUser.fromRawUser("alex"),
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
      expect(identity.ownerUser, equals(ProcessUser.fromRawUser("alex")));
      expect(identity.platform, equals("macos"));
      expect(identity.capturedAt, equals(capturedAt));
    });

    test("targeted process inspection classifies bridge and unknown matches", () async {
      api.inspectFact = ProcessIdentity(
        pid: 10,
        startMarker: null,
        executablePath: "/Users/alex/.local/bin/sesori-bridge",
        commandLine: "/Users/alex/.local/bin/sesori-bridge --relay wss://relay.sesori.com",
        ownerUser: ProcessUser.fromRawUser("alex"),
        platform: "macos",
        capturedAt: DateTime.utc(2026, 5, 15, 12),
      );

      final bridgeMatch = await repository.inspectProcessMatch(pid: 10);

      expect(bridgeMatch, isNotNull);
      expect(bridgeMatch!.kind, equals(ProcessMatchKind.sesoriBridge));
      expect(bridgeMatch.isCurrentUserProcess, isTrue);
      expect(bridgeMatch.identity.pid, equals(10));

      api.inspectFact = ProcessIdentity(
        pid: 12,
        startMarker: null,
        executablePath: "/usr/bin/python3",
        commandLine: "python3 worker.py",
        ownerUser: ProcessUser.fromRawUser("other"),
        platform: "macos",
        capturedAt: DateTime.utc(2026, 5, 15, 12, 2),
      );

      final unknownMatch = await repository.inspectProcessMatch(pid: 12);

      expect(unknownMatch, isNotNull);
      expect(unknownMatch!.kind, equals(ProcessMatchKind.unknown));
      expect(unknownMatch.isCurrentUserProcess, isFalse);
      expect(unknownMatch.identity.startMarker, isNull);
    });

    test("process repository exposes graceful and force signal primitives", () async {
      api.gracefulResult = SignalResult(
        pid: 44,
        requestedSignal: ShutdownSignal.graceful,
        deliveredSignal: .sigterm,
        wasRequested: true,
        attemptedAt: DateTime.utc(2026, 5, 15, 12, 30),
      );
      api.forceResult = SignalResult(
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
    });
  });
}

class _FakeSystemProcessApi implements SystemProcessApi {
  @override
  Future<int> startDetached({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
  }) async {
    throw UnimplementedError();
  }

  ProcessIdentity? inspectFact;
  SignalResult? gracefulResult;
  SignalResult? forceResult;
  int? inspectPid;
  final List<String> signalRequests = <String>[];

  @override
  Future<ProcessIdentity?> inspectProcess({required int pid}) async {
    inspectPid = pid;
    return inspectFact;
  }

  @override
  Future<SignalResult> sendForceSignal({required int pid}) async {
    signalRequests.add("force:$pid");
    return forceResult!;
  }

  @override
  Future<SignalResult> sendGracefulSignal({required int pid}) async {
    signalRequests.add("graceful:$pid");
    return gracefulResult!;
  }
}
