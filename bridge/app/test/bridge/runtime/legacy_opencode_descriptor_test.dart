import "dart:async";

import "package:sesori_bridge/src/bridge/runtime/legacy_opencode_descriptor.dart";
import "package:sesori_bridge/src/server/models/open_code_ownership_record.dart";
import "package:sesori_bridge/src/server/repositories/open_code_ownership_repository.dart";
import "package:sesori_bridge/src/server/services/open_code_server_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show
        BridgeHostInfo,
        BridgePluginApi,
        HostJsonStore,
        HostPortService,
        HostProcessService,
        PluginConfig,
        PluginConfigException,
        PluginHost,
        PluginReady,
        PluginStatus,
        PluginStopped,
        PluginStopping,
        ProcessIdentity,
        ProcessUser,
        ServerClock,
        StartAbortSignal;
import "package:test/test.dart";

void main() {
  group("LegacyOpenCodeDescriptor config surface", () {
    test("rejects no-auto-start without a port as a usage error", () {
      expect(
        () => LegacyOpenCodeDescriptor.validateConfigValues(_config(port: null, noAutoStart: true)),
        throwsA(
          isA<PluginConfigException>().having((e) => e.message, "message", contains("--no-auto-start")),
        ),
      );
    });

    test("accepts no-auto-start with a port and plain auto-start", () {
      LegacyOpenCodeDescriptor.validateConfigValues(_config(port: 4096, noAutoStart: true));
      LegacyOpenCodeDescriptor.validateConfigValues(_config(port: null, noAutoStart: false));
    });
  });

  group("LegacyOpenCodeDescriptor.start", () {
    late _FakeOpenCodeServerService openCodeServerService;
    late _FakeOwnershipRepository ownershipRepository;
    late _FakePluginApi pluginApi;

    setUp(() {
      openCodeServerService = _FakeOpenCodeServerService();
      ownershipRepository = _FakeOwnershipRepository();
      pluginApi = _FakePluginApi();
    });

    LegacyOpenCodeDescriptor descriptor({List<ProcessIdentity> terminatedBridges = const []}) {
      return LegacyOpenCodeDescriptor(
        openCodeServerService: openCodeServerService,
        ownershipRepository: ownershipRepository,
        ownerSessionId: "owner-session",
        terminatedBridgeIdentities: terminatedBridges,
        buildPluginApi: ({required String serverUrl, required String? serverPassword}) {
          pluginApi.builds.add((serverUrl: serverUrl, serverPassword: serverPassword));
          return pluginApi;
        },
      );
    }

    test("auto-start starts OpenCode from config and keeps the ready ownership record", () async {
      openCodeServerService.startRuntime = OpenCodeServerRuntime(
        serverUri: Uri.parse("http://127.0.0.1:50123"),
        serverPassword: "generated-password",
        process: null,
        port: 50123,
        identity: null,
      );
      ownershipRepository.recordByOwnerSessionId["owner-session"] = _ownedRecord();
      final terminated = [_identity(pid: 200, startMarker: "old-start")];

      final plugin = await descriptor(terminatedBridges: terminated).start(_TestPluginHost(_config()));

      final startCall = openCodeServerService.startCalls.single;
      expect(startCall.executablePath, "opencode");
      expect(startCall.requestedPort, isNull);
      expect(startCall.password, isNull, reason: "empty --password normalizes to null");
      expect(startCall.terminatedBridgeIdentities.map((identity) => identity.pid), [200]);

      expect(plugin.serverUrl, "http://127.0.0.1:50123");
      expect(plugin.serverPassword, "generated-password");
      expect(plugin.port, 50123);
      expect(plugin.api, same(pluginApi));
      expect(
        pluginApi.builds.single,
        (serverUrl: "http://127.0.0.1:50123", serverPassword: "generated-password"),
      );
      expect(ownershipRepository.readOwnerSessionIds, ["owner-session"]);
      expect(plugin.describe().endpoint, "http://127.0.0.1:50123");
      expect(plugin.describe().details["mode"], "managed");
      expect(plugin.currentStatus, const PluginReady());
    });

    test("discards an ownership record that never reached ready", () async {
      ownershipRepository.recordByOwnerSessionId["owner-session"] = _ownedRecord(
        status: OpenCodeOwnershipStatus.starting,
      );

      final plugin = await descriptor().start(_TestPluginHost(_config()));

      expect(plugin.describe().details["mode"], "attached");
      await plugin.shutdown(budget: null);
      expect(openCodeServerService.stopRecords, isEmpty);
    });

    test("no-auto-start validates the existing server and owns nothing", () async {
      openCodeServerService.validateRuntime = OpenCodeServerRuntime(
        serverUri: Uri.parse("http://127.0.0.1:4096"),
        serverPassword: "existing-password",
        process: null,
        port: 4096,
        identity: null,
      );

      final plugin = await descriptor().start(
        _TestPluginHost(_config(port: 4096, noAutoStart: true, password: "existing-password")),
      );

      expect(openCodeServerService.startCalls, isEmpty);
      expect(openCodeServerService.validateCalls.single, (port: 4096, password: "existing-password"));
      expect(plugin.describe().details["mode"], "attached");
      expect(ownershipRepository.readOwnerSessionIds, isEmpty);
    });

    test("no-auto-start falls back to a degraded target when validation fails", () async {
      openCodeServerService.validateError = const OpenCodeServerStartException(
        "no server on port 4096",
        cause: null,
      );

      final plugin = await descriptor().start(
        _TestPluginHost(_config(port: 4096, noAutoStart: true, password: "existing-password")),
      );

      expect(plugin.serverUrl, "http://127.0.0.1:4096");
      expect(plugin.serverPassword, "existing-password");
      expect(plugin.port, 4096);
      expect(plugin.describe().details["mode"], "attached");
      await plugin.shutdown(budget: null);
      expect(openCodeServerService.stopRecords, isEmpty);
    });
  });

  group("LegacyOpenCodeBridgePlugin shutdown", () {
    late _FakePluginApi api;
    late List<OpenCodeOwnershipRecord> stopped;
    late List<String> operations;

    setUp(() {
      operations = [];
      api = _FakePluginApi(operations: () => operations);
      stopped = [];
    });

    LegacyOpenCodeBridgePlugin plugin({OpenCodeOwnershipRecord? record}) {
      return LegacyOpenCodeBridgePlugin(
        api: api,
        serverUrl: "http://127.0.0.1:50123",
        serverPassword: "secret",
        port: 50123,
        ownedOpenCodeRecord: record,
        stopOwnedServer: (record) async {
          operations.add("server.stop");
          stopped.add(record);
        },
      );
    }

    test("disposes the api before stopping the owned server", () async {
      await plugin(record: _ownedRecord()).shutdown(budget: const Duration(seconds: 10));

      expect(operations, ["api.dispose", "server.stop"]);
      expect(stopped.single.ownerSessionId, "owner-session");
    });

    test("is idempotent: repeated calls return the same future and run once", () async {
      final wrapper = plugin(record: _ownedRecord());

      final first = wrapper.shutdown(budget: null);
      final second = wrapper.shutdown(budget: null);
      await first;
      await second;

      expect(identical(first, second), isTrue);
      expect(operations, ["api.dispose", "server.stop"]);
    });

    test("stays safe when the orchestrator already disposed the api directly", () async {
      final wrapper = plugin(record: _ownedRecord());

      // Until PR 12 the orchestrator's finally calls dispose() on its own;
      // the wrapper's shutdown must tolerate running after it.
      await api.dispose();
      await wrapper.shutdown(budget: null);

      expect(operations, ["api.dispose", "api.dispose", "server.stop"]);
      expect(stopped, hasLength(1));
    });

    test("skips the server stop when this bridge owns no record", () async {
      await plugin().shutdown(budget: null);

      expect(operations, ["api.dispose"]);
    });

    test("emits Stopping then Stopped and closes the status stream", () async {
      final wrapper = plugin(record: _ownedRecord());
      final statuses = <PluginStatus>[];
      final done = Completer<void>();
      wrapper.status.listen(statuses.add, onDone: done.complete);

      await wrapper.shutdown(budget: null);
      await done.future;

      expect(statuses, const [PluginReady(), PluginStopping(), PluginStopped()]);
    });

    test("still stops the owned server when api dispose fails, then surfaces the error", () async {
      final wrapper = LegacyOpenCodeBridgePlugin(
        api: _ThrowingDisposeApi(),
        serverUrl: "http://127.0.0.1:50123",
        serverPassword: null,
        port: 50123,
        ownedOpenCodeRecord: _ownedRecord(),
        stopOwnedServer: (record) async => stopped.add(record),
      );

      await expectLater(wrapper.shutdown(budget: null), throwsA(isA<StateError>()));

      expect(stopped, hasLength(1), reason: "api teardown failure must not leak the owned opencode process");
      expect(wrapper.currentStatus, const PluginStopped());
    });

    test("still reaches Stopped when the server stop fails", () async {
      final wrapper = LegacyOpenCodeBridgePlugin(
        api: api,
        serverUrl: "http://127.0.0.1:50123",
        serverPassword: null,
        port: 50123,
        ownedOpenCodeRecord: _ownedRecord(),
        stopOwnedServer: (_) async => throw StateError("stop failed"),
      );

      await expectLater(wrapper.shutdown(budget: null), throwsA(isA<StateError>()));
      expect(wrapper.currentStatus, const PluginStopped());
    });
  });
}

