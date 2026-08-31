import "dart:async";
import "dart:convert";

import "package:pi_plugin/pi_plugin.dart";
import "package:pi_plugin/pi_testing.dart";
import "package:pi_plugin/src/api/pi_agent_tool_extension.dart";
import "package:pi_plugin/src/repositories/mappers/pi_history_mapper.dart";
import "package:pi_plugin/src/repositories/pi_session_process_repository.dart";
import "package:pi_plugin/src/trackers/pi_message_identity_tracker.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "support/pi_rpc_client_test_factory.dart";

void main() {
  test("generated source registers exactly the bridge-owned tools with strict schemas", () {
    const capability = PluginAgentToolMcpCapability(
      id: "opaque-id",
      url: "http://127.0.0.1:4321/mcp",
      bearerToken: "owner-only-token",
    );

    final source = const PiAgentToolExtensionSource().build(capability: capability);
    final registeredNames = RegExp(
      r'^    name: "([^"]+)",$',
      multiLine: true,
    ).allMatches(source).map((match) => match.group(1)).toList();

    expect(registeredNames, pluginAgentToolDefinitions.map((definition) => definition.tool.wireName));
    expect(RegExp(r"pi\.registerTool\(\{").allMatches(source), hasLength(3));
    for (final definition in pluginAgentToolDefinitions) {
      expect(source, contains("description: ${jsonEncode(definition.description)}"));
    }
    expect(source, contains("Type.Object({}, { additionalProperties: false })"));
    expect(
      source,
      contains(
        [
          'Type.Object({ deviceKey: Type.String({"minLength":1,"maxLength":512,',
          '"description":"Device key returned by list_simulators"}) }, { additionalProperties: false })',
        ].join(),
      ),
    );
    expect(source, contains('method: "tools/call"'));
    expect(source, contains('"Authorization": "Bearer " + bearerToken'));
    expect(source, contains('"MCP-Protocol-Version": "2025-06-18"'));
    expect(source, contains(capability.url));
    expect(source, contains(capability.bearerToken));
    expect(source, isNot(contains("backendSessionId")));
    expect(source, isNot(contains(capability.id)));
  });

  test("resident children receive isolated bound capabilities without secrets in argv", () async {
    final first = FakePiProcess();
    final second = FakePiProcess();
    final harness = _Harness(processes: [first, second]);
    addTearDown(harness.dispose);

    await Future.wait([
      harness.startResident(sessionId: "session-a", process: first),
      harness.startResident(sessionId: "session-b", process: second),
    ]);

    expect(harness.tools.provisionedBackendIds, containsAll(<String>["session-a", "session-b"]));
    expect(harness.specs, hasLength(2));
    expect(harness.specs.map((spec) => spec.extensionPath).toSet(), hasLength(2));
    for (var index = 0; index < harness.specs.length; index++) {
      final spec = harness.specs[index];
      final token = "owner-token-${index + 1}";
      expect(spec.arguments, containsAllInOrder(["--extension", spec.extensionPath]));
      expect(spec.arguments.join(" "), isNot(contains(token)));
      expect(harness.files.contents.values.singleWhere((contents) => contents.contains(token)), isNotEmpty);
    }
    for (final contents in harness.files.contents.values) {
      expect(contents, isNot(contains("session-a")));
      expect(contents, isNot(contains("session-b")));
    }
  });

  test("transient history clients do not provision or inject the extension", () async {
    final process = FakePiProcess();
    final harness = _Harness(processes: [process]);
    addTearDown(harness.dispose);

    final loading = harness.repository.loadHistory(sessionId: "session", knownDirectories: const {"/project"});
    final command = await waitForCommand(process: process, type: "get_entries");
    process.emitResponse(
      id: command["id"]! as String,
      command: "get_entries",
      data: const {"entries": <Object?>[], "leafId": null},
    );
    await loading;

    expect(harness.tools.provisionedBackendIds, isEmpty);
    expect(harness.files.contents, isEmpty);
    expect(harness.specs.single.extensionPath, isNull);
    expect(harness.specs.single.arguments, isNot(contains("--extension")));
  });

  test("failed resident startup deletes its file and revokes its capability", () async {
    final harness = _Harness(processes: const [], spawnError: StateError("spawn failed"));
    addTearDown(harness.dispose);

    await expectLater(
      harness.repository.ensureResident(
        sessionId: "session",
        knownDirectories: const {"/project"},
        model: null,
        variant: null,
      ),
      throwsA(anything),
    );

    expect(harness.files.contents, isEmpty);
    expect(harness.files.deleted, hasLength(1));
    expect(harness.tools.revokedIds, ["capability-1"]);
  });

  test("retains failed attachment cleanup for a later repository retry", () async {
    final process = FakePiProcess();
    final harness = _Harness(processes: [process]);
    await harness.startResident(sessionId: "session", process: process);
    harness.tools.revokeFailures = 1;
    harness.files.deleteFailures = 1;

    await expectLater(harness.repository.teardown(sessionId: "session"), throwsStateError);
    expect(harness.tools.revokedIds, isEmpty);
    expect(harness.files.contents, isNotEmpty);

    await harness.repository.dispose();
    expect(harness.tools.revokedIds, ["capability-1"]);
    expect(harness.files.contents, isEmpty);
    expect(harness.tools.revokeAttempts, 2);
    expect(harness.files.deleteAttempts, 2);
    await harness.closeProcesses();
  });

  test("retains failed startup rollback for disposal retry", () async {
    final harness = _Harness(processes: const [], spawnError: StateError("spawn failed"));
    harness.tools.revokeFailures = 1;
    harness.files.deleteFailures = 1;

    await expectLater(
      harness.repository.ensureResident(
        sessionId: "session",
        knownDirectories: const {"/project"},
        model: null,
        variant: null,
      ),
      throwsA(anything),
    );
    expect(harness.tools.revokedIds, isEmpty);
    expect(harness.files.contents, isNotEmpty);

    await harness.repository.dispose();
    expect(harness.tools.revokedIds, ["capability-1"]);
    expect(harness.files.contents, isEmpty);
  });

  test("zero-budget disposal still retries security attachment cleanup", () async {
    final process = FakePiProcess();
    final harness = _Harness(processes: [process]);
    await harness.startResident(sessionId: "session", process: process);
    harness.tools.revokeFailures = 1;
    harness.files.deleteFailures = 1;

    await harness.repository.dispose(shutdownBudget: Duration.zero);

    expect(harness.tools.revokedIds, ["capability-1"]);
    expect(harness.files.contents, isEmpty);
    expect(harness.tools.revokeAttempts, 2);
    expect(harness.files.deleteAttempts, 2);
    await harness.closeProcesses();
  });

  test("disposal waits for late attachment provisioning before its final drain", () async {
    final harness = _Harness(processes: const []);
    harness.tools.blockProvision();
    final connecting = harness.repository.ensureResident(
      sessionId: "session",
      knownDirectories: const {"/project"},
      model: null,
      variant: null,
    );
    await harness.tools.provisionStarted.future;
    harness.tools.revokeFailures = 1;
    harness.files.deleteFailures = 1;

    var disposed = false;
    final disposal = harness.repository.dispose(shutdownBudget: Duration.zero).then((_) => disposed = true);
    await pump();
    expect(disposed, isFalse);

    harness.tools.releaseProvision();
    await expectLater(connecting, throwsA(anything));
    await disposal;
    expect(disposed, isTrue);
    expect(harness.tools.revokedIds, ["capability-1"]);
    expect(harness.files.contents, isEmpty);
    expect(harness.tools.revokeAttempts, 2);
    expect(harness.files.deleteAttempts, 2);
  });

  test("a connection paused before provisioning cannot attach tools after disposal", () async {
    final harness = _Harness(processes: const []);
    harness.storage.blockResolve();
    final connecting = harness.repository.ensureResident(
      sessionId: "session",
      knownDirectories: const {"/project"},
      model: null,
      variant: null,
    );
    await harness.storage.resolveStarted.future;

    await harness.repository.dispose(shutdownBudget: Duration.zero);
    final failedConnection = expectLater(connecting, throwsA(isA<StateError>()));
    harness.storage.releaseResolve();
    await failedConnection;

    expect(harness.tools.provisionedBackendIds, isEmpty);
    expect(harness.files.contents, isEmpty);
  });

  test("teardown and repository dispose clean every resident generation", () async {
    final first = FakePiProcess();
    final second = FakePiProcess();
    final harness = _Harness(processes: [first, second]);

    await harness.startResident(sessionId: "first", process: first);
    await harness.repository.teardown(sessionId: "first");
    expect(harness.tools.revokedIds, ["capability-1"]);
    expect(harness.files.contents, isEmpty);

    await harness.startResident(sessionId: "second", process: second);
    await harness.repository.dispose();
    expect(harness.tools.revokedIds, ["capability-1", "capability-2"]);
    expect(harness.files.contents, isEmpty);
    await harness.closeProcesses();
  });

  test("process exit cleans the old generation before a replacement is retained", () async {
    final exited = FakePiProcess();
    final replacement = FakePiProcess();
    final harness = _Harness(processes: [exited, replacement]);
    addTearDown(harness.dispose);

    await harness.startResident(sessionId: "session", process: exited);
    final oldPath = harness.specs.single.extensionPath;
    exited.exit(code: 9);
    await _waitUntil(() => harness.tools.revokedIds.contains("capability-1"));

    await harness.startResident(sessionId: "session", process: replacement);
    expect(harness.specs.last.extensionPath, isNot(oldPath));
    expect(harness.tools.provisionedBackendIds, ["session", "session"]);
    expect(harness.tools.revokedIds, ["capability-1"]);
    expect(harness.files.contents, hasLength(1));
    expect(harness.files.contents.values.single, contains("owner-token-2"));
  });
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await pump();
  }
  throw StateError("condition was not reached");
}

