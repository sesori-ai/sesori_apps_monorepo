import "dart:async";
import "dart:convert";

import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

class _PolicyPlugin({
  required super.id,
  required super.agentDisplayName,
  required super.launchSpec,
  required super.launchDirectory,
  required super.eventMapper,
  required super.childSessionTracker,
  required super.commandTracker,
  required super.sessionOptionsService,
  required super.processFactory,
  required final AcpResidencyPreference preference,
  required final AcpPendingRegistry<Object>? registry,
  required final AcpOutputInterceptors Function()? outputFactory,
}) extends TestAcpPlugin {
  @override
  AcpResidencyPreference get residencyPreference => preference;
  @override
  AcpOutputInterceptors createOutputInterceptors() => outputFactory?.call() ?? super.createOutputInterceptors();
  @override
  AcpPendingRegistry<Object> buildApprovalRegistry({required AcpStdioClient client}) =>
      registry ?? super.buildApprovalRegistry(client: client);
}

class _NeutralRegistry({required final List<String> settlements}) extends AcpPendingRegistry<String> {
  this
    : super(
        emit: (_) {},
        logContext: "test",
        idGenerator: null,
        resolvePermission: ({required payload, required reply}) => settlements.add("$payload:${reply.name}"),
        resolveQuestion: ({required payload, required answers}) => PendingQuestionReplyOutcome.rejected,
        rejectQuestion: ({required payload}) {},
        cancelPending: ({required payload, required reason}) => settlements.add("$payload:${reason.name}"),
      );
  final requests = <AcpServerRequest>[];
  final ambiguous = <AcpServerRequest>[];
  @override
  void rejectAmbiguousServerRequest({required AcpServerRequest request}) => ambiguous.add(request);
  @override
  void handleRequest(AcpServerRequest request) {
    requests.add(request);
    registerPendingPermission(
      payload: request.id.toString(),
      sessionId: request.params["sessionId"] as String,
      displaySessionId: null,
      tool: "test",
      description: "test",
      allowAlways: false,
    );
  }
}

_PolicyPlugin _compose({
  required AcpProcessFactory processFactory,
  required AcpResidencyPreference preference,
  required AcpPendingRegistry<Object>? registry,
  required AcpOutputInterceptors Function()? outputFactory,
}) {
  final config = AcpSessionConfigurationTracker();
  final commands = AcpCommandTracker();
  final children = AcpChildSessionTracker();
  return _PolicyPlugin(
    id: "test",
    agentDisplayName: "Test",
    launchDirectory: "/repo",
    launchSpec: const AcpLaunchSpec(command: "fake", args: [], includeParentEnvironment: false),
    eventMapper: AcpEventMapper(
      launchDirectory: "/repo",
      pluginId: "test",
      configurationTracker: config,
      childSessions: children,
    ),
    childSessionTracker: children,
    commandTracker: commands,
    sessionOptionsService: AcpSessionOptionsService(
      configurationTracker: config,
      commandTracker: commands,
      pluginId: "test",
      agentDisplayName: "Test",
    ),
    processFactory: processFactory,
    preference: preference,
    registry: registry,
    outputFactory: outputFactory,
  );
}

