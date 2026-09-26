import "dart:async";
import "dart:convert";
import "dart:io";

import "package:opencode_plugin/src/v2/opencode_v2_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;
import "package:test/test.dart";

import "support/v2_fixtures.dart";

const _sessionId = "session-fixture";
const _directory = "/fixture/project";
const _form = <String, Object?>{
  "id": "form",
  "sessionID": _sessionId,
  "fields": [
    {"type": "integer", "key": "count", "minimum": 1, "maximum": 3},
  ],
};
const _permission = <String, Object?>{
  "id": "permission",
  "sessionID": _sessionId,
  "action": "shell",
  "resources": ["pwd"],
};

Future<T> _next<T extends BridgeSseEvent>({required OpenCodeV2Plugin plugin}) =>
    plugin.events.where((event) => event is T).cast<T>().first.timeout(const Duration(seconds: 5));

void main() {
  late _ServerFixture server;
  late OpenCodeV2Plugin plugin;
  setUp(() async {
    server = _ServerFixture(
      server: await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
      native: jsonDecodeMap(File("test/v2/fixtures/native_2_0_16.json").readAsStringSync()),
    );
    plugin = OpenCodeV2Plugin(serverUrl: server.url, password: "fixture", onConnected: () {}, onDisconnected: () {});
  });
  tearDown(() async {
    await plugin.dispose();
    await server.close();
  });

  test("shares initialization and buffers the hydrated baseline for the first listener", () async {
    server.snapshotGate = Completer<void>();
    final first = plugin.initialize();
    expect(plugin.initialize(), same(first));
    await server.snapshotEntered.future;
    expect(plugin.currentWorkState, PluginWorkState.unknown);
    expect(server.streams, isEmpty);
    server.snapshotGate!.complete();
    await first;
    await _next<BridgeSseProjectUpdated>(plugin: plugin);
    expect(server.snapshotReads, 1);
    expect(server.streams, hasLength(1));
    expect(plugin.currentWorkState, PluginWorkState.idle);
    expect(plugin.id, "opencode");
    expect(await plugin.healthCheck(), isTrue);
    expect((await plugin.getProjects()).single.id, _directory);
    expect((await plugin.getProject(_directory)).directory, _directory);
    expect((await plugin.getSessions(projectId: _directory, start: 0, limit: 1)).single.id, _sessionId);
    final options = await plugin.getSessionOptions(
      projectId: _directory,
      discoveryMode: PluginSessionOptionsDiscoveryMode.refresh,
    );
    expect((options as PluginSessionOptionsDiscoveryObserved).options.agents.single.name, "Build");
    expect(options.options.completeness, PluginSessionOptionsCompleteness.complete);
    expect(options.options.commands.single.name, "compact");
    await plugin.warmUpCommandCatalog();
    expect(await plugin.getQueuedPrompts(sessionId: _sessionId), isEmpty);
    expect(await plugin.cancelQueuedPrompt(sessionId: _sessionId, promptId: "fixture"), isFalse);
  });

  test("serializes enrichment before deltas and recovers after a malformed frame", () async {
    await plugin.initialize();
    final events = <BridgeSseEvent>[];
    final subscription = plugin.events.listen(events.add);
    addTearDown(subscription.cancel);
    server.agentGate = Completer<void>();
    final delta = _next<BridgeSseMessagePartDelta>(plugin: plugin);
    await server.emit(
      type: "session.step.started",
      data: {
        "assistantMessageID": "assistant",
        "agent": "build",
        "model": {"id": "model", "providerID": "provider"},
        "started": 1,
      },
    );
    await server.agentEntered.future;
    await server.raw(data: "{malformed fixture");
    await server.emit(
      type: "session.text.delta",
      data: {"assistantMessageID": "assistant", "ordinal": 0, "delta": "Fixture"},
    );
    expect(events.whereType<BridgeSseMessagePartDelta>(), isEmpty);
    server.agentGate!.complete();
    expect((await delta).delta, "Fixture");
    expect(events.whereType<BridgeSseMessageUpdated>().single.info.agent, "Build");
    expect(
      events.indexWhere((event) => event is BridgeSseMessageUpdated),
      lessThan(events.indexWhere((event) => event is BridgeSseMessagePartDelta)),
    );
  });

  test("cold-start failure is observable and first-connect recovery restores trust", () async {
    server.failFirstSnapshot = true;
    server.snapshotGate = Completer<void>();
    await expectLater(plugin.initialize(), throwsA(isA<PluginOperationException>()));
    await server.secondSnapshotEntered.future.timeout(const Duration(seconds: 5));
    expect(plugin.currentWorkState, PluginWorkState.unknown);
    final recovered = plugin.workState.firstWhere((state) => state == PluginWorkState.idle);
    server.snapshotGate!.complete();
    await recovered.timeout(const Duration(seconds: 5));
    expect(server.streams, hasLength(1));
  });

  test("reconnect refresh holds new frames until the complete snapshot replaces state", () async {
    await plugin.initialize();
    server.snapshotGate = Completer<void>();
    final events = <BridgeSseEvent>[];
    final subscription = plugin.events.listen(events.add);
    addTearDown(subscription.cancel);
    final delta = _next<BridgeSseMessagePartDelta>(plugin: plugin);
    await server.streams.single.close();
    await server.secondSnapshotEntered.future.timeout(const Duration(seconds: 5));
    expect(plugin.currentWorkState, PluginWorkState.unknown);
    await server.emit(
      type: "session.text.delta",
      data: {"assistantMessageID": "assistant", "ordinal": 0, "delta": "After refresh"},
    );
    expect(events.whereType<BridgeSseMessagePartDelta>(), isEmpty);
    server.snapshotGate!.complete();
    expect((await delta).delta, "After refresh");
    expect(plugin.currentWorkState, PluginWorkState.idle);
  });

  test("disposal during enrichment drops late publication and closes the event stream", () async {
    await plugin.initialize();
    final events = <BridgeSseEvent>[];
    final closed = Completer<void>();
    plugin.events.listen(events.add, onDone: closed.complete);
    server.agentGate = Completer<void>();
    await server.emit(
      type: "session.step.started",
      data: {
        "assistantMessageID": "assistant",
        "agent": "build",
        "model": {"id": "model", "providerID": "provider"},
        "started": 1,
      },
    );
    await server.agentEntered.future;
    server.allowClosedResponse = true;
    await plugin.dispose();
    await closed.future;
    server.agentGate!.complete();
    await server.agentAnswered.future;
    await pumpEventQueue();
    expect(events.whereType<BridgeSseMessageUpdated>(), isEmpty);
  });

  test("correlates prompt delivery and history without resurrecting busy on a late ACK", () async {
    await plugin.initialize();
    server.promptGate = Completer<void>();
    final sending = plugin.sendPrompt(
      sessionId: _sessionId,
      promptId: "fixture-prompt",
      parts: const [PluginPromptPart.text(text: "Fixture")],
      variant: null,
      fastMode: false,
      agent: null,
      model: null,
    );
    await server.promptEntered.future;
    final nativeId = server.promptBody!["id"]! as String;
    expect(nativeId, matches(RegExp(r"^msg_[0-9a-f]{12}[0-9A-Za-z]{14}_sesori_fixture-prompt$")));
    final busy = plugin.workState.firstWhere((state) => state == PluginWorkState.busy);
    await server.emit(type: "session.execution.started", data: {});
    await busy;
    final echo = _next<BridgeSseMessageUpdated>(plugin: plugin);
    await server.emit(type: "session.inbox.delivered", data: {"inboxID": nativeId});
    expect(((await echo).info as PluginMessageUser).promptId, "fixture-prompt");
    final idle = plugin.workState.firstWhere((state) => state == PluginWorkState.idle);
    await server.emit(type: "session.execution.succeeded", data: {});
    await idle;
    server.promptGate!.complete();
    await sending;
    expect(plugin.currentWorkState, PluginWorkState.idle);
    final history = await plugin.getSessionMessages(_sessionId);
    expect((history.single.info as PluginMessageUser).promptId, "fixture-prompt");
    server.failHistory = true;
    await expectLater(
      plugin.getSessionMessages(_sessionId),
      throwsA(isA<PluginOperationException>().having((e) => e.statusCode, "status", 503)),
    );
  });

  test("successful input replies update work state; a rejected write retains constraints", () async {
    server.forms = [_form];
    server.permissions = [_permission];
    await plugin.initialize();
    expect(plugin.currentWorkState, PluginWorkState.busy);
    expect(await plugin.getPendingQuestions(sessionId: _sessionId), hasLength(1));
    expect(await plugin.getPendingPermissions(sessionId: _sessionId), hasLength(1));
    server.failReplies = true;
    await expectLater(
      plugin.replyToQuestion(
        questionId: "form",
        sessionId: _sessionId,
        answers: [
          ["2"],
        ],
      ),
      throwsA(isA<PluginOperationException>()),
    );
    expect(await plugin.getPendingQuestions(sessionId: _sessionId), hasLength(1));
    server.failReplies = false;
    await plugin.replyToQuestion(
      questionId: "form",
      sessionId: _sessionId,
      answers: [
        ["2"],
      ],
    );
    expect(server.replyBody, {
      "answer": {"count": 2},
    });
    expect(await plugin.getPendingQuestions(sessionId: _sessionId), isEmpty);
    expect(plugin.currentWorkState, PluginWorkState.busy);
    await plugin.replyToPermission(requestId: "permission", sessionId: _sessionId, reply: PluginPermissionReply.once);
    expect(plugin.currentWorkState, PluginWorkState.idle);
  });

  test("managed interruption waits for native settlement rather than the interrupt ACK", () async {
    await plugin.initialize();
    final busy = plugin.workState.firstWhere((state) => state == PluginWorkState.busy);
    await server.emit(type: "session.execution.started", data: {});
    await busy;
    var settled = false;
    final stopping = plugin.interruptActiveWork(budget: const Duration(seconds: 5)).then((ids) {
      settled = true;
      return ids;
    });
    await server.interrupted.future;
    await pumpEventQueue();
    expect(settled, isFalse);
    await server.emit(type: "session.execution.succeeded", data: {});
    expect(await stopping, {_sessionId});
  });
}