final class _Harness({required final List<FakePiProcess> processes, final Object? spawnError}) {
  final _Tools tools = _Tools();
  final _PrivateFiles files = _PrivateFiles();
  final List<PiLaunchSpec> specs = [];
  final List<FakePiProcess> _spawnedProcesses = [];
  late final _Storage storage = _Storage();
  late final PiSessionProcessRepository repository = PiSessionProcessRepository(
    storageApi: storage,
    historyStorageApi: PiSessionHistoryStorageApi(storageApi: storage),
    binaryPath: "/runtime/pi",
    environment: const {},
    processFactory: ({required spec}) async {
      specs.add(spec);
      if (spawnError case final error?) throw error;
      final process = processes.removeAt(0);
      _spawnedProcesses.add(process);
      return process;
    },
    historyMapper: PiHistoryMapper(pluginId: "pi"),
    identityTracker: PiMessageIdentityTracker(pluginId: "pi"),
    startupExitTimeout: const Duration(milliseconds: 50),
    historyRpcTimeout: const Duration(seconds: 2),
    abortRpcTimeout: const Duration(seconds: 1),
    promptRpcTimeout: const Duration(seconds: 2),
    agentToolServices: _Services(tools: tools, privateFiles: files),
  );

  Future<void> startResident({required String sessionId, required FakePiProcess process}) async {
    final connecting = repository.ensureResident(
      sessionId: sessionId,
      knownDirectories: const {"/project"},
      model: null,
      variant: null,
    );
    final command = await waitForCommand(process: process, type: "get_entries");
    process.emitResponse(
      id: command["id"]! as String,
      command: "get_entries",
      data: const {"entries": <Object?>[], "leafId": null},
    );
    await connecting;
  }

