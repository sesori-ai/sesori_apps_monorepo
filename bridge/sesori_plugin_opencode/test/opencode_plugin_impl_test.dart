import "dart:async";
import "dart:convert";
import "dart:io";

import "package:opencode_plugin/opencode_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("OpenCodePlugin", () {
    late _FakeOpenCodeServer server;

    setUp(() async {
      server = _FakeOpenCodeServer();
      await server.start();
    });

    tearDown(() async {
      await server.close();
    });

    test("id returns opencode", () {
      final plugin = OpenCodePlugin(serverUrl: server.baseUrl);
      expect(plugin.id, equals("opencode"));
    });

    test("getProjects maps internal projects to plugin projects", () async {
      final plugin = OpenCodePlugin(serverUrl: server.baseUrl);

      final projects = await plugin.getProjects();

      expect(projects, hasLength(2));

      final real = projects.firstWhere((p) => p.id == "/repo");
      expect(real.id, equals("/repo"));
      expect(real.name, equals("Main Repo"));

      final virtual = projects.firstWhere((p) => p.id == "/virtual");
      expect(virtual.name, equals("virtual"));
    });

    test("getSessions maps internal sessions to plugin sessions", () async {
      final plugin = OpenCodePlugin(serverUrl: server.baseUrl);

      final sessions = await plugin.getSessions("/repo");

      expect(sessions, hasLength(2));

      final root = sessions.firstWhere((session) => session.id == "s-root");
      expect(root.projectID, equals("/repo"));
      expect(root.directory, equals("/repo"));
      expect(root.parentID, isNull);
      expect(root.time?.created, equals(100));
      expect(root.time?.updated, equals(200));

      final child = sessions.firstWhere((session) => session.id == "s-child");
      expect(child.projectID, equals("/repo"));
      expect(child.directory, equals("/repo/packages/foo"));
      expect(child.parentID, isNull);
    });

    test("getCommands delegates through service and returns plugin commands", () async {
      final plugin = OpenCodePlugin(serverUrl: server.baseUrl);

      final commands = await plugin.getCommands(projectId: "/repo");

      expect(commands, hasLength(1));
      expect(commands.single.name, equals("/review-work"));
      expect(commands.single.source, equals(PluginCommandSource.skill));
    });

    test("createSession creates the session then sends the first prompt", () async {
      final plugin = OpenCodePlugin(serverUrl: server.baseUrl);
      await server.waitForSseConnection();
      server.requestLog.clear();

      final session = await plugin.createSession(
        directory: "/repo",
        parentSessionId: "s-root",
        parts: const [PluginPromptPart.text(text: "Start from here")],
        agent: "build",
        model: (providerID: "openai", modelID: "gpt-5.4"),
      );

      expect(session.id, equals("s-created"));
      expect(session.projectID, equals("/repo"));
      expect(
        server.requestLog,
        equals(["POST /session", "POST /session/s-created/prompt_async"]),
      );
      expect(server.lastCreatedSessionParentId, equals("s-root"));
      expect(server.lastPromptBody?['agent'], equals('build'));
      expect(server.lastPromptBody?['model'], equals({"providerID": "openai", "modelID": "gpt-5.4"}));
    });

    test("sendPrompt resolves tracked directory before sending", () async {
      final plugin = OpenCodePlugin(serverUrl: server.baseUrl);
      await server.waitForSseConnection();
      server.requestLog.clear();

      await plugin.sendPrompt(
        sessionId: "s-root",
        parts: const [PluginPromptPart.text(text: "Continue")],
        agent: null,
        model: null,
      );

      expect(server.requestLog, equals(["POST /session/s-root/prompt_async"]));
      expect(server.lastPromptDirectoryHeader, equals("/repo"));
      expect(server.lastPromptBody?['parts'], equals([{"type": "text", "text": "Continue"}]));
    });

    test("sendCommand resolves tracked directory before sending", () async {
      final plugin = OpenCodePlugin(serverUrl: server.baseUrl);
      await server.waitForSseConnection();
      server.requestLog.clear();

      await plugin.sendCommand(
        sessionId: "s-root",
        command: "/review-work",
        arguments: "recent changes",
        agent: "reviewer",
        model: (providerID: "openai", modelID: "gpt-4.1"),
      );

      expect(server.requestLog, equals(["POST /session/s-root/command"]));
      expect(server.lastCommandDirectoryHeader, equals("/repo"));
      expect(
        server.lastCommandBody,
        equals({
          "command": "/review-work",
          "arguments": "recent changes",
          "agent": "reviewer",
          "model": "openai/gpt-4.1",
        }),
      );
    });

    test("getSessionMessages maps raw messages to plugin messages", () async {
      final plugin = OpenCodePlugin(serverUrl: server.baseUrl);

      final messages = await plugin.getSessionMessages("ses-1");

      expect(messages, hasLength(2));
      final user = messages.first;
      expect(user.info, isA<PluginMessageUser>());
      expect(user.info.id, equals("m-user"));
      expect(user.info.sessionID, equals("ses-1"));

      final assistant = messages.last;
      expect(assistant.info, isA<PluginMessageAssistant>());
      expect(assistant.info.id, equals("m-assistant"));
      expect((assistant.info as PluginMessageAssistant).modelID, equals("gpt"));
      expect((assistant.info as PluginMessageAssistant).providerID, equals("openai"));
    });

    test("getSessionMessages filters file and snapshot parts", () async {
      final plugin = OpenCodePlugin(serverUrl: server.baseUrl);

      final messages = await plugin.getSessionMessages("ses-filter");

      expect(messages, hasLength(2));
      final parts = messages.last.parts;
      expect(
        parts.map((part) => part.type).toList(),
        equals([PluginMessagePartType.text, PluginMessagePartType.tool, PluginMessagePartType.reasoning]),
      );
    });

    test("getSessionMessages filters patch and compaction parts", () async {
      final plugin = OpenCodePlugin(serverUrl: server.baseUrl);

      final messages = await plugin.getSessionMessages("ses-new-parts-filter");

      expect(messages, hasLength(2));
      final parts = messages.last.parts;
      expect(
        parts.map((part) => part.type).toList(),
        equals([PluginMessagePartType.text]),
      );
    });

    test("getSessionMessages agent part carries agentName", () async {
      final plugin = OpenCodePlugin(serverUrl: server.baseUrl);

      final messages = await plugin.getSessionMessages("ses-agent-part");

      expect(messages, hasLength(2));
      final part = messages.last.parts.single;
      expect(part.type, equals(PluginMessagePartType.agent));
      expect(part.agentName, equals("explore"));
    });

    test("getSessionMessages retry part carries attempt and retryError", () async {
      final plugin = OpenCodePlugin(serverUrl: server.baseUrl);

      final messages = await plugin.getSessionMessages("ses-retry-part");

      expect(messages, hasLength(2));
      final part = messages.last.parts.single;
      expect(part.type, equals(PluginMessagePartType.retry));
      expect(part.attempt, equals(2));
      expect(part.retryError, equals("Rate limited"));
    });

    test("getSessionMessages truncates tool output to 500 chars", () async {
      final plugin = OpenCodePlugin(serverUrl: server.baseUrl);

      final messages = await plugin.getSessionMessages("ses-tool-long");

      expect(messages, hasLength(2));
      final output = messages.last.parts.single.state?.output;
      expect(output, isNotNull);
      expect(output!.length, lessThanOrEqualTo(500));
      expect(output.length, equals(500));
    });

    test("getSessionMessages keeps short tool output unchanged", () async {
      final plugin = OpenCodePlugin(serverUrl: server.baseUrl);

      final messages = await plugin.getSessionMessages("ses-tool-short");

      expect(messages, hasLength(2));
      expect(messages.last.parts.single.state?.output, equals("short"));
    });

    test("getProviders with connectedOnly false returns all providers", () async {
      final plugin = OpenCodePlugin(serverUrl: server.baseUrl);

      final result = await plugin.getProviders(connectedOnly: false);

      expect(result.providers, hasLength(2));

      final anthropic = result.providers.firstWhere((p) => p.id == "anthropic");
      expect(anthropic, isA<PluginProviderAnthropic>());
      expect(anthropic.name, equals("Anthropic"));
      expect(anthropic.authType, equals(PluginProviderAuthType.apiKey));
      expect(anthropic.models, hasLength(2));
      expect(anthropic.defaultModelID, equals("claude-3-sonnet"));

      final opus = anthropic.models.firstWhere((m) => m.id == "claude-3-opus");
      expect(opus.name, equals("Claude 3 Opus"));
      expect(opus.family, equals("claude-3"));
      expect(opus.isAvailable, isTrue);
      expect(opus.releaseDate, equals(DateTime(2025, 3, 15)));

      final sonnet = anthropic.models.firstWhere((m) => m.id == "claude-3-sonnet");
      expect(sonnet.name, equals("Claude 3 Sonnet"));
      expect(sonnet.family, equals("claude-3"));
      expect(sonnet.isAvailable, isFalse);
      expect(sonnet.releaseDate, equals(DateTime(2024, 6, 1)));

      final custom = result.providers.firstWhere((p) => p.id == "my-custom");
      expect(custom, isA<PluginProviderCustom>());
      expect(custom.name, equals("My Custom Provider"));
      expect(custom.authType, equals(PluginProviderAuthType.unknown));
    });

    test("getProviders with connectedOnly true filters to connected", () async {
      final plugin = OpenCodePlugin(serverUrl: server.baseUrl);

      final result = await plugin.getProviders(connectedOnly: true);

      expect(result.providers, hasLength(1));
      expect(result.providers.single.id, equals("anthropic"));
    });

    test("getProviders maps known provider IDs to correct union variants", () async {
      final plugin = OpenCodePlugin(serverUrl: server.baseUrl);

      final result = await plugin.getProviders(connectedOnly: false);

      final anthropic = result.providers.firstWhere((p) => p.id == "anthropic");
      expect(anthropic, isA<PluginProviderAnthropic>());

      final custom = result.providers.firstWhere((p) => p.id == "my-custom");
      expect(custom, isA<PluginProviderCustom>());
    });

    test("events stream emits bridge events", () async {
      final plugin = OpenCodePlugin(serverUrl: server.baseUrl);

      // Wait for the actual event instead of a blind delay.
      // _initialize() emits BridgeSseProjectUpdated after coldStart().
      await expectLater(
        plugin.events,
        emitsThrough(isA<BridgeSseProjectUpdated>()),
      );
    });

    test("unknown and malformed SSE frames are ignored without emitting bridge events", () async {
      final plugin = OpenCodePlugin(serverUrl: server.baseUrl);
      await server.waitForSseConnection();

      final events = <BridgeSseEvent>[];
      final initialProjectUpdated = Completer<void>();
      final subscription = plugin.events.listen((event) {
        events.add(event);
        if (event is BridgeSseProjectUpdated && !initialProjectUpdated.isCompleted) {
          initialProjectUpdated.complete();
        }
      });
      addTearDown(subscription.cancel);

      await initialProjectUpdated.future;
      events.clear();

      await server.emitRawSse(
        '{"directory":"/repo","payload":{"type":"unknown.event","properties":{}}}',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(events, isEmpty);

      expect(
        formatDroppedSseFrameLog(
          category: "unknown-event-type",
          message: "Ignoring SSE frame with unknown event type.",
          directory: "/repo",
          eventType: "unknown.event",
        ),
        equals(
          "[opencode][sse][unknown-event-type] [directory=/repo, eventType=unknown.event] Ignoring SSE frame with unknown event type.",
        ),
      );

      await server.emitRawSse("{not-json");
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(events, isEmpty);
    });

    test("sync SSE frames are swallowed without emitting bridge events", () async {
      final plugin = OpenCodePlugin(serverUrl: server.baseUrl);
      await server.waitForSseConnection();

      final events = <BridgeSseEvent>[];
      final initialProjectUpdated = Completer<void>();
      final subscription = plugin.events.listen((event) {
        events.add(event);
        if (event is BridgeSseProjectUpdated && !initialProjectUpdated.isCompleted) {
          initialProjectUpdated.complete();
        }
      });
      addTearDown(subscription.cancel);

      await initialProjectUpdated.future;
      events.clear();

      await server.emitRawSse(
        jsonEncode({
          "directory": "/repo",
          "payload": {
            "type": "sync",
            "name": "message.updated.1",
            "id": "evt-1",
            "seq": 7,
            "aggregateID": "sessionID",
            "data": {
              "sessionID": "s1",
            },
          },
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(events, isEmpty);
    });

    test("drop log formatting includes event type when present", () {
      expect(
        formatDroppedSseFrameLog(
          category: "malformed-known-payload",
          message: "Ignoring malformed payload for known SSE event.",
          directory: "/repo",
          eventType: "session.status",
        ),
        equals(
          "[opencode][sse][malformed-known-payload] [directory=/repo, eventType=session.status] Ignoring malformed payload for known SSE event.",
        ),
      );
    });

    test("getSessionStatuses merges tracker data with API response", () async {
      // Use a configurable server: cold start sees the full status map
      // (including a busy child), but subsequent API calls return only
      // the root session — simulating OpenCode's directory-scoped response.
      final dynamicServer = _DynamicStatusServer();
      await dynamicServer.start();
      addTearDown(dynamicServer.close);

      // During cold start, the tracker ingests the busy child status.
      dynamicServer.sessionStatuses = {
        "s-root": {"type": "idle"},
        "child-1": {"type": "busy"},
      };

      final plugin = OpenCodePlugin(serverUrl: dynamicServer.baseUrl);
      await dynamicServer.waitForSseConnection();

      // Now change the API response to omit the child — as if OpenCode
      // scoped /session/status by directory on subsequent calls.
      dynamicServer.sessionStatuses = {
        "s-root": {"type": "idle"},
      };

      final statuses = await plugin.getSessionStatuses();

      // API-returned status is preserved.
      expect(statuses["s-root"], isA<PluginSessionStatusIdle>());
      // The tracker's SSE-maintained busy status fills in the gap the
      // scoped API response left — this is the fix for the cold-load bug.
      expect(statuses["child-1"], isA<PluginSessionStatusBusy>());
    });

    test("getSessionStatuses tracker overrides stale API idle", () async {
      final dynamicServer = _DynamicStatusServer();
      await dynamicServer.start();
      addTearDown(dynamicServer.close);

      // Cold start: root is busy in the tracker.
      dynamicServer.sessionStatuses = {
        "s-root": {"type": "busy"},
      };

      final plugin = OpenCodePlugin(serverUrl: dynamicServer.baseUrl);
      await dynamicServer.waitForSseConnection();

      // API now returns idle — stale relative to the tracker.
      dynamicServer.sessionStatuses = {
        "s-root": {"type": "idle"},
      };

      final statuses = await plugin.getSessionStatuses();

      // Tracker's busy overrides the API's stale idle.
      expect(statuses["s-root"], isA<PluginSessionStatusBusy>());
    });

    group("renameSession", () {
      test("sends PATCH with title body and returns updated session", () async {
        final plugin = OpenCodePlugin(serverUrl: server.baseUrl);
        await server.waitForSseConnection();
        server.requestLog.clear();

        final session = await plugin.renameSession(sessionId: "s-root", title: "New Title");

        expect(session.id, equals("s-root"));
        expect(session.title, equals("New Title"));
        expect(server.requestLog, equals(["PATCH /session/s-root"]));
      });
    });

    group("archiveSession", () {
      test("sends PATCH with time.archived body", () async {
        final plugin = OpenCodePlugin(serverUrl: server.baseUrl);
        await server.waitForSseConnection();
        server.requestLog.clear();

        await plugin.archiveSession(sessionId: "s-root");

        expect(server.requestLog, equals(["PATCH /session/s-root"]));

        // Verify the fake server applied the archived timestamp.
        final sessionTime = server.getSessionTime("s-root");
        expect(sessionTime, isNotNull);
        expect(sessionTime!["archived"], isA<int>());
      });
    });

    group("renameProject", () {
      test("resolves worktree to project UUID then sends PATCH with name", () async {
        final plugin = OpenCodePlugin(serverUrl: server.baseUrl);
        await server.waitForSseConnection();
        server.requestLog.clear();

        final project = await plugin.renameProject(projectId: "/repo", name: "Renamed Repo");

        // PluginProject.id is always the worktree path, not the OpenCode UUID
        expect(project.id, equals("/repo"));
        expect(project.name, equals("Renamed Repo"));
        expect(
          server.requestLog,
          equals(["GET /project/current", "PATCH /project/p1"]),
        );
      });
    });
  });
}

/// A lightweight fake OpenCode server whose `/session/status` response can be
/// changed between calls — used to test the merge of API data with tracker data.
class _DynamicStatusServer {
  HttpServer? _server;
  final Completer<void> _firstSseClient = Completer<void>();

  /// The JSON map returned by `GET /session/status`. Mutable so tests can
  /// change it between the cold-start call and the explicit plugin call.
  Map<String, Map<String, dynamic>> sessionStatuses = {};

  String get baseUrl => "http://${_server!.address.address}:${_server!.port}";

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen((request) async {
      final path = request.uri.path;

      if (request.method == "GET" && path == "/project") {
        await _json(request.response, [
          {"id": "p1", "worktree": "/repo", "name": "Repo"},
        ]);
        return;
      }

      if (request.method == "GET" && path == "/session/status") {
        await _json(request.response, sessionStatuses);
        return;
      }

      if (request.method == "GET" && path == "/session") {
        await _json(request.response, [
          {
            "id": "s-root",
            "projectID": "p1",
            "directory": "/repo",
            "time": {"created": 1, "updated": 2},
          },
          {
            "id": "child-1",
            "projectID": "p1",
            "directory": "/repo",
            "parentID": "s-root",
            "time": {"created": 3, "updated": 4},
          },
          {
            "id": "s-child",
            "projectID": "p1",
            "directory": "/repo/packages/foo",
            "time": {"created": 5, "updated": 6},
          },
        ]);
        return;
      }

      if (request.method == "GET" && path == "/experimental/session") {
        await _json(request.response, <Map<String, dynamic>>[]);
        return;
      }

      if (request.method == "GET" && path == "/question") {
        await _json(request.response, <Object>[]);
        return;
      }

      if (request.method == "GET" && path == "/permission") {
        await _json(request.response, <Object>[]);
        return;
      }

      if (request.method == "GET" && path == "/global/event") {
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType("text", "event-stream");
        request.response.headers.set("cache-control", "no-cache");
        request.response.write(": connected\n\n");
        await request.response.flush();
        if (!_firstSseClient.isCompleted) _firstSseClient.complete();
        // Keep the response open (SSE stream).
        return;
      }

      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    });
  }

  Future<void> waitForSseConnection() => _firstSseClient.future;

  Future<void> close() async {
    await _server?.close(force: true);
  }

  Future<void> _json(HttpResponse response, Object body) async {
    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }
}