class _ServerFixture({required final HttpServer server, required final Map<String, dynamic> native}) {
  late final StreamSubscription<HttpRequest> _subscription;
  final streams = <HttpResponse>[];
  final snapshotEntered = Completer<void>();
  final secondSnapshotEntered = Completer<void>();
  final agentEntered = Completer<void>();
  final agentAnswered = Completer<void>();
  final promptEntered = Completer<void>();
  final interrupted = Completer<void>();
  Completer<void>? snapshotGate;
  Completer<void>? agentGate;
  Completer<void>? promptGate;
  int snapshotReads = 0;
  bool failFirstSnapshot = false;
  bool failHistory = false;
  bool failReplies = false;
  bool allowClosedResponse = false;
  List<Map<String, Object?>> forms = [];
  List<Map<String, Object?>> permissions = [];
  Map<String, dynamic>? promptBody;
  Map<String, dynamic>? replyBody;

  this {
    _subscription = server.listen(_handle);
  }
  String get url => "http://127.0.0.1:${server.port}";
  Map<String, Object?> get user => {
    "id": promptBody!["id"],
    "type": "user",
    "text": promptBody!["text"],
    "time": {"created": 1},
  };

  Future<void> raw({required String data}) async {
    streams.last.write("data: $data\n\n");
    await streams.last.flush();
  }