PluginConfig _config({int? port, bool noAutoStart = false, String password = ""}) {
  return PluginConfig(
    values: {
      "port": port?.toString(),
      "no-auto-start": noAutoStart,
      "password": password,
      "opencode-bin": "opencode",
    },
  );
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

OpenCodeOwnershipRecord _ownedRecord({OpenCodeOwnershipStatus status = OpenCodeOwnershipStatus.ready}) {
  return OpenCodeOwnershipRecord(
    ownerSessionId: "owner-session",
    openCodePid: 300,
    openCodeStartMarker: "open-start",
    openCodeExecutablePath: "/usr/local/bin/opencode",
    openCodeCommand: "/usr/local/bin/opencode",
    openCodeArgs: const ["serve", "--port", "50123", "--hostname", "127.0.0.1"],
    port: 50123,
    bridgePid: 100,
    bridgeStartMarker: "bridge-start",
    startedAt: DateTime.utc(2026, 5, 15, 12),
    status: status,
  );
}

/// Host double for the legacy descriptor, which only reads [config] (its
/// collaborators are constructor-injected during the migration window).
class _TestPluginHost implements PluginHost {
  _TestPluginHost(this.config);

  @override
  final PluginConfig config;

  @override
  StartAbortSignal get startAborted => StartAbortSignal.never;

  @override
  String get stateDirectory => throw UnimplementedError();

  @override
  Map<String, String> get environment => throw UnimplementedError();

  @override
  ServerClock get clock => throw UnimplementedError();

  @override
  BridgeHostInfo get bridge => throw UnimplementedError();

  @override
  HostProcessService get processes => throw UnimplementedError();

  @override
  HostPortService get ports => throw UnimplementedError();

  @override
  HostJsonStore get store => throw UnimplementedError();
}

class _ThrowingDisposeApi implements BridgePluginApi {
  @override
  Future<void> dispose() async => throw StateError("dispose failed");

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePluginApi implements BridgePluginApi {
  _FakePluginApi({List<String> Function()? operations}) : _operations = operations;

  final List<String> Function()? _operations;
  final List<({String serverUrl, String? serverPassword})> builds = [];

  @override
  Future<void> dispose() async {
    _operations?.call().add("api.dispose");
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeOpenCodeServerService implements OpenCodeServerService {
  OpenCodeServerRuntime? startRuntime;
  OpenCodeServerRuntime? validateRuntime;
  OpenCodeServerStartException? validateError;

  final List<
    ({
      String executablePath,
      int? requestedPort,
      String? password,
      List<ProcessIdentity> terminatedBridgeIdentities,
    })
  >
  startCalls = [];
  final List<({int port, String? password})> validateCalls = [];
  final List<OpenCodeOwnershipRecord> stopRecords = [];

  @override
  Future<void> cleanupStaleOwnedServers({required Iterable<ProcessIdentity> terminatedBridgeIdentities}) async {}

  @override
  Future<OpenCodeServerRuntime> start({
    required String executablePath,
    required int? requestedPort,
    required String? password,
    required Iterable<ProcessIdentity> terminatedBridgeIdentities,
  }) async {
    startCalls.add((
      executablePath: executablePath,
      requestedPort: requestedPort,
      password: password,
      terminatedBridgeIdentities: List<ProcessIdentity>.from(terminatedBridgeIdentities),
    ));
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
  Future<void> stopOwnedServer({required OpenCodeOwnershipRecord record}) async {
    stopRecords.add(record);
  }

  @override
  Future<OpenCodeServerRuntime> validateExistingServer({required int port, required String? password}) async {
    validateCalls.add((port: port, password: password));
    final error = validateError;
    if (error != null) {
      throw error;
    }
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

class _FakeOwnershipRepository implements OpenCodeOwnershipRepository {
  final Map<String, OpenCodeOwnershipRecord> recordByOwnerSessionId = {};
  final List<String> readOwnerSessionIds = [];

  @override
  Future<void> deleteByOwnerSessionId({required String ownerSessionId}) async {}

  @override
  Future<List<OpenCodeOwnershipRecord>> readAll() async => recordByOwnerSessionId.values.toList();

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
