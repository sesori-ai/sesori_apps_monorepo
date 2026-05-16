import "package:args/args.dart";
import "package:sesori_bridge/src/bridge/runtime/bridge_cli_options.dart";
import "package:sesori_bridge/src/bridge/runtime/bridge_runtime_server.dart";
import "package:sesori_bridge/src/server/foundation/process_identity.dart";
import "package:sesori_bridge/src/server/repositories/open_code_ownership_record.dart";
import "package:sesori_bridge/src/server/repositories/open_code_ownership_repository.dart";
import "package:sesori_bridge/src/server/repositories/startup_mutex_repository.dart";
import "package:sesori_bridge/src/server/services/bridge_instance_service.dart";
import "package:sesori_bridge/src/server/services/open_code_server_service.dart";
import "package:test/test.dart";

void main() {
  group("resolveServer", () {
    late _FakeStartupMutexRepository startupMutexRepository;
    late _FakeOwnershipRepository ownershipRepository;
    late _FakeBridgeInstanceService bridgeInstanceService;
    late _FakeOpenCodeServerService openCodeServerService;
    late ProcessIdentity currentBridgeIdentity;

    setUp(() {
      startupMutexRepository = _FakeStartupMutexRepository();
      ownershipRepository = _FakeOwnershipRepository();
      bridgeInstanceService = _FakeBridgeInstanceService();
      openCodeServerService = _FakeOpenCodeServerService();
      currentBridgeIdentity = _identity(pid: 100, startMarker: "bridge-start");
    });

    test("no-auto-start without port still fails clearly", () async {
      await expectLater(
        resolveServer(
          options: _options(port: null, noAutoStart: true),
          currentBridgeIdentity: currentBridgeIdentity,
          ownerSessionId: "owner-session",
          startupMutexRepository: startupMutexRepository,
          ownershipRepository: ownershipRepository,
          bridgeInstanceService: bridgeInstanceService,
          openCodeServerService: openCodeServerService,
        ),
        throwsA(
          isA<ArgParserException>().having(
            (error) => error.message,
            "message",
            contains("--no-auto-start"),
          ),
        ),
      );
    });

    test("auto-start without port uses mutex then singleton resolution then service start", () async {
      final terminatedBridge = _identity(pid: 200, startMarker: "old-bridge-start");
      bridgeInstanceService.resolution = BridgeInstanceResolution(
        status: BridgeInstanceResolutionStatus.allowed,
        existingBridges: const <ProcessIdentity>[],
        terminatedBridges: <ProcessIdentity>[terminatedBridge],
      );
      openCodeServerService.startRuntime = OpenCodeServerRuntime(
        serverUri: Uri.parse("http://127.0.0.1:50123"),
        serverPassword: "generated-password",
        process: null,
        port: 50123,
        identity: _identity(pid: 300, startMarker: "open-start"),
      );
      ownershipRepository.recordByOwnerSessionId["owner-session"] = _ownedRecord();

      final runtime = await resolveServer(
        options: _options(port: null, noAutoStart: false),
        currentBridgeIdentity: currentBridgeIdentity,
        ownerSessionId: "owner-session",
        startupMutexRepository: startupMutexRepository,
        ownershipRepository: ownershipRepository,
        bridgeInstanceService: bridgeInstanceService,
        openCodeServerService: openCodeServerService,
      );

      expect(startupMutexRepository.lockRequests, hasLength(1));
      expect(startupMutexRepository.lockRequests.single, equals((pid: 100, startMarker: "bridge-start")));
      expect(bridgeInstanceService.currentPids, equals(<int>[100]));
      expect(openCodeServerService.startCalls.single.requestedPort, isNull);
      expect(
        openCodeServerService.startCalls.single.terminatedBridgeIdentities.map((identity) => identity.pid),
        equals(<int>[200]),
      );
      expect(
        <String>[
          ...startupMutexRepository.operations,
          ...bridgeInstanceService.operations,
          ...openCodeServerService.operations,
        ],
        equals(<String>["mutex.acquire", "singleton.check", "opencode.start"]),
      );
      expect(runtime.serverUrl, equals("http://127.0.0.1:50123"));
      expect(runtime.port, equals(50123));
      expect(runtime.ownedOpenCodeRecord, isNotNull);
      expect(ownershipRepository.readOwnerSessionIds, equals(<String>["owner-session"]));
    });

    test("singleton decline aborts before any OpenCode lifecycle decision", () async {
      bridgeInstanceService.resolution = const BridgeInstanceResolution(
        status: BridgeInstanceResolutionStatus.declined,
        existingBridges: <ProcessIdentity>[],
        terminatedBridges: <ProcessIdentity>[],
      );

      await expectLater(
        resolveServer(
          options: _options(port: 4096, noAutoStart: false),
          currentBridgeIdentity: currentBridgeIdentity,
          ownerSessionId: "owner-session",
          startupMutexRepository: startupMutexRepository,
          ownershipRepository: ownershipRepository,
          bridgeInstanceService: bridgeInstanceService,
          openCodeServerService: openCodeServerService,
        ),
        throwsA(
          isA<BridgeRuntimeServerException>().having(
            (error) => error.message,
            "message",
            contains("declined"),
          ),
        ),
      );

      expect(openCodeServerService.startCalls, isEmpty);
      expect(openCodeServerService.validateCalls, isEmpty);
    });

    test("non-interactive singleton conflict aborts before OpenCode lifecycle", () async {
      bridgeInstanceService.resolution = const BridgeInstanceResolution(
        status: BridgeInstanceResolutionStatus.nonInteractive,
        existingBridges: <ProcessIdentity>[],
        terminatedBridges: <ProcessIdentity>[],
      );

      await expectLater(
        resolveServer(
          options: _options(port: 4096, noAutoStart: false),
          currentBridgeIdentity: currentBridgeIdentity,
          ownerSessionId: "owner-session",
          startupMutexRepository: startupMutexRepository,
          ownershipRepository: ownershipRepository,
          bridgeInstanceService: bridgeInstanceService,
          openCodeServerService: openCodeServerService,
        ),
        throwsA(
          isA<BridgeRuntimeServerException>().having(
            (error) => error.message,
            "message",
            contains("non-interactive"),
          ),
        ),
      );

      expect(openCodeServerService.startCalls, isEmpty);
      expect(openCodeServerService.validateCalls, isEmpty);
    });

    test("mutex rejection aborts before singleton or OpenCode work", () async {
      startupMutexRepository.rejectLock = true;

      await expectLater(
        resolveServer(
          options: _options(port: null, noAutoStart: false),
          currentBridgeIdentity: currentBridgeIdentity,
          ownerSessionId: "owner-session",
          startupMutexRepository: startupMutexRepository,
          ownershipRepository: ownershipRepository,
          bridgeInstanceService: bridgeInstanceService,
          openCodeServerService: openCodeServerService,
        ),
        throwsA(
          isA<BridgeRuntimeServerException>().having(
            (error) => error.message,
            "message",
            contains("already in progress"),
          ),
        ),
      );

      expect(bridgeInstanceService.currentPids, isEmpty);
      expect(openCodeServerService.startCalls, isEmpty);
      expect(openCodeServerService.validateCalls, isEmpty);
    });

    test("no-auto-start explicit port validates existing server and creates no ownership", () async {
      bridgeInstanceService.resolution = const BridgeInstanceResolution(
        status: BridgeInstanceResolutionStatus.allowed,
        existingBridges: <ProcessIdentity>[],
        terminatedBridges: <ProcessIdentity>[],
      );
      openCodeServerService.validateRuntime = OpenCodeServerRuntime(
        serverUri: Uri.parse("http://127.0.0.1:4096"),
        serverPassword: "existing-password",
        process: null,
        port: 4096,
        identity: null,
      );

      final runtime = await resolveServer(
        options: _options(port: 4096, noAutoStart: true, password: "existing-password"),
        currentBridgeIdentity: currentBridgeIdentity,
        ownerSessionId: "owner-session",
        startupMutexRepository: startupMutexRepository,
        ownershipRepository: ownershipRepository,
        bridgeInstanceService: bridgeInstanceService,
        openCodeServerService: openCodeServerService,
      );

      expect(openCodeServerService.startCalls, isEmpty);
      expect(openCodeServerService.validateCalls.single, equals((port: 4096, password: "existing-password")));
      expect(runtime.ownedOpenCodeRecord, isNull);
      expect(ownershipRepository.readOwnerSessionIds, isEmpty);
    });
  });
}