class _FakeOpenCodeServer {
  HttpServer? _server;
  final List<HttpResponse> _sseClients = [];
  final Completer<void> _firstSseClient = Completer<void>();
  final List<String> requestLog = [];
  Map<String, dynamic>? lastPromptBody;
  String? lastPromptDirectoryHeader;
  Map<String, dynamic>? lastCommandBody;
  String? lastCommandDirectoryHeader;
  String? lastCreatedSessionParentId;

  final Map<String, Map<String, dynamic>> _sessions = {
    "s-root": {
      "id": "s-root",
      "projectID": "p1",
      "directory": "/repo",
      "title": "Root Session",
      "time": <String, dynamic>{"created": 100, "updated": 200},
    },
  };

  final Map<String, Map<String, dynamic>> _projects = {
    "p1": {"id": "p1", "worktree": "/repo", "name": "Main Repo"},
  };

  String get baseUrl => "http://${_server!.address.address}:${_server!.port}";

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen((request) async {
      final path = request.uri.path;
      requestLog.add("${request.method} $path");

      if (request.method == "GET" && path == "/project") {
        await _sendJson(request.response, _projects.values.toList());
        return;
      }

      if (request.method == "GET" && path == "/project/current") {
        final dir = request.headers.value("x-opencode-directory");
        final project = _projects.values.where((p) => p["worktree"] == dir).firstOrNull;
        if (project == null) {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }
        await _sendJson(request.response, project);
        return;
      }

      final projectMatch = RegExp(r"^/project/([^/]+)$").firstMatch(path);
      if (projectMatch != null && request.method == "PATCH") {
        final directoryHeader = request.headers.value("x-opencode-directory");
        if (directoryHeader == null || directoryHeader.isEmpty) {
          request.response.statusCode = HttpStatus.badRequest;
          await request.response.close();
          return;
        }
        final projectId = projectMatch.group(1)!;
        final project = _projects[projectId];
        if (project == null) {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }
        final rawBody = await utf8.decoder.bind(request).join();
        final body = (jsonDecode(rawBody) as Map).cast<String, dynamic>();
        if (body.containsKey("name")) {
          project["name"] = body["name"];
        }
        await _sendJson(request.response, project);
        return;
      }

      if (request.method == "GET" && path == "/session/status") {
        await _sendJson(request.response, {
          "s-root": {"type": "idle"},
        });
        return;
      }

      if (request.method == "GET" && path == "/session") {
        await _sendJson(request.response, [
          {
            "id": "s-root",
            "projectID": "p1",
            "directory": "/repo",
            "title": "Root Session",
            "time": {"created": 100, "updated": 200},
          },
          {
            "id": "s-child",
            "projectID": "p1",
            "directory": "/repo/packages/foo",
            "title": "Child Session",
            "time": {"created": 110, "updated": 210},
          },
        ]);
        return;
      }

      if (request.method == "GET" && path == "/command") {
        await _sendJson(request.response, [
          {
            "name": "/review-work",
            "template": "review {{input}}",
            "hints": ["recent changes"],
            "description": "Review current branch changes",
            "agent": "review-work",
            "model": "gpt-5.4",
            "provider": "openai",
            "source": "skill",
            "subtask": true,
          },
        ]);
        return;
      }

      if (request.method == "POST" && path == "/session") {
        final rawBody = await utf8.decoder.bind(request).join();
        final body = rawBody.isEmpty ? <String, dynamic>{} : (jsonDecode(rawBody) as Map).cast<String, dynamic>();
        lastCreatedSessionParentId = body["parentID"] as String?;
        final directory = request.headers.value("x-opencode-directory") ?? "/repo";
        const sessionId = "s-created";
        _sessions[sessionId] = {
          "id": sessionId,
          "projectID": "global",
          "directory": directory,
          "parentID": body["parentID"],
          "title": "Created Session",
          "time": <String, dynamic>{"created": 300, "updated": 300},
        };
        await _sendJson(request.response, _sessions[sessionId]!);
        return;
      }

      final sessionMatch = RegExp(r"^/session/([^/]+)$").firstMatch(path);
      if (sessionMatch != null && request.method == "GET") {
        final sessionId = sessionMatch.group(1)!;
        final session = _sessions[sessionId];
        if (session == null) {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }
        await _sendJson(request.response, session);
        return;
      }

      final promptMatch = RegExp(r"^/session/([^/]+)/prompt_async$").firstMatch(path);
      if (promptMatch != null && request.method == "POST") {
        final rawBody = await utf8.decoder.bind(request).join();
        lastPromptBody = (jsonDecode(rawBody) as Map).cast<String, dynamic>();
        lastPromptDirectoryHeader = request.headers.value("x-opencode-directory");
        await _sendJson(request.response, true);
        return;
      }

      final commandMatch = RegExp(r"^/session/([^/]+)/command$").firstMatch(path);
      if (commandMatch != null && request.method == "POST") {
        final rawBody = await utf8.decoder.bind(request).join();
        lastCommandBody = (jsonDecode(rawBody) as Map).cast<String, dynamic>();
        lastCommandDirectoryHeader = request.headers.value("x-opencode-directory");
        await _sendJson(request.response, true);
        return;
      }

      if (sessionMatch != null && request.method == "DELETE") {
        final sessionId = sessionMatch.group(1)!;
        _sessions.remove(sessionId);
        await _sendJson(request.response, true);
        return;
      }

      if (sessionMatch != null && request.method == "PATCH") {
        final sessionId = sessionMatch.group(1)!;
        final session = _sessions[sessionId];
        if (session == null) {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }

        final rawBody = await utf8.decoder.bind(request).join();
        final body = (jsonDecode(rawBody) as Map).cast<String, dynamic>();
        final title = body["title"];
        if (title is String) {
          session["title"] = title;
        }

        final timeBody = body["time"];
        if (timeBody is Map<String, dynamic>) {
          final archived = timeBody["archived"];
          final currentTime = (session["time"] as Map?) != null
              ? Map<String, dynamic>.from((session["time"] as Map).cast<String, dynamic>())
              : <String, dynamic>{"created": 100, "updated": 200};
          currentTime["archived"] = archived;
          session["time"] = currentTime;
        }

        await _sendJson(request.response, session);
        return;
      }

      if (request.method == "GET" && path == "/experimental/session") {
        await _sendJson(request.response, [
          {
            "id": "g-1",
            "projectID": "global",
            "directory": "/virtual",
            "time": {"created": 100, "updated": 200},
          },
        ]);
        return;
      }

      if (request.method == "GET" && path == "/provider") {
        await _sendJson(request.response, {
          "all": [
            {
              "id": "anthropic",
              "name": "Anthropic",
              "models": {
                "claude-3-opus": {
                  "id": "claude-3-opus",
                  "providerID": "anthropic",
                  "name": "Claude 3 Opus",
                  "family": "claude-3",
                  "status": "active",
                  "release_date": "2025-03-15",
                },
                "claude-3-sonnet": {
                  "id": "claude-3-sonnet",
                  "providerID": "anthropic",
                  "name": "Claude 3 Sonnet",
                  "family": "claude-3",
                  "status": "deprecated",
                  "release_date": "2024-06-01",
                },
              },
            },
            {
              "id": "my-custom",
              "name": "My Custom Provider",
              "models": <String, dynamic>{},
            },
          ],
          "default": {"anthropic": "claude-3-sonnet"},
          "connected": ["anthropic"],
        });
        return;
      }

      if (request.method == "GET" && path == "/session/ses-1/message") {
        await _sendJson(request.response, [
          {
            "info": {
              "role": "user",
              "id": "m-user",
              "sessionID": "ses-1",
            },
            "parts": [
              {
                "id": "part-1",
                "sessionID": "ses-1",
                "messageID": "m-user",
                "type": "text",
                "text": "hello",
                "tool": null,
                "callID": null,
                "state": null,
                "mime": null,
                "url": null,
                "filename": null,
                "cost": null,
                "reason": null,
                "prompt": null,
                "description": null,
                "agent": null,
                "snapshot": null,
                "time": null,
              },
            ],
          },
          {
            "info": {
              "role": "assistant",
              "id": "m-assistant",
              "sessionID": "ses-1",
              "modelID": "gpt",
              "providerID": "openai",
              "cost": 1.25,
              "finish": "stop",
              "tokens": {
                "input": 12,
                "output": 34,
                "reasoning": 5,
                "cache": {"read": 2, "write": 3},
              },
              "time": {"created": 123, "completed": 456},
            },
            "parts": [
              {
                "id": "part-2",
                "sessionID": "ses-1",
                "messageID": "m-assistant",
                "type": "text",
                "text": "world",
                "tool": null,
                "callID": null,
                "state": null,
                "mime": null,
                "url": null,
                "filename": null,
                "cost": null,
                "reason": null,
                "prompt": null,
                "description": null,
                "agent": null,
                "snapshot": null,
                "time": null,
              },
            ],
          },
        ]);
        return;
      }

      if (request.method == "GET" && path == "/session/ses-filter/message") {
        await _sendJson(request.response, [
          {
            "info": {
              "role": "user",
              "id": "m-filter-user",
              "sessionID": "ses-filter",
            },
            "parts": [
              {
                "id": "part-filter-user",
                "sessionID": "ses-filter",
                "messageID": "m-filter-user",
                "type": "text",
                "text": "go",
              },
            ],
          },
          {
            "info": {
              "role": "assistant",
              "id": "m-filter",
              "sessionID": "ses-filter",
            },
            "parts": [
              {
                "id": "part-text",
                "sessionID": "ses-filter",
                "messageID": "m-filter",
                "type": "text",
                "text": "hello",
              },
              {
                "id": "part-tool",
                "sessionID": "ses-filter",
                "messageID": "m-filter",
                "type": "tool",
                "tool": "bash",
                "state": {
                  "status": "completed",
                  "title": "Run command",
                  "output": "done",
                  "error": null,
                },
              },
              {
                "id": "part-file",
                "sessionID": "ses-filter",
                "messageID": "m-filter",
                "type": "file",
                "text": "ignored",
              },
              {
                "id": "part-snapshot",
                "sessionID": "ses-filter",
                "messageID": "m-filter",
                "type": "snapshot",
                "text": "ignored",
              },
              {
                "id": "part-reasoning",
                "sessionID": "ses-filter",
                "messageID": "m-filter",
                "type": "reasoning",
                "text": "thinking",
              },
            ],
          },
        ]);
        return;
      }

      if (request.method == "GET" && path == "/session/ses-tool-long/message") {
        await _sendJson(request.response, [
          {
            "info": {
              "role": "user",
              "id": "m-tool-long-user",
              "sessionID": "ses-tool-long",
            },
            "parts": [
              {
                "id": "part-tool-long-user",
                "sessionID": "ses-tool-long",
                "messageID": "m-tool-long-user",
                "type": "text",
                "text": "run",
              },
            ],
          },
          {
            "info": {
              "role": "assistant",
              "id": "m-tool-long",
              "sessionID": "ses-tool-long",
            },
            "parts": [
              {
                "id": "part-tool-long",
                "sessionID": "ses-tool-long",
                "messageID": "m-tool-long",
                "type": "tool",
                "tool": "bash",
                "state": {
                  "status": "completed",
                  "title": "Long output",
                  "output": "x" * 1000,
                  "error": null,
                },
              },
            ],
          },
        ]);
        return;
      }

      if (request.method == "GET" && path == "/session/ses-tool-short/message") {
        await _sendJson(request.response, [
          {
            "info": {
              "role": "user",
              "id": "m-tool-short-user",
              "sessionID": "ses-tool-short",
            },
            "parts": [
              {
                "id": "part-tool-short-user",
                "sessionID": "ses-tool-short",
                "messageID": "m-tool-short-user",
                "type": "text",
                "text": "run",
              },
            ],
          },
          {
            "info": {
              "role": "assistant",
              "id": "m-tool-short",
              "sessionID": "ses-tool-short",
            },
            "parts": [
              {
                "id": "part-tool-short",
                "sessionID": "ses-tool-short",
                "messageID": "m-tool-short",
                "type": "tool",
                "tool": "bash",
                "state": {
                  "status": "completed",
                  "title": "Short output",
                  "output": "short",
                  "error": null,
                },
              },
            ],
          },
        ]);
        return;
      }

      if (request.method == "GET" && path == "/session/ses-new-parts-filter/message") {
        await _sendJson(request.response, [
          {
            "info": {"role": "user", "id": "m-npf-user", "sessionID": "ses-new-parts-filter"},
            "parts": [
              {
                "id": "p-npf-user",
                "sessionID": "ses-new-parts-filter",
                "messageID": "m-npf-user",
                "type": "text",
                "text": "go",
              },
            ],
          },
          {
            "info": {"role": "assistant", "id": "m-npf", "sessionID": "ses-new-parts-filter"},
            "parts": [
              {"id": "p-patch", "sessionID": "ses-new-parts-filter", "messageID": "m-npf", "type": "patch"},
              {"id": "p-compaction", "sessionID": "ses-new-parts-filter", "messageID": "m-npf", "type": "compaction"},
              {
                "id": "p-text",
                "sessionID": "ses-new-parts-filter",
                "messageID": "m-npf",
                "type": "text",
                "text": "done",
              },
            ],
          },
        ]);
        return;
      }

      if (request.method == "GET" && path == "/session/ses-agent-part/message") {
        await _sendJson(request.response, [
          {
            "info": {"role": "user", "id": "m-agent-user", "sessionID": "ses-agent-part"},
            "parts": [
              {
                "id": "p-agent-user",
                "sessionID": "ses-agent-part",
                "messageID": "m-agent-user",
                "type": "text",
                "text": "go",
              },
            ],
          },
          {
            "info": {"role": "assistant", "id": "m-agent", "sessionID": "ses-agent-part"},
            "parts": [
              {
                "id": "p-agent",
                "sessionID": "ses-agent-part",
                "messageID": "m-agent",
                "type": "agent",
                "name": "explore",
              },
            ],
          },
        ]);
        return;
      }

      if (request.method == "GET" && path == "/session/ses-retry-part/message") {
        await _sendJson(request.response, [
          {
            "info": {"role": "user", "id": "m-retry-user", "sessionID": "ses-retry-part"},
            "parts": [
              {
                "id": "p-retry-user",
                "sessionID": "ses-retry-part",
                "messageID": "m-retry-user",
                "type": "text",
                "text": "go",
              },
            ],
          },
          {
            "info": {"role": "assistant", "id": "m-retry", "sessionID": "ses-retry-part"},
            "parts": [
              {
                "id": "p-retry",
                "sessionID": "ses-retry-part",
                "messageID": "m-retry",
                "type": "retry",
                "attempt": 2,
                "error": {
                  "name": "APIError",
                  "data": {"message": "Rate limited", "isRetryable": true},
                },
                "time": {"created": 1234},
              },
            ],
          },
        ]);
        return;
      }

      if (request.method == "GET" && path == "/question") {
        await _sendJson(request.response, <Object>[]);
        return;
      }

      if (request.method == "GET" && path == "/permission") {
        await _sendJson(request.response, <Object>[]);
        return;
      }

      if (request.method == "GET" && path == "/global/event") {
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType("text", "event-stream");
        request.response.headers.set("cache-control", "no-cache");
        request.response.headers.set("connection", "keep-alive");
        request.response.write(": connected\n\n");
        await request.response.flush();
        _sseClients.add(request.response);
        if (!_firstSseClient.isCompleted) {
          _firstSseClient.complete();
        }
        return;
      }

      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    });
  }

  Map<String, dynamic>? getSessionTime(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) return null;
    return (session["time"] as Map?)?.cast<String, dynamic>();
  }

  Future<void> waitForSseConnection() => _firstSseClient.future;

  Future<void> emitSse(Map<String, dynamic> payload) async {
    final data = jsonEncode(payload);
    await emitRawSse(data);
  }

  Future<void> emitRawSse(String data) async {
    final futures = <Future<void>>[];
    for (final client in _sseClients) {
      client.write("data: $data\n\n");
      futures.add(client.flush());
    }
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  Future<void> close() async {
    for (final client in _sseClients) {
      try {
        await client.close();
      } catch (_) {}
    }
    _sseClients.clear();
    await _server?.close(force: true);
  }

  Future<void> _sendJson(HttpResponse response, Object body) async {
    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }
}