Future<void> _until({required bool Function() condition}) async {
  for (var i = 0; i < 400; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  throw StateError("Expected fake ACP activity did not arrive");
}

Future<Map<String, dynamic>> _frame({required FakeAcpProcess fake, required String method}) async {
  await _until(condition: () => fake.written.any((frame) => frame["method"] == method));
  return fake.written.lastWhere((frame) => frame["method"] == method);
}

Future<void> _handshake({required FakeAcpProcess fake, required bool load, required bool resume}) async {
  final init = await _frame(fake: fake, method: "initialize");
  fake.emit({
    "jsonrpc": "2.0",
    "id": init["id"],
    "result": {
      "protocolVersion": 1,
      "authMethods": <Object?>[],
      "agentCapabilities": {
        "loadSession": load,
        "sessionCapabilities": {if (resume) "resume": <String, dynamic>{}},
      },
    },
  });
}

void main() {
  for (final preference in AcpResidencyPreference.values) {
    for (final capabilities in [(true, true), (true, false), (false, true), (false, false)]) {
      test("$preference chooses an advertised residency method with capabilities $capabilities", () async {
        final fake = FakeAcpProcess();
        final plugin = _compose(
          processFactory: (_) async => fake,
          preference: preference,
          registry: null,
          outputFactory: null,
        );
        addTearDown(() async {
          await plugin.dispose();
          await fake.close();
        });
        plugin.primeSessionDirectory(sessionId: "old", directory: "/repo");
        final connecting = plugin.ensureConnected();
        await _handshake(fake: fake, load: capabilities.$1, resume: capabilities.$2);
        expect(await connecting, isTrue);
        final sending = plugin.sendPrompt(
          promptId: "p",
          sessionId: "old",
          parts: const [PluginPromptPart.text(text: "synthetic")],
          model: null,
          variant: null,
          agent: null,
        );
        final method = capabilities.$2 && (!capabilities.$1 || preference == AcpResidencyPreference.resumeFirst)
            ? "session/resume"
            : capabilities.$1
            ? "session/load"
            : null;
        if (method != null) {
          final activation = await _frame(fake: fake, method: method);
          fake.emit({
            "jsonrpc": "2.0",
            "id": activation["id"],
            "result": {"sessionId": "old"},
          });
        }
        final prompt = await _frame(fake: fake, method: "session/prompt");
        fake.emit({
          "jsonrpc": "2.0",
          "id": prompt["id"],
          "result": {"stopReason": "end_turn"},
        });
        await sending;
        expect(fake.written.where((f) => f["method"] == "session/load").length, method == "session/load" ? 1 : 0);
        expect(fake.written.where((f) => f["method"] == "session/resume").length, method == "session/resume" ? 1 : 0);
      });
    }
  }

  test("resume-first never retries an arbitrary error through load", () async {
    final fake = FakeAcpProcess();
    final plugin = _compose(
      processFactory: (_) async => fake,
      preference: AcpResidencyPreference.resumeFirst,
      registry: null,
      outputFactory: null,
    );
    addTearDown(() async {
      await plugin.dispose();
      await fake.close();
    });
    plugin.primeSessionDirectory(sessionId: "old", directory: "/repo");
    final connecting = plugin.ensureConnected();
    await _handshake(fake: fake, load: true, resume: true);
    await connecting;
    final sending = plugin.sendPrompt(
      promptId: "p",
      sessionId: "old",
      parts: const [PluginPromptPart.text(text: "synthetic")],
      model: null,
      variant: null,
      agent: null,
    );
    final resume = await _frame(fake: fake, method: "session/resume");
    fake.emit({
      "jsonrpc": "2.0",
      "id": resume["id"],
      "error": {"code": -32000, "message": "synthetic failure"},
    });
    final prompt = await _frame(fake: fake, method: "session/prompt");
    fake.emit({
      "jsonrpc": "2.0",
      "id": prompt["id"],
      "result": {"stopReason": "end_turn"},
    });
    await sending;
    expect(fake.written.where((f) => f["method"] == "session/load"), isEmpty);
  });

  test("recovered directories are hints beneath DB/live attribution without spawning a process", () async {
    var spawns = 0;
    final plugin = _compose(
      processFactory: (_) async {
        spawns++;
        return FakeAcpProcess();
      },
      preference: AcpResidencyPreference.loadFirst,
      registry: null,
      outputFactory: null,
    );
    addTearDown(plugin.dispose);
    plugin.primeSessionDirectory(sessionId: "db", directory: "/db");
    plugin.attributeSessionDirectory(sessionId: "live", directory: "/live");
    plugin.registerRecoveredSessionDirectories(
      batch: AcpSessionDirectoryBatch(directories: {"db": "/stale", "live": "/stale", "cold": "/cold/child/.."}),
    );
    expect(plugin.directoryForSession(sessionId: "db"), "/db");
    expect(plugin.directoryForSession(sessionId: "live"), "/live");
    expect(plugin.directoryForSession(sessionId: "cold"), "/cold");
    plugin.attributeSessionDirectory(sessionId: "cold", directory: "/fresh");
    expect(plugin.directoryForSession(sessionId: "cold"), "/fresh");
    expect(spawns, 0);
  });

  test("non-stock registry receives attributed requests, ambiguity and existing pending lifecycle", () async {
    final fake = FakeAcpProcess();
    final settlements = <String>[];
    final registry = _NeutralRegistry(settlements: settlements);
    final plugin = _compose(
      processFactory: (_) async => fake,
      preference: AcpResidencyPreference.loadFirst,
      registry: registry,
      outputFactory: null,
    );
    addTearDown(() async {
      await plugin.dispose();
      await fake.close();
    });
    final connecting = plugin.ensureConnected();
    await _handshake(fake: fake, load: true, resume: true);
    await connecting;
    plugin.handleAgentNotification(
      const AcpNotification(
        method: "session/update",
        params: {
          "sessionId": "s",
          "update": {"sessionUpdate": "tool_call", "toolCallId": "tool", "title": "Synthetic", "status": "pending"},
        },
      ),
    );
    fake.emit({
      "jsonrpc": "2.0",
      "id": 1,
      "method": "session/request_permission",
      "params": {"toolCallId": "tool"},
    });
    await _until(condition: () => registry.requests.isNotEmpty);
    expect(registry.requests.single.params["sessionId"], "s");
    final pending = await plugin.getPendingPermissions(sessionId: "s");
    await plugin.replyToPermission(requestId: pending.single.id, sessionId: "s", reply: PluginPermissionReply.once);
    expect(settlements, ["1:once"]);
    fake.emit({
      "jsonrpc": "2.0",
      "id": 2,
      "method": "session/request_permission",
      "params": {
        "toolCallId": "one",
        "toolCall": {"toolCallId": "two"},
      },
    });
    await _until(condition: () => registry.ambiguous.isNotEmpty);
    expect(registry.requests, hasLength(1));
    registry.handleServerRequest(
      request: const AcpServerRequest(id: 3, method: "session/request_permission", params: {"sessionId": "s"}),
    );
    registry.cancelForSession(sessionId: "s");
    expect(settlements.last, "3:sessionCancelled");
    registry.handleServerRequest(
      request: const AcpServerRequest(id: 4, method: "session/request_permission", params: {"sessionId": "s"}),
    );
    await plugin.dispose();
    expect(settlements.last, "4:disposed");
  });

  test("live and load-based replay each get fresh stdout/stderr interception", () async {
    final live = FakeAcpProcess();
    final replay = FakeAcpProcess();
    var spawns = 0;
    var policies = 0;
    final consumed = <String>[];
    final plugin = _compose(
      processFactory: (_) async => spawns++ == 0 ? live : replay,
      preference: AcpResidencyPreference.resumeFirst,
      registry: null,
      outputFactory: () {
        final generation = ++policies;
        AcpOutputInterceptor interceptor({required String stream}) => AcpOutputInterceptor(
          maxLineBytes: 4096,
          consumeLine: ({required line}) {
            if (!utf8.decode(line).contains("synthetic-hidden")) return false;
            consumed.add("$generation:$stream");
            return true;
          },
        );
        return (stdout: interceptor(stream: "stdout"), stderr: interceptor(stream: "stderr"));
      },
    );
    addTearDown(() async {
      await plugin.dispose();
      await live.close();
      await replay.close();
    });
    plugin.primeSessionDirectory(sessionId: "old", directory: "/repo");
    final connecting = plugin.ensureConnected();
    await _handshake(fake: live, load: true, resume: true);
    await connecting;
    live.emit({"synthetic-hidden": true});
    live.emitStderr(text: "synthetic-hidden\n");
    final history = plugin.getSessionMessages("old");
    await _handshake(fake: replay, load: true, resume: true);
    replay.emit({"synthetic-hidden": true});
    replay.emitStderr(text: "synthetic-hidden\n");
    final load = await _frame(fake: replay, method: "session/load");
    replay.emit({
      "jsonrpc": "2.0",
      "id": load["id"],
      "result": {"sessionId": "old"},
    });
    expect(await history, isEmpty);
    await _until(condition: () => consumed.length == 4);
    expect(policies, 2);
    expect(consumed.toSet(), {"1:stdout", "1:stderr", "2:stdout", "2:stderr"});
    expect(replay.written.where((f) => f["method"] == "session/resume"), isEmpty);
  });
}
