import "dart:io";

import "package:sesori_bridge/src/bridge/runtime/bridge_runtime_server_exception.dart";
import "package:sesori_bridge/src/bridge/runtime/plugin_generation_factory.dart";
import "package:sesori_bridge/src/server/api/runtime_file_api.dart";
import "package:sesori_bridge/src/server/foundation/process_match.dart";
import "package:sesori_bridge/src/server/host/plugin_state_directory.dart";
import "package:sesori_bridge/src/server/models/bridge_startup_lock.dart";
import "package:sesori_bridge/src/server/repositories/process_repository.dart";
import "package:sesori_bridge/src/server/repositories/startup_mutex_repository.dart";
import "package:sesori_bridge/src/server/services/bridge_instance_service.dart";
import "package:sesori_bridge/src/updater/models/managed_runtime_paths.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

// The plugin-specific start flows (managed start, attach mode, ownership
// records) live with OpenCodePluginDescriptor in sesori_plugin_opencode;
// these tests cover the generation factory's mutex → singleton → host → start
// orchestration with a fake descriptor.
void main() {
  group("PluginGenerationFactory", () {
    late _FakeStartupMutexRepository startupMutexRepository;
    late _FakeBridgeInstanceService bridgeInstanceService;
    late _RecordingDescriptor descriptor;
    late ProcessIdentity currentBridgeIdentity;
    late Directory runtimeDirectory;
    late List<BridgePlugin> startedPlugins;

    setUp(() async {
      startupMutexRepository = _FakeStartupMutexRepository();
      bridgeInstanceService = _FakeBridgeInstanceService();
      descriptor = _RecordingDescriptor();
      currentBridgeIdentity = _identity(pid: 100, startMarker: "bridge-start");
      runtimeDirectory = await Directory.systemTemp.createTemp("bridge-runtime-server-test");
      startedPlugins = [];
    });

    tearDown(() async {
      for (final plugin in startedPlugins) {
        await plugin.shutdown(budget: const Duration(seconds: 1));
      }
      if (runtimeDirectory.existsSync()) {
        await runtimeDirectory.delete(recursive: true);
      }
    });

    Future<BridgePlugin> startPlugin({
      String? stateDirectory,
      List<RuntimeProvisionProgress>? observedProgress,
    }) async {
      final directory = stateDirectory ?? runtimeDirectory.path;
      final managedRuntimePaths = ManagedRuntimePaths(
        installRoot: directory,
        binaryPath: "$directory/bin/sesori-bridge",
        cacheDirectory: directory,
      );
      final factory = PluginGenerationFactory(
        managedRuntimePaths: managedRuntimePaths,
        currentBridgeIdentity: currentBridgeIdentity,
        ownerSessionId: "owner-session",
        startupMutexRepository: startupMutexRepository,
        bridgeInstanceService: bridgeInstanceService,
        processRepository: _FakeProcessRepository(),
        runtimeFileApi: RuntimeFileApi(runtimeDirectory: directory),
        clock: const ServerClock(),
        environment: const <String, String>{"HOME": "/home/alex"},
        currentUser: ProcessUser.fromRawUser("alex"),
      );
      BridgePlugin? startedPlugin;
      await for (final event in factory.start(
        registration: PluginRuntimeRegistration(
          descriptor: descriptor,
          config: const PluginConfig(values: <String, Object?>{"port": "4096"}),
          stateDirectory: pluginStateDirectoryPath(
            paths: managedRuntimePaths,
            pluginId: descriptor.id,
            stateStorage: descriptor.stateStorage,
          ),
        ),
        startAborted: StartAbortSignal.never,
      )) {
        switch (event) {
          case PluginGenerationProvisionProgress(:final event):
            observedProgress?.add(event);
          case PluginGenerationStarted(:final plugin):
            startedPlugin = plugin;
        }
      }
      final plugin = startedPlugin;
      if (plugin == null) throw StateError("Factory did not return a started plugin.");
      startedPlugins.add(plugin);
      return plugin;
    }

    test("allowed resolution starts the descriptor on a fully wired host", () async {
      final terminatedBridge = _identity(pid: 200, startMarker: "old-bridge-start");
      bridgeInstanceService.resolution = BridgeInstanceResolution(
        status: BridgeInstanceResolutionStatus.allowed,
        existingBridges: const <ProcessIdentity>[],
        terminatedBridges: <ProcessIdentity>[terminatedBridge],
      );

      final plugin = await startPlugin();

      expect(startupMutexRepository.lockRequests, hasLength(1));
      expect(startupMutexRepository.lockRequests.single, equals((pid: 100, startMarker: "bridge-start")));
      expect(bridgeInstanceService.currentPids, equals(<int>[100]));
      expect(
        <String>[
          ...startupMutexRepository.operations,
          ...bridgeInstanceService.operations,
          ...descriptor.operations,
        ],
        equals(<String>["mutex.acquire", "singleton.check", "descriptor.start"]),
      );
      expect(identical(plugin, descriptor.startedPlugin), isTrue);

      final host = descriptor.startedHosts.single;
      expect(host.config.value("port"), equals("4096"));
      expect(host.stateDirectory, equals("${runtimeDirectory.path}/plugins/fake"));
      expect(host.environment, containsPair("HOME", "/home/alex"));
      expect(host.bridge.identity.pid, equals(100));
      expect(host.bridge.ownerSessionId, equals("owner-session"));
      expect(
        host.bridge.terminatedBridgeIdentities.map((identity) => identity.pid),
        equals(<int>[200]),
        reason: "stale cleanup must be authorized to reclaim records of the bridge this one replaced",
      );
    });

    test("zero-plugin startup still performs single-live-bridge enforcement", () async {
      final factory = PluginGenerationFactory(
        managedRuntimePaths: ManagedRuntimePaths(
          installRoot: runtimeDirectory.path,
          binaryPath: "${runtimeDirectory.path}/bin/sesori-bridge",
          cacheDirectory: runtimeDirectory.path,
        ),
        currentBridgeIdentity: currentBridgeIdentity,
        ownerSessionId: "owner-session",
        startupMutexRepository: startupMutexRepository,
        bridgeInstanceService: bridgeInstanceService,
        processRepository: _FakeProcessRepository(),
        runtimeFileApi: RuntimeFileApi(runtimeDirectory: runtimeDirectory.path),
        clock: const ServerClock(),
        environment: const <String, String>{},
        currentUser: null,
      );
      await factory.enforceBridgeOwnership();

      expect(startupMutexRepository.lockRequests, hasLength(1));
      expect(bridgeInstanceService.currentPids, [currentBridgeIdentity.pid]);
      expect(descriptor.startedHosts, isEmpty);
    });

    test("the state directory exists before the descriptor starts", () async {
      final stateDirectory = "${runtimeDirectory.path}/nested/runtime";

      await startPlugin(stateDirectory: stateDirectory);

      expect(descriptor.stateDirectoryExistedAtStartLog.single, isTrue);
    });

    test("singleton decline aborts before the descriptor starts", () async {
      bridgeInstanceService.resolution = const BridgeInstanceResolution(
        status: BridgeInstanceResolutionStatus.declined,
        existingBridges: <ProcessIdentity>[],
        terminatedBridges: <ProcessIdentity>[],
      );

      await expectLater(
        startPlugin(),
        throwsA(
          isA<BridgeRuntimeServerException>().having(
            (error) => error.message,
            "message",
            contains("declined"),
          ),
        ),
      );

      expect(descriptor.startedHosts, isEmpty);
    });

    test("non-interactive singleton conflict aborts before the descriptor starts", () async {
      bridgeInstanceService.resolution = const BridgeInstanceResolution(
        status: BridgeInstanceResolutionStatus.nonInteractive,
        existingBridges: <ProcessIdentity>[],
        terminatedBridges: <ProcessIdentity>[],
      );

      await expectLater(
        startPlugin(),
        throwsA(
          isA<BridgeRuntimeServerException>().having(
            (error) => error.message,
            "message",
            contains("non-interactive"),
          ),
        ),
      );

      expect(descriptor.startedHosts, isEmpty);
    });

    test("mutex rejection aborts before singleton or descriptor work", () async {
      startupMutexRepository.rejectLock = true;
      startupMutexRepository.rejection = _startupLockRejection();
      bridgeInstanceService.startupLockStatus = BridgeInstanceResolutionStatus.declined;

      await expectLater(
        startPlugin(),
        throwsA(
          isA<BridgeRuntimeServerException>().having(
            (error) => error.message,
            "message",
            contains("already in progress"),
          ),
        ),
      );

      expect(bridgeInstanceService.currentPids, isEmpty);
      expect(descriptor.startedHosts, isEmpty);
    });

    test("mutex rejection with unidentifiable holder includes lock path recovery", () async {
      startupMutexRepository.rejectLock = true;
      startupMutexRepository.rejection = const StartupLockRejection(
        lock: null,
        holderMatch: null,
        lockFilePath: "/tmp/bridge-startup.lock",
      );

      await expectLater(
        startPlugin(),
        throwsA(
          isA<BridgeRuntimeServerException>().having(
            (error) => error.message,
            "message",
            allOf(contains("delete /tmp/bridge-startup.lock"), contains("already in progress")),
          ),
        ),
      );

      expect(bridgeInstanceService.startupLockContentionCalls, isEmpty);
    });

    test("startup lock takeover retries mutex and starts the descriptor", () async {
      startupMutexRepository.rejectSequence = <bool>[true, false];
      startupMutexRepository.rejection = _startupLockRejection();
      bridgeInstanceService.startupLockStatus = BridgeInstanceResolutionStatus.allowed;

      final plugin = await startPlugin();

      expect(identical(plugin, descriptor.startedPlugin), isTrue);
      expect(startupMutexRepository.lockRequests, hasLength(2));
      expect(bridgeInstanceService.startupLockContentionCalls.single.lock.bridgePid, equals(201));
      expect(bridgeInstanceService.currentPids, equals(<int>[100]));
    });

    test("startup lock replacement decline aborts with declined message", () async {
      startupMutexRepository.rejectLock = true;
      startupMutexRepository.rejection = _startupLockRejection();
      bridgeInstanceService.startupLockStatus = BridgeInstanceResolutionStatus.declined;

      await expectLater(
        startPlugin(),
        throwsA(
          isA<BridgeRuntimeServerException>().having(
            (error) => error.message,
            "message",
            contains("replacement was declined"),
          ),
        ),
      );
    });

    test("startup lock nonInteractive message includes pid and lock path", () async {
      startupMutexRepository.rejectLock = true;
      startupMutexRepository.rejection = _startupLockRejection(lockFilePath: "/tmp/start.lock");
      bridgeInstanceService.startupLockStatus = BridgeInstanceResolutionStatus.nonInteractive;

      await expectLater(
        startPlugin(),
        throwsA(
          isA<BridgeRuntimeServerException>().having(
            (error) => error.message,
            "message",
            allOf(contains("non-interactive"), contains("Bridge pid 201"), contains("/tmp/start.lock")),
          ),
        ),
      );
    });

    test("startup lock allowed but still locked on retry aborts without infinite loop", () async {
      startupMutexRepository.rejectSequence = <bool>[true, true];
      startupMutexRepository.rejection = _startupLockRejection();
      bridgeInstanceService.startupLockStatus = BridgeInstanceResolutionStatus.allowed;

      await expectLater(
        startPlugin(),
        throwsA(
          isA<BridgeRuntimeServerException>().having(
            (error) => error.message,
            "message",
            contains("still in progress after attempting replacement"),
          ),
        ),
      );

      expect(startupMutexRepository.lockRequests, hasLength(2));
    });

    test("a start aborted inside the descriptor settles as PluginStartAbortedException", () async {
      descriptor.startErrors.add(const PluginStartAbortedException());

      await expectLater(startPlugin(), throwsA(isA<PluginStartAbortedException>()));
    });

    group("runtime-resolution tee", () {
      test("emits each runtime-resolution event in order", () async {
        descriptor.provisionEvents.addAll(const <RuntimeProvisionProgress>[
          ProvisionResolving(),
          ProvisionDownloading(receivedBytes: 256, totalBytes: 1024),
          ProvisionReady(binaryPath: "/bin/opencode"),
        ]);
        final observed = <RuntimeProvisionProgress>[];

        await startPlugin(observedProgress: observed);

        expect(observed, equals(descriptor.provisionEvents));
      });

      test("teeing does not disturb the runner recording ProvisionReady.binaryPath on the host", () async {
        descriptor.provisionEvents.addAll(const <RuntimeProvisionProgress>[
          ProvisionResolving(),
          ProvisionReady(binaryPath: "/opt/opencode/bin/opencode"),
        ]);

        await startPlugin(observedProgress: <RuntimeProvisionProgress>[]);

        expect(descriptor.startedHosts.single.provisionedRuntimePath, equals("/opt/opencode/bin/opencode"));
      });

      test("standalone mode (no notifier) still records the resolved path with no tee", () async {
        descriptor.provisionEvents.add(const ProvisionReady(binaryPath: "/opt/opencode/bin/opencode"));

        // No provisionNotifier passed — the standalone/byte-identical path.
        await startPlugin();

        expect(descriptor.startedHosts.single.provisionedRuntimePath, equals("/opt/opencode/bin/opencode"));
      });
    });
  });
}

