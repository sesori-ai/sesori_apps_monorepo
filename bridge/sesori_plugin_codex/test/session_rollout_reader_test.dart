import "dart:convert";
import "dart:io";

import "package:codex_plugin/codex_plugin.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("SessionRolloutReader", () {
    late Directory codexHome;
    late SessionRolloutReader reader;

    setUp(() {
      codexHome = Directory.systemTemp.createTempSync("codex-home-");
      reader = SessionRolloutReader(
        environment: {"CODEX_HOME": codexHome.path},
      );
    });

    tearDown(() {
      try {
        codexHome.deleteSync(recursive: true);
      } catch (_) {
        // Best-effort cleanup.
      }
    });

    test("readIndex returns empty when session_index.jsonl is missing", () {
      expect(reader.readIndex(), isEmpty);
    });

    test("readIndex parses well-formed lines and skips bad ones", () {
      final index = File(p.join(codexHome.path, "session_index.jsonl"))
        ..writeAsStringSync(
          [
            jsonEncode({
              "id": "019a0000-1111-2222-3333-aaaaaaaaaaaa",
              "thread_name": "First thread",
              "updated_at": "2026-04-17T10:00:00Z",
            }),
            "not-json-at-all",
            jsonEncode({
              "id": "019a0000-1111-2222-3333-bbbbbbbbbbbb",
              "thread_name": "Second thread",
              "updated_at": "2026-04-17T11:30:00Z",
            }),
            jsonEncode({"thread_name": "missing-id"}),
            "",
          ].join("\n"),
        );

      final entries = reader.readIndex();
      expect(entries, hasLength(2));
      expect(entries[0].id, equals("019a0000-1111-2222-3333-aaaaaaaaaaaa"));
      expect(entries[0].threadName, equals("First thread"));
      expect(entries[0].updatedAt, isNotNull);
      expect(entries[1].threadName, equals("Second thread"));
      expect(index.existsSync(), isTrue);
    });

    test("listRolloutFiles walks the sessions tree and extracts UUIDs", () {
      _writeRollout(
        codexHome,
        path: "sessions/2026/04/17/rollout-2026-04-17T10-00-00-019a0000-1111-2222-3333-aaaaaaaaaaaa.jsonl",
        sessionId: "019a0000-1111-2222-3333-aaaaaaaaaaaa",
        cwd: "/repo/app",
      );
      _writeRollout(
        codexHome,
        path: "sessions/2026/04/18/rollout-2026-04-18T08-30-00-019a0000-1111-2222-3333-bbbbbbbbbbbb.jsonl",
        sessionId: "019a0000-1111-2222-3333-bbbbbbbbbbbb",
        cwd: "/repo/web",
      );

      final files = reader.listRolloutFiles();
      expect(files, hasLength(2));
      expect(
        files.map((f) => f.sessionId).toSet(),
        equals({
          "019a0000-1111-2222-3333-aaaaaaaaaaaa",
          "019a0000-1111-2222-3333-bbbbbbbbbbbb",
        }),
      );
    });

    test("readMeta returns CWD and timestamp from the session_meta header", () {
      final path = _writeRollout(
        codexHome,
        path: "sessions/2026/04/17/rollout-2026-04-17T10-00-00-019a0000-1111-2222-3333-aaaaaaaaaaaa.jsonl",
        sessionId: "019a0000-1111-2222-3333-aaaaaaaaaaaa",
        cwd: "/repo/app",
        timestamp: "2026-04-17T10:00:00Z",
        cliVersion: "0.121.0",
      );
      final meta = reader.readMeta(path);
      expect(meta, isNotNull);
      expect(meta!.id, equals("019a0000-1111-2222-3333-aaaaaaaaaaaa"));
      expect(meta.cwd, equals("/repo/app"));
      expect(meta.timestamp, isNotNull);
      expect(meta.cliVersion, equals("0.121.0"));
    });

    test("listSessions joins index + rollout header and sorts by updatedAt", () {
      _writeRollout(
        codexHome,
        path: "sessions/2026/04/17/rollout-2026-04-17T10-00-00-019a0000-1111-2222-3333-aaaaaaaaaaaa.jsonl",
        sessionId: "019a0000-1111-2222-3333-aaaaaaaaaaaa",
        cwd: "/repo/app",
        timestamp: "2026-04-17T10:00:00Z",
      );
      _writeRollout(
        codexHome,
        path: "sessions/2026/04/18/rollout-2026-04-18T08-30-00-019a0000-1111-2222-3333-bbbbbbbbbbbb.jsonl",
        sessionId: "019a0000-1111-2222-3333-bbbbbbbbbbbb",
        cwd: "/repo/app",
        timestamp: "2026-04-18T08:30:00Z",
      );
      File(p.join(codexHome.path, "session_index.jsonl")).writeAsStringSync(
        [
          jsonEncode({
            "id": "019a0000-1111-2222-3333-aaaaaaaaaaaa",
            "thread_name": "Older",
            "updated_at": "2026-04-17T10:05:00Z",
          }),
          jsonEncode({
            "id": "019a0000-1111-2222-3333-bbbbbbbbbbbb",
            "thread_name": "Newer",
            "updated_at": "2026-04-18T09:00:00Z",
          }),
        ].join("\n"),
      );

      final records = reader.listSessions();
      expect(records, hasLength(2));
      // Sorted newest-first.
      expect(records[0].threadName, equals("Newer"));
      expect(records[1].threadName, equals("Older"));
      expect(records[0].cwd, equals("/repo/app"));
    });

    test("readMessages maps user/assistant text turns into PluginMessages", () {
      final path = _writeRollout(
        codexHome,
        path: "sessions/2026/04/17/rollout-2026-04-17T10-00-00-019a0000-1111-2222-3333-aaaaaaaaaaaa.jsonl",
        sessionId: "019a0000-1111-2222-3333-aaaaaaaaaaaa",
        cwd: "/repo/app",
        extraLines: [
          jsonEncode({
            "type": "response_item",
            "payload": {
              "role": "user",
              "content": [
                {"type": "input_text", "text": "hello, codex"},
              ],
            },
          }),
          jsonEncode({
            "type": "response_item",
            "payload": {
              "role": "assistant",
              "content": [
                {"type": "output_text", "text": "hello back!"},
              ],
            },
          }),
          // Should be skipped: not a response_item.
          jsonEncode({
            "type": "event_msg",
            "payload": {"type": "token_count", "count": 10},
          }),
        ],
      );

      final messages = reader.readMessages(
        path,
        "019a0000-1111-2222-3333-aaaaaaaaaaaa",
      );
      expect(messages, hasLength(2));
      expect(messages[0].info, isA<PluginMessageUser>());
      expect(messages[0].parts.first.text, equals("hello, codex"));
      expect(messages[1].info, isA<PluginMessageAssistant>());
      expect(messages[1].parts.first.text, equals("hello back!"));
      expect(messages[0].info.sessionID, equals("019a0000-1111-2222-3333-aaaaaaaaaaaa"));
    });
  });

  group("CodexPlugin Phase 3 wiring", () {
    late Directory codexHome;

    setUp(() {
      codexHome = Directory.systemTemp.createTempSync("codex-home-");
    });

    tearDown(() {
      try {
        codexHome.deleteSync(recursive: true);
      } catch (_) {
        // Best-effort cleanup.
      }
    });

    test("getProjects returns the synthesised project for the launch CWD", () async {
      final plugin = CodexPlugin(
        serverUrl: "ws://127.0.0.1:0",
        rolloutReader: SessionRolloutReader(
          environment: {"CODEX_HOME": codexHome.path},
        ),
        projectCwd: "/work/sample-app",
      );
      final projects = await plugin.getProjects();
      expect(projects, hasLength(1));
      expect(projects.single.id, equals("/work/sample-app"));
      expect(projects.single.name, equals("sample-app"));
      await plugin.dispose();
    });

    test("getSessions filters rollouts by CWD == projectId", () async {
      _writeRollout(
        codexHome,
        path: "sessions/2026/04/17/rollout-2026-04-17T10-00-00-019a0000-1111-2222-3333-aaaaaaaaaaaa.jsonl",
        sessionId: "019a0000-1111-2222-3333-aaaaaaaaaaaa",
        cwd: "/work/sample-app",
        timestamp: "2026-04-17T10:00:00Z",
      );
      _writeRollout(
        codexHome,
        path: "sessions/2026/04/18/rollout-2026-04-18T08-30-00-019a0000-1111-2222-3333-bbbbbbbbbbbb.jsonl",
        sessionId: "019a0000-1111-2222-3333-bbbbbbbbbbbb",
        cwd: "/other/project",
        timestamp: "2026-04-18T08:30:00Z",
      );

      final plugin = CodexPlugin(
        serverUrl: "ws://127.0.0.1:0",
        rolloutReader: SessionRolloutReader(
          environment: {"CODEX_HOME": codexHome.path},
        ),
        projectCwd: "/work/sample-app",
      );

      final sessions = await plugin.getSessions("/work/sample-app");
      expect(sessions, hasLength(1));
      expect(sessions.single.id, equals("019a0000-1111-2222-3333-aaaaaaaaaaaa"));
      expect(sessions.single.directory, equals("/work/sample-app"));

      // Filtering by a different CWD returns empty.
      final none = await plugin.getSessions("/somewhere/else");
      expect(none, isEmpty);
      await plugin.dispose();
    });

    test("getSessionMessages reads the rollout for the session", () async {
      _writeRollout(
        codexHome,
        path: "sessions/2026/04/17/rollout-2026-04-17T10-00-00-019a0000-1111-2222-3333-aaaaaaaaaaaa.jsonl",
        sessionId: "019a0000-1111-2222-3333-aaaaaaaaaaaa",
        cwd: "/work/sample-app",
        extraLines: [
          jsonEncode({
            "type": "response_item",
            "payload": {
              "role": "user",
              "content": [
                {"type": "input_text", "text": "ping"},
              ],
            },
          }),
          jsonEncode({
            "type": "response_item",
            "payload": {
              "role": "assistant",
              "content": [
                {"type": "output_text", "text": "pong"},
              ],
            },
          }),
        ],
      );

      final plugin = CodexPlugin(
        serverUrl: "ws://127.0.0.1:0",
        rolloutReader: SessionRolloutReader(
          environment: {"CODEX_HOME": codexHome.path},
        ),
        projectCwd: "/work/sample-app",
      );

      final messages = await plugin.getSessionMessages(
        "019a0000-1111-2222-3333-aaaaaaaaaaaa",
      );
      expect(messages, hasLength(2));
      expect(messages[0].parts.first.text, equals("ping"));
      expect(messages[1].parts.first.text, equals("pong"));
      await plugin.dispose();
    });
  });
}

String _writeRollout(
  Directory codexHome, {
  required String path,
  required String sessionId,
  required String cwd,
  String timestamp = "2026-04-17T10:00:00Z",
  String cliVersion = "0.121.0",
  List<String> extraLines = const [],
}) {
  final full = p.join(codexHome.path, path);
  Directory(p.dirname(full)).createSync(recursive: true);
  final lines = <String>[
    jsonEncode({
      "timestamp": timestamp,
      "type": "session_meta",
      "payload": {
        "id": sessionId,
        "timestamp": timestamp,
        "cwd": cwd,
        "cli_version": cliVersion,
        "model_provider": "openai",
      },
    }),
    ...extraLines,
  ];
  File(full).writeAsStringSync("${lines.join("\n")}\n");
  return full;
}
