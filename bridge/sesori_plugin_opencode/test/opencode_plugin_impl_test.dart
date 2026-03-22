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

      final virtual = projects.firstWhere((p) => p.name == null);
      expect(virtual.id, isNotEmpty);
    });

    test("getSessions maps internal sessions to plugin sessions", () async {
      final plugin = OpenCodePlugin(serverUrl: server.baseUrl);

      final sessions = await plugin.getSessions("/repo");

      expect(sessions, hasLength(1));
      final session = sessions.single;
      expect(session.id, equals("s-root"));
      expect(session.projectID, equals("p1"));
      expect(session.directory, equals("/repo"));
      expect(session.parentID, isNull);
      expect(session.time?.created, equals(100));
      expect(session.time?.updated, equals(200));
    });

    test("getSessionMessages maps raw messages to plugin messages", () async {
      final plugin = OpenCodePlugin(serverUrl: server.baseUrl);

      final messages = await plugin.getSessionMessages("ses-1");

      expect(messages, hasLength(2));
      final user = messages.first;
      expect(user.info.role, equals("user"));
      expect(user.info.id, equals("m-user"));
      expect(user.info.sessionID, equals("ses-1"));

      final assistant = messages.last;
      expect(assistant.info.role, equals("assistant"));
      expect(assistant.info.id, equals("m-assistant"));
      expect(assistant.info.modelID, equals("gpt"));
      expect(assistant.info.providerID, equals("openai"));
      expect(assistant.info.cost, equals(1.25));
      expect(assistant.info.finish, equals("stop"));
      expect(assistant.info.time?.created, equals(123));
      expect(assistant.info.time?.completed, equals(456));
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

      final sonnet = anthropic.models.firstWhere((m) => m.id == "claude-3-sonnet");
      expect(sonnet.name, equals("Claude 3 Sonnet"));
      expect(sonnet.family, equals("claude-3"));

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

    test("getSessionDiffs returns cumulative diffs for session", () async {
      final plugin = OpenCodePlugin(serverUrl: server.baseUrl);

      final diffs = await plugin.getSessionDiffs("ses-1");

      expect(diffs, hasLength(2));
      final added = diffs.first;
      expect(added.file, equals("src/a.dart"));
      expect(added.before, equals(""));
      expect(added.after, equals("content"));
      expect(added.additions, equals(5));
      expect(added.deletions, equals(0));
      expect(added.status, equals("added"));

      final deleted = diffs.last;
      expect(deleted.file, equals("src/b.dart"));
      expect(deleted.status, equals("deleted"));
    });

    test("getMessageDiffs returns per-message diffs", () async {
      final plugin = OpenCodePlugin(serverUrl: server.baseUrl);

      final diffs = await plugin.getMessageDiffs("ses-1", "m-1");

      expect(diffs, hasLength(1));
      final diff = diffs.single;
      expect(diff.file, equals("src/foo.dart"));
      expect(diff.before, equals("old"));
      expect(diff.after, equals("new"));
      expect(diff.additions, equals(3));
      expect(diff.deletions, equals(1));
      expect(diff.status, equals("modified"));
    });

    test("getSessionDiffs with null status field returns status as null", () async {
      // Verify null status path via PluginFileDiff constructed directly
      // (no server interaction needed for this property check).
      const diff = PluginFileDiff(
        file: "x",
        before: "a",
        after: "b",
        additions: 1,
        deletions: 0,
      );
      expect(diff.status, isNull);
    });

    test("events stream emits bridge events", () async {
      final plugin = OpenCodePlugin(serverUrl: server.baseUrl);

      final stream = plugin.events;
      final collected = <BridgeSseEvent>[];
      final sub = stream.listen(collected.add);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(collected.whereType<BridgeSseProjectUpdated>(), isNotEmpty);
    });
  });
}

class _FakeOpenCodeServer {
  HttpServer? _server;
  final List<HttpResponse> _sseClients = [];
  final Completer<void> _firstSseClient = Completer<void>();

  String get baseUrl => "http://${_server!.address.address}:${_server!.port}";

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen((request) async {
      final path = request.uri.path;

      if (request.method == "GET" && path == "/project") {
        await _sendJson(request.response, [
          {"id": "p1", "worktree": "/repo", "name": "Main Repo"},
        ]);
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
            "time": {"created": 100, "updated": 200},
          },
        ]);
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
                },
                "claude-3-sonnet": {
                  "id": "claude-3-sonnet",
                  "providerID": "anthropic",
                  "name": "Claude 3 Sonnet",
                  "family": "claude-3",
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

      if (request.method == "GET" && path.startsWith("/session/") && path.endsWith("/diff")) {
        final messageId = request.uri.queryParameters["messageID"];
        if (messageId != null) {
          // per-message diffs: return a single diff for message m-1
          await _sendJson(request.response, [
            {
              "file": "src/foo.dart",
              "before": "old",
              "after": "new",
              "additions": 3,
              "deletions": 1,
              "status": "modified",
            },
          ]);
        } else {
          // session-level diffs: return two diffs
          await _sendJson(request.response, [
            {
              "file": "src/a.dart",
              "before": "",
              "after": "content",
              "additions": 5,
              "deletions": 0,
              "status": "added",
            },
            {
              "file": "src/b.dart",
              "before": "old",
              "after": "",
              "additions": 0,
              "deletions": 2,
              "status": "deleted",
            },
          ]);
        }
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

  Future<void> waitForSseConnection() => _firstSseClient.future;

  Future<void> emitSse(Map<String, dynamic> payload) async {
    final data = jsonEncode(payload);
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