BridgeCliOptions _options({
  required int? port,
  required bool noAutoStart,
  String password = "",
}) {
  return BridgeCliOptions(
    cliArgs: const <String>["bridge"],
    relayUrl: "wss://relay.sesori.com",
    port: port,
    noAutoStart: noAutoStart,
    password: password,
    opencodeBin: "opencode",
    authBackendUrl: "https://api.sesori.com",
    forceLogin: false,
    debugPort: null,
    logLevelName: "info",
  );
}

ProcessIdentity _identity({required int pid, required String? startMarker}) {
  return ProcessIdentity(
    pid: pid,
    startMarker: startMarker,
    executablePath: "/usr/local/bin/sesori-bridge",
    commandLine: "/usr/local/bin/sesori-bridge",
    ownerUser: "alex",
    platform: "macos",
    capturedAt: DateTime.utc(2026, 5, 15, 12),
  );
}

OpenCodeOwnershipRecord _ownedRecord() {
  return OpenCodeOwnershipRecord(
    ownerSessionId: "owner-session",
    openCodePid: 300,
    openCodeStartMarker: "open-start",
    openCodeExecutablePath: "/usr/local/bin/opencode",
    openCodeCommand: "/usr/local/bin/opencode",
    openCodeArgs: const <String>["serve", "--port", "50123", "--hostname", "127.0.0.1"],
    port: 50123,
    bridgePid: 100,
    bridgeStartMarker: "bridge-start",
    startedAt: DateTime.utc(2026, 5, 15, 12),
    status: OpenCodeOwnershipStatus.ready,
  );
}