ProcessIdentity _identity({required int pid, required String? startMarker}) {
  return ProcessIdentity(
    pid: pid,
    startMarker: startMarker,
    executablePath: "/usr/local/bin/sesori-bridge",
    commandLine: "/usr/local/bin/sesori-bridge",
    ownerUser: ProcessUser.fromRawUser("alex"),
    platform: "macos",
    capturedAt: DateTime.utc(2026, 5, 15, 12),
  );
}

StartupLockRejection _startupLockRejection({String lockFilePath = "/tmp/bridge-startup.lock"}) {
  final holderIdentity = _identity(pid: 201, startMarker: "holder-start");
  return StartupLockRejection(
    lock: const BridgeStartupLock(bridgePid: 201, bridgeStartMarker: "holder-start"),
    holderMatch: ProcessMatch(
      identity: holderIdentity,
      kind: ProcessMatchKind.sesoriBridge,
      isCurrentUserProcess: true,
    ),
    lockFilePath: lockFilePath,
  );
}

/// Records the host every `start()` receives and returns a steady fake plugin,
/// so the tests can assert exactly what the runner wires up.
class _RecordingDescriptor extends BridgePluginDescriptor {
  _RecordingDescriptor();

  final List<PluginHost> startedHosts = <PluginHost>[];
  final List<String> operations = <String>[];
  final _FakeBridgePlugin startedPlugin = _FakeBridgePlugin();
  final List<bool> stateDirectoryExistedAtStartLog = <bool>[];

