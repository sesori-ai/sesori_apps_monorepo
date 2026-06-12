import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:math";

import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:opencode_plugin/src/runtime/open_code_managed_api.dart";
import "package:opencode_plugin/src/runtime/open_code_plugin_descriptor.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("OpenCodePluginDescriptor static surface", () {
    const descriptor = OpenCodePluginDescriptor();

    test("declares the four OpenCode CLI options with the legacy names", () {
      expect(descriptor.id, equals("opencode"));
      expect(descriptor.displayName, equals("OpenCode"));
      expect(
        descriptor.options.map((o) => o.name).toList(),
        equals(<String>["port", "no-auto-start", "password", "opencode-bin"]),
      );
    });

    test("validateConfig requires --port when --no-auto-start is set", () {
      expect(
        () => descriptor.validateConfig(
          const PluginConfig(values: {"no-auto-start": true, "port": null, "password": "", "opencode-bin": "opencode"}),
        ),
        throwsA(isA<PluginConfigException>()),
      );
      expect(
        () => descriptor.validateConfig(
          const PluginConfig(values: {"no-auto-start": true, "port": "4096", "password": "", "opencode-bin": "opencode"}),
        ),
        returnsNormally,
      );
      expect(
        () => descriptor.validateConfig(
          const PluginConfig(values: {"no-auto-start": false, "port": null, "password": "", "opencode-bin": "opencode"}),
        ),
        returnsNormally,
      );
    });
  });

  group("OpenCodePluginDescriptor.start (managed)", () {
    late _FakeHost host;
    late _FakeApiRecorder apiRecorder;

    setUp(() {
      host = _FakeHost(
        config: const PluginConfig(
          values: {"port": null, "no-auto-start": false, "password": "", "opencode-bin": "/bin/opencode"},
        ),
      );
      apiRecorder = _FakeApiRecorder();
    });

    OpenCodePluginDescriptor descriptor({Object? initializeError}) {
      apiRecorder.initializeError = initializeError;
      return OpenCodePluginDescriptor(
        buildApi: apiRecorder.build,
        probeClientFactory: () => MockClient((_) async => http.Response("", 200)),
        candidatePorts: const <int>[51000],
        random: Random(1),
      );
    }

    test("spawns, owns, becomes Ready, and persists a ready record", () async {
      host.ports.defaultBindable = true;
      final plugin = await descriptor().start(host);

      expect(plugin.currentStatus, isA<PluginReady>());
      expect(plugin.port, equals(51000));
      expect(plugin.serverUrl, equals("http://127.0.0.1:51000"));
      expect(plugin.describe().details["mode"], equals("managed"));
      expect(plugin.describe().endpoint, equals("http://127.0.0.1:51000"));
      expect(apiRecorder.last!.initializeCalled, isTrue);
      expect(apiRecorder.last!.onConnected, isNotNull);

      final record = host.ownershipRecord("owner-current");
      expect(record, isNotNull);
      expect(record!["status"], equals("ready"));
      expect(record["port"], equals(51000));
      expect(record["openCodePid"], equals(4242));

      await plugin.shutdown(budget: null);
    });

    test("maps a cold-start failure to Degraded without failing the bridge", () async {
      host.ports.defaultBindable = true;
      final plugin = await descriptor(initializeError: StateError("cold start failed")).start(host);

      expect(plugin.currentStatus, isA<PluginDegraded>());
      // The runtime is still owned and recorded — only the api cold-start failed.
      expect(host.ownershipRecord("owner-current"), isNotNull);

      await plugin.shutdown(budget: null);
    });

    test("an unexpected child exit surfaces as Failed (restart disabled in PR 11)", () async {
      host.ports.defaultBindable = true;
      final plugin = await descriptor().start(host);
      expect(plugin.currentStatus, isA<PluginReady>());

      host.processes.spawnedProcesses.single.completeExit(1);
      await pumpEventQueue();

      expect(plugin.currentStatus, isA<PluginFailed>());
    });

    test("shutdown disposes the api, stops the owned runtime, and is idempotent", () async {
      host.ports.defaultBindable = true;
      final plugin = await descriptor().start(host);

      await plugin.shutdown(budget: null);
      await plugin.shutdown(budget: null);

      expect(apiRecorder.last!.disposeCount, equals(1));
      expect(plugin.currentStatus, isA<PluginStopped>());
      // The owned runtime was stopped: its ownership record is gone.
      expect(host.ownershipRecord("owner-current"), isNull);
    });

    test("a child exit after shutdown does not flip the status to Failed", () async {
      host.ports.defaultBindable = true;
      final plugin = await descriptor().start(host);
      final child = host.processes.spawnedProcesses.single;

      await plugin.shutdown(budget: null);
      child.completeExit(1);
      await pumpEventQueue();

      expect(plugin.currentStatus, isA<PluginStopped>());
    });

    test("an aborted start throws PluginStartAbortedException and leaves no record", () async {
      host.ports.defaultBindable = true;
      host.abort.abort();

      await expectLater(descriptor().start(host), throwsA(isA<PluginStartAbortedException>()));
      expect(host.ownershipRecord("owner-current"), isNull);
    });
  });

  group("OpenCodePluginDescriptor.start (attach / --no-auto-start)", () {
    late _FakeApiRecorder apiRecorder;

    setUp(() {
      apiRecorder = _FakeApiRecorder();
    });

    _FakeHost attachHost() => _FakeHost(
      config: const PluginConfig(
        values: {"port": "4096", "no-auto-start": true, "password": "", "opencode-bin": "opencode"},
      ),
    );

    test("attaches to a reachable server as Ready without owning it", () async {
      final host = attachHost();
      final descriptor = OpenCodePluginDescriptor(
        buildApi: apiRecorder.build,
        probeClientFactory: () => MockClient((_) async => http.Response("", 200)),
      );

      final plugin = await descriptor.start(host);

      expect(plugin.currentStatus, isA<PluginReady>());
      expect(plugin.port, equals(4096));
      expect(plugin.describe().details["mode"], equals("attached"));
      expect(host.ownershipRecord("owner-current"), isNull);
      expect(host.processes.spawnedProcesses, isEmpty);

      await plugin.shutdown(budget: null);
    });

    test("starts degraded but does not throw when the existing server is unreachable", () async {
      final host = attachHost();
      apiRecorder.initializeError = const SocketException("connection refused");
      final descriptor = OpenCodePluginDescriptor(
        buildApi: apiRecorder.build,
        probeClientFactory: () => MockClient((_) async => http.Response("nope", 503)),
      );

      final plugin = await descriptor.start(host);

      expect(plugin.currentStatus, isA<PluginDegraded>());
      expect(plugin.describe().details["mode"], equals("attached"));
      expect(host.ownershipRecord("owner-current"), isNull);

      await plugin.shutdown(budget: null);
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeApiRecorder {
  Object? initializeError;
  final List<_FakeManagedApi> built = <_FakeManagedApi>[];

  _FakeManagedApi? get last => built.isEmpty ? null : built.last;

  OpenCodeManagedApi build({
    required String serverUrl,
    required String? password,
    required void Function() onConnected,
    required void Function() onDisconnected,
  }) {
    final api = _FakeManagedApi(
      initializeError: initializeError,
      onConnected: onConnected,
      onDisconnected: onDisconnected,
    );
    built.add(api);
    return api;
  }
}

class _FakeManagedApi implements OpenCodeManagedApi {
  _FakeManagedApi({required this.initializeError, required this.onConnected, required this.onDisconnected});

  final Object? initializeError;
  final void Function() onConnected;
  final void Function() onDisconnected;
  bool initializeCalled = false;
  int disposeCount = 0;

  @override
  Future<void> initialize() async {
    initializeCalled = true;
    final error = initializeError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> dispose() async {
    disposeCount += 1;
  }

  @override
  String get id => "opencode";

  @override
  Stream<BridgeSseEvent> get events => const Stream<BridgeSseEvent>.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHost implements PluginHost {
  _FakeHost({required this.config});

  @override
  final PluginConfig config;

  @override
  final String stateDirectory = "/runtime";

  @override
  final Map<String, String> environment = const <String, String>{"PATH": "/usr/bin"};

  @override
  final ServerClock clock = const _ImmediateClock();

  final StartAbortController abort = StartAbortController();

  @override
  StartAbortSignal get startAborted => abort.signal;

  @override
  final _FakeBridgeHostInfo bridge = _FakeBridgeHostInfo();

  @override
  final _FakeHostProcessService processes = _FakeHostProcessService();

  @override
  final _FakePortService ports = _FakePortService();

  @override
  final _MemoryJsonStore store = _MemoryJsonStore();

  Map<String, dynamic>? ownershipRecord(String ownerSessionId) {
    final contents = store.files["opencode-processes.json"];
    if (contents == null) {
      return null;
    }
    final root = jsonDecode(contents) as Map<String, dynamic>;
    final record = root[ownerSessionId];
    return record == null ? null : Map<String, dynamic>.from(record as Map);
  }
}

class _ImmediateClock implements ServerClock {
  const _ImmediateClock();

  @override
  DateTime now() => DateTime.utc(2026, 6, 1, 12);

  @override
  Future<void> delay({required Duration duration}) async {}
}

class _FakeBridgeHostInfo implements BridgeHostInfo {
  @override
  ProcessIdentity get identity => ProcessIdentity(
    pid: 900,
    startMarker: "bridge-marker",
    executablePath: "/bin/sesori-bridge",
    commandLine: "sesori-bridge",
    ownerUser: null,
    platform: "macos",
    capturedAt: DateTime.utc(2026, 6, 1),
  );

  @override
  String get ownerSessionId => "owner-current";

  @override
  Future<bool> isLiveBridgeProcess({required int pid, required String? startMarker}) async => false;
}

class _FakePortService implements HostPortService {
  bool defaultBindable = true;
  final Map<int, bool> byPort = <int, bool>{};

  @override
  Future<bool> isBindable({required String host, required int port}) async => byPort[port] ?? defaultBindable;
}

class _FakeHostProcessService implements HostProcessService {
  final List<_FakeSpawnedProcess> spawnedProcesses = <_FakeSpawnedProcess>[];
  final List<String> signals = <String>[];
  int nextPid = 4242;

  @override
  Future<SpawnedProcess> spawn({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
  }) async {
    final process = _FakeSpawnedProcess(pid: nextPid, executablePath: executable);
    spawnedProcesses.add(process);
    return process;
  }

  @override
  Future<ProcessIdentity?> inspect({required int pid}) async => null;

  @override
  Future<List<ProcessIdentity>> list({required int? excludePid}) async => const <ProcessIdentity>[];

  @override
  Future<SignalResult> signalGraceful({required int pid}) async {
    signals.add("graceful:$pid");
    for (final process in spawnedProcesses) {
      if (process.pid == pid) {
        process.completeExit(0);
      }
    }
    return _signal(pid: pid, signal: ShutdownSignal.graceful);
  }

  @override
  Future<SignalResult> signalForce({required int pid}) async {
    signals.add("force:$pid");
    return _signal(pid: pid, signal: ShutdownSignal.force);
  }

  SignalResult _signal({required int pid, required ShutdownSignal signal}) {
    return SignalResult(
      pid: pid,
      requestedSignal: signal,
      deliveredSignal: signal == ShutdownSignal.graceful ? ProcessSignal.sigterm : ProcessSignal.sigkill,
      wasRequested: true,
      attemptedAt: DateTime.utc(2026, 6, 1),
    );
  }
}

class _FakeSpawnedProcess implements SpawnedProcess {
  _FakeSpawnedProcess({required this.pid, required String executablePath}) : _executablePath = executablePath;

  @override
  final int pid;

  final String _executablePath;
  final Completer<int> _exit = Completer<int>();

  void completeExit([int code = 0]) {
    if (!_exit.isCompleted) {
      _exit.complete(code);
    }
  }

  @override
  Future<int> get exitCode => _exit.future;

  @override
  ProcessIdentity get identity => ProcessIdentity(
    pid: pid,
    startMarker: null,
    executablePath: _executablePath,
    commandLine: "$_executablePath serve",
    ownerUser: null,
    platform: "macos",
    capturedAt: DateTime.utc(2026, 6, 1),
  );

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  Stream<List<int>> get stdout => Stream<List<int>>.value(const <int>[]);

  @override
  Stream<List<int>> get stderr => Stream<List<int>>.value(const <int>[]);
}

class _MemoryJsonStore implements HostJsonStore {
  final Map<String, String> files = <String, String>{};

  @override
  Future<String?> read({required String name}) async => files[name];

  @override
  Future<void> write({required String name, required String contents}) async {
    files[name] = contents;
  }

  @override
  Future<void> delete({required String name}) async {
    files.remove(name);
  }

  @override
  Future<void> quarantine({required String name, required String quarantinedName}) async {
    final contents = files.remove(name);
    if (contents != null) {
      files[quarantinedName] = contents;
    }
  }

  @override
  Future<String?> update({
    required String name,
    required FutureOr<String?> Function(String? current) transform,
  }) async {
    final next = await transform(files[name]);
    if (next == null) {
      files.remove(name);
    } else {
      files[name] = next;
    }
    return next;
  }
}