class _FakeStartupMutexRepository implements StartupMutexRepository {
  bool rejectLock = false;
  final List<({int pid, String? startMarker})> lockRequests = <({int pid, String? startMarker})>[];
  final List<String> operations = <String>[];

  @override
  Future<T> withLock<T>({
    required int bridgePid,
    required String? bridgeStartMarker,
    required Future<T> Function() onLockAcquired,
    required Future<T> Function(StartupMutexAcquireResult result) onLockRejected,
  }) async {
    lockRequests.add((pid: bridgePid, startMarker: bridgeStartMarker));
    operations.add("mutex.acquire");
    if (rejectLock) {
      return onLockRejected(StartupMutexAcquireResult.alreadyLocked);
    }
    return onLockAcquired();
  }
}

class _FakeOwnershipRepository implements OpenCodeOwnershipRepository {
  final Map<String, OpenCodeOwnershipRecord> recordByOwnerSessionId = <String, OpenCodeOwnershipRecord>{};
  final List<String> readOwnerSessionIds = <String>[];

  @override
  Future<void> deleteByOwnerSessionId({required String ownerSessionId}) async {}

  @override
  Future<List<OpenCodeOwnershipRecord>> readAll() async {
    return recordByOwnerSessionId.values.toList();
  }

  @override
  Future<OpenCodeOwnershipRecord?> readByOwnerSessionId({required String ownerSessionId}) async {
    readOwnerSessionIds.add(ownerSessionId);
    return recordByOwnerSessionId[ownerSessionId];
  }

  @override
  Future<void> upsert({required OpenCodeOwnershipRecord record}) async {
    recordByOwnerSessionId[record.ownerSessionId] = record;
  }
}

class _FakeBridgeInstanceService implements BridgeInstanceService {
  BridgeInstanceResolution resolution = const BridgeInstanceResolution(
    status: BridgeInstanceResolutionStatus.allowed,
    existingBridges: <ProcessIdentity>[],
    terminatedBridges: <ProcessIdentity>[],
  );
  final List<int> currentPids = <int>[];
  final List<String> operations = <String>[];

  @override
  Future<BridgeInstanceResolution> enforceSingleLiveBridge({required int currentPid}) async {
    currentPids.add(currentPid);
    operations.add("singleton.check");
    return resolution;
  }
}

class _FakeOpenCodeServerService implements OpenCodeServerService {
  OpenCodeServerRuntime? startRuntime;
  OpenCodeServerRuntime? validateRuntime;
  final List<
    ({String executablePath, int? requestedPort, String? password, List<ProcessIdentity> terminatedBridgeIdentities})
  >
  startCalls =
      <
        ({
          String executablePath,
          int? requestedPort,
          String? password,
          List<ProcessIdentity> terminatedBridgeIdentities,
        })
      >[];
  final List<({int port, String? password})> validateCalls = <({int port, String? password})>[];
  final List<String> operations = <String>[];

  @override
  Future<void> cleanupStaleOwnedServers({required Iterable<ProcessIdentity> terminatedBridgeIdentities}) async {}

  @override
  Future<OpenCodeServerRuntime> start({
    required String executablePath,
    required int? requestedPort,
    required String? password,
    required Iterable<ProcessIdentity> terminatedBridgeIdentities,
  }) async {
    operations.add("opencode.start");
    startCalls.add(
      (
        executablePath: executablePath,
        requestedPort: requestedPort,
        password: password,
        terminatedBridgeIdentities: terminatedBridgeIdentities.toList(),
      ),
    );
    return startRuntime ??
        OpenCodeServerRuntime(
          serverUri: Uri.parse("http://127.0.0.1:50123"),
          serverPassword: password,
          process: null,
          port: requestedPort ?? 50123,
          identity: null,
        );
  }

  @override
  Future<void> stopOwnedServer({required OpenCodeOwnershipRecord record}) async {}

  @override
  Future<OpenCodeServerRuntime> validateExistingServer({required int port, required String? password}) async {
    operations.add("opencode.validate");
    validateCalls.add((port: port, password: password));
    return validateRuntime ??
        OpenCodeServerRuntime(
          serverUri: Uri.parse("http://127.0.0.1:$port"),
          serverPassword: password,
          process: null,
          port: port,
          identity: null,
        );
  }
}