  Future<void> closeProcesses() async {
    for (final process in [..._spawnedProcesses, ...processes]) {
      await process.close();
    }
  }

  Future<void> dispose() async {
    await repository.dispose();
    await closeProcesses();
  }
}

final class _Storage() implements PiSessionStorageApi {
  Completer<void> resolveStarted = Completer<void>();
  Completer<void>? _resolveGate;

  void blockResolve() {
    resolveStarted = Completer<void>();
    _resolveGate = Completer<void>();
  }

  void releaseResolve() {
    final gate = _resolveGate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<void> clearPendingNewSession({required String sessionId, required Set<String> knownDirectories}) async {}

  @override
  Future<PiResolvedSession> resolveSession({required String sessionId, required Set<String> knownDirectories}) async {
    if (!resolveStarted.isCompleted) resolveStarted.complete();
    await _resolveGate?.future;
    return PiResolvedSession(
      metadata: PiSessionMetadata(
        id: sessionId,
        cwd: "/project",
        parentId: null,
        title: null,
        createdAt: null,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
      path: "/sessions/$sessionId.jsonl",
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class const _Services({
  @override required final _Tools tools,
  @override required final _PrivateFiles privateFiles,
}) implements PluginAgentToolServices;

final class _Tools() implements PluginAgentToolHost {
  final List<String> provisionedBackendIds = [];
  final List<String> revokedIds = [];
  int revokeFailures = 0;
  int revokeAttempts = 0;
  Completer<void> provisionStarted = Completer<void>();
  Completer<void>? _provisionGate;

  void blockProvision() {
    provisionStarted = Completer<void>();
    _provisionGate = Completer<void>();
  }

  void releaseProvision() {
    final gate = _provisionGate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<PluginAgentToolMcpCapability> provisionMcp({required String? backendSessionId}) async {
    if (!provisionStarted.isCompleted) provisionStarted.complete();
    await _provisionGate?.future;
    provisionedBackendIds.add(backendSessionId!);
    final sequence = provisionedBackendIds.length;
    return PluginAgentToolMcpCapability(
      id: "capability-$sequence",
      url: "http://127.0.0.1:4321/mcp",
      bearerToken: "owner-token-$sequence",
    );
  }

  @override
  Future<void> revokeMcp({required PluginAgentToolMcpCapability capability}) async {
    revokeAttempts++;
    if (revokeFailures > 0) {
      revokeFailures--;
      throw StateError("revoke failed");
    }
    revokedIds.add(capability.id);
  }

  @override
  Future<void> bindMcp({
    required PluginAgentToolMcpCapability capability,
    required String backendSessionId,
  }) async => throw StateError("capabilities must be provisioned already bound");

  @override
  Future<void> dispose() async {}

  @override
  Future<Map<String, dynamic>> invoke({
    required String backendSessionId,
    required PluginAgentTool tool,
    required Map<String, dynamic> arguments,
  }) async => throw UnsupportedError("native invocation is not used by Pi");
}

final class _PrivateFiles() implements PluginPrivateFileService {
  final Map<String, String> contents = {};
  final List<String> deleted = [];
  int deleteFailures = 0;
  int deleteAttempts = 0;

  @override
  Future<String> write({required String name, required String contents}) async {
    this.contents[name] = contents;
    return "/private/$name";
  }

  @override
  Future<void> delete({required String name}) async {
    deleteAttempts++;
    if (deleteFailures > 0) {
      deleteFailures--;
      throw StateError("delete failed");
    }
    contents.remove(name);
    deleted.add(name);
  }
}