  /// When non-empty, `start()` throws the first entry instead of returning.
  final List<Object> startErrors = <Object>[];

  /// Emitted, in order, from `ensureRuntime()` before `start()`.
  final List<RuntimeProvisionProgress> provisionEvents = <RuntimeProvisionProgress>[];

  @override
  String get id => "fake";

  @override
  String get displayName => "Fake";

  @override
  PluginProjectOwnership get projectOwnership => PluginProjectOwnership.native;

  @override
  List<PluginOption> get options => const [];

  @override
  Stream<RuntimeProvisionProgress> ensureRuntime({required PluginHost host}) async* {
    for (final event in provisionEvents) {
      yield event;
    }
  }

  @override
  Future<BridgePlugin> start(PluginHost host) async {
    operations.add("descriptor.start");
    startedHosts.add(host);
    stateDirectoryExistedAtStartLog.add(Directory(host.stateDirectory).existsSync());
    if (startErrors.isNotEmpty) {
      throw startErrors.first;
    }
    return startedPlugin;
  }
}

class _FakeBridgePlugin implements BridgePlugin {
  final PluginStatusController _status = PluginStatusController(initial: const PluginReady());
  final BridgePluginApi _api = _FakeBridgePluginApi();

  @override
  BridgePluginApi get api => _api;