  Future<void> emit({required String type, required Map<String, Object?> data}) => raw(
    data: jsonEncode({
      "id": "evt_fixture",
      "created": 2,
      "type": type,
      "location": {"directory": _directory},
      "data": {"sessionID": _sessionId, ...data},
    }),
  );

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    try {
      expect(
        request.headers.value(HttpHeaders.authorizationHeader),
        "Basic ${base64Encode(utf8.encode("opencode:fixture"))}",
      );
      request.response.headers.contentType = ContentType.json;
      if (path == "/api/event") {
        request.response.headers.set(HttpHeaders.contentTypeHeader, "text/event-stream");
        request.response.bufferOutput = false;
        streams.add(request.response);
        request.response.write(": fixture\n\n");
        await request.response.flush();
        return;
      }
      if (path == "/api/session") {
        if (++snapshotReads == 1) snapshotEntered.complete();
        if (snapshotReads == 2) secondSnapshotEntered.complete();
        if (snapshotReads == 1 && failFirstSnapshot) {
          request.response.statusCode = 503;
          await request.response.close();
          return;
        }
        await snapshotGate?.future;
      }
      if (path == "/api/agent") {
        if (!agentEntered.isCompleted) agentEntered.complete();
        await agentGate?.future;
      }
      if (path.endsWith("/prompt")) {
        promptBody = jsonDecodeMap(await utf8.decoder.bind(request).join());
        promptEntered.complete();
        await promptGate?.future;
        request.response.write(
          jsonEncode({
            "data": {
              "id": promptBody!["id"],
              "sessionID": _sessionId,
              "time": {"created": 1},
              "delivery": "queue",
              "payload": {"text": promptBody!["text"]},
            },
          }),
        );
      } else if (path.endsWith("/reply")) {
        replyBody = jsonDecodeMap(await utf8.decoder.bind(request).join());
        request.response.statusCode = failReplies ? 409 : 204;
      } else if (path.endsWith("/interrupt")) {
        request.response.write('{"interrupted":true}');
        interrupted.complete();
      } else if (path.contains("/message") && failHistory) {
        request.response.statusCode = 503;
      } else {
        final Object body = switch (path) {
          "/api/info" => {
            "version": native["version"],
            "pid": 1,
            "urls": <String>[],
            "paths": {"tmp": "/fixture/tmp"},
          },
          "/api/project" => [native["project"]],
          "/api/location" => v2LocationFixture,
          "/api/session" => {
            "data": [v2SessionFixture],
            "cursor": {"next": null},
          },
          "/api/session/active" => {"data": <String, Object?>{}},
          "/api/session/$_sessionId" => {"data": v2SessionFixture},
          "/api/agent" => {
            "data": [native["agent"]],
          },
          "/api/model" => {
            "data": [native["model"]],
          },
          "/api/provider" => {
            "data": [native["provider"]],
          },
          "/api/model/default" => {"data": native["model"]},
          "/api/form" => {"data": forms},
          "/api/permission/request" => {"data": permissions},
          "/api/session/$_sessionId/message" => {
            "data": [if (promptBody != null && !request.uri.queryParameters.containsKey("type")) user],
            "cursor": {"next": null},
          },
          _ when path.startsWith("/api/session/$_sessionId/message/") => {"data": user},
          _ => {"data": <Object?>[]},
        };
        request.response.write(jsonEncode(body));
      }
      await request.response.close();
    } on IOException {
      if (!allowClosedResponse) rethrow; // The disposal test deliberately closes this client's in-flight response.
    } finally {
      if (path == "/api/agent" && !agentAnswered.isCompleted) agentAnswered.complete();
    }
  }

  Future<void> close() async {
    for (final gate in [snapshotGate, agentGate, promptGate]) {
      if (gate != null && !gate.isCompleted) gate.complete();
    }
    await server.close(force: true);
    await _subscription.cancel();
  }
}