  @override
  Stream<PluginStatus> get status => _status.stream;

  @override
  PluginStatus get currentStatus => _status.current;

  @override
  PluginDiagnostics describe() {
    return const PluginDiagnostics(pluginId: "fake", endpoint: "http://127.0.0.1:1", details: {});
  }

  @override
  Future<void> shutdown({required Duration? budget}) async {}
}

class _FakeBridgePluginApi extends NativeProjectsPluginApi {
  @override
  String get id => "fake";

  @override
  Stream<BridgeSseEvent> get events => const Stream.empty();

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Never invoked in these tests: the host's process service is constructed
/// but the fake descriptor short-circuits before any process work.
class _FakeProcessRepository implements ProcessRepository {
  @override
  Future<int> startDetached({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
  }) async {
    throw UnimplementedError();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeStartupMutexRepository implements StartupMutexRepository {
  bool rejectLock = false;
  List<bool>? rejectSequence;
  StartupLockRejection? rejection;
  final List<({int pid, String? startMarker})> lockRequests = <({int pid, String? startMarker})>[];
  final List<String> operations = <String>[];

  @override
  Future<T> withLock<T>({
    required int bridgePid,
    required String? bridgeStartMarker,
    required Future<T> Function() onLockAcquired,
    required Future<T> Function(StartupLockRejection rejection) onLockRejected,
  }) async {
    lockRequests.add((pid: bridgePid, startMarker: bridgeStartMarker));
    operations.add("mutex.acquire");
    final shouldReject = rejectSequence?.removeAt(0) ?? rejectLock;
    if (shouldReject) {
      return onLockRejected(
        rejection ??
            const StartupLockRejection(
              lock: null,
              holderMatch: null,
              lockFilePath: "/tmp/bridge-startup.lock",
            ),
      );
    }
    return onLockAcquired();
  }
}

class _FakeBridgeInstanceService implements BridgeInstanceService {
  @override
  Future<void> awaitPredecessorBridgeExit({
    required int predecessorPid,
    required Duration timeout,
  }) async {}

  BridgeInstanceResolution resolution = const BridgeInstanceResolution(
    status: BridgeInstanceResolutionStatus.allowed,
    existingBridges: <ProcessIdentity>[],
    terminatedBridges: <ProcessIdentity>[],
  );
  final List<int> currentPids = <int>[];
  final List<String> operations = <String>[];
  BridgeInstanceResolutionStatus startupLockStatus = BridgeInstanceResolutionStatus.allowed;
  final List<({BridgeStartupLock lock, ProcessMatch holder, int currentPid})> startupLockContentionCalls =
      <({BridgeStartupLock lock, ProcessMatch holder, int currentPid})>[];

  @override
  Future<BridgeInstanceResolution> enforceSingleLiveBridge({required int currentPid}) async {
    currentPids.add(currentPid);
    operations.add("singleton.check");
    return resolution;
  }

  @override
  Future<List<ProcessIdentity>> terminateBridges({
    required int currentPid,
    required List<ProcessIdentity> existingBridges,
  }) async {
    operations.add("singleton.terminate");
    return existingBridges;
  }

  @override
  Future<BridgeInstanceResolutionStatus> resolveStartupLockContention({
    required BridgeStartupLock lock,
    required ProcessMatch holder,
    required int currentPid,
  }) async {
    startupLockContentionCalls.add((lock: lock, holder: holder, currentPid: currentPid));
    return startupLockStatus;
  }
}
