// Phase 6 polish tests for project/session mutation behavior.

import "dart:convert";
import "dart:io";

import "package:codex_plugin/codex_plugin.dart";
import "package:path/path.dart" as p;
import "package:test/test.dart";

import "support/codex_plugin_test_factory.dart";

void main() {
  group("CodexPlugin Phase 6 polish", () {
    late Directory codexHome;
    late Directory projectCwd;

    setUp(() {
      codexHome = Directory.systemTemp.createTempSync("codex-home-p6-");
      projectCwd = Directory.systemTemp.createTempSync("codex-project-p6-");
    });

    tearDown(() {
      try {
        codexHome.deleteSync(recursive: true);
      } catch (_) {}
      try {
        projectCwd.deleteSync(recursive: true);
      } catch (_) {}
    });

    CodexPlugin newPlugin() {
      const serverUrl = "ws://127.0.0.1:0";
      return createInjectedCodexPlugin(
        serverUrl: "ws://127.0.0.1:0",
        environment: {"CODEX_HOME": codexHome.path},
        projectCwd: projectCwd.path,
        clientFactory: () => CodexAppServerClient(serverUrl: serverUrl),
        keepaliveInterval: const Duration(seconds: 30),
      );
    }

    test("deleteSession removes the rollout JSONL and the index entry", () async {
      // Set up: one session in the index and on disk, one extra session
      // that must be preserved.
      _writeRollout(
        codexHome,
        path: "sessions/2026/04/17/rollout-2026-04-17T10-00-00-019a0000-1111-2222-3333-aaaaaaaaaaaa.jsonl",
        sessionId: "019a0000-1111-2222-3333-aaaaaaaaaaaa",
        cwd: projectCwd.path,
      );
      _writeRollout(
        codexHome,
        path: "sessions/2026/04/18/rollout-2026-04-18T08-30-00-019a0000-1111-2222-3333-bbbbbbbbbbbb.jsonl",
        sessionId: "019a0000-1111-2222-3333-bbbbbbbbbbbb",
        cwd: projectCwd.path,
      );
      File(p.join(codexHome.path, "session_index.jsonl")).writeAsStringSync(
        [
          jsonEncode({
            "id": "019a0000-1111-2222-3333-aaaaaaaaaaaa",
            "thread_name": "Goner",
            "updated_at": "2026-04-17T10:05:00Z",
          }),
          jsonEncode({
            "id": "019a0000-1111-2222-3333-bbbbbbbbbbbb",
            "thread_name": "Survivor",
            "updated_at": "2026-04-18T09:00:00Z",
          }),
        ].join("\n"),
      );

      final plugin = newPlugin();
      await plugin.deleteSession("019a0000-1111-2222-3333-aaaaaaaaaaaa");

      // Rollout file is gone.
      expect(
        File(
          p.join(
            codexHome.path,
            "sessions/2026/04/17/rollout-2026-04-17T10-00-00-019a0000-1111-2222-3333-aaaaaaaaaaaa.jsonl",
          ),
        ).existsSync(),
        isFalse,
      );
      // The survivor rollout is untouched.
      expect(
        File(
          p.join(
            codexHome.path,
            "sessions/2026/04/18/rollout-2026-04-18T08-30-00-019a0000-1111-2222-3333-bbbbbbbbbbbb.jsonl",
          ),
        ).existsSync(),
        isTrue,
      );
      // Index has only the survivor left.
      final indexLines = File(
        p.join(codexHome.path, "session_index.jsonl"),
      ).readAsLinesSync().where((l) => l.trim().isNotEmpty).toList();
      expect(indexLines, hasLength(1));
      expect(indexLines.single, contains("Survivor"));
      // Listing sessions reflects the delete.
      final remaining = await plugin.getSessions(projectCwd.path);
      expect(
        remaining.map((s) => s.id).toList(),
        equals([
          "019a0000-1111-2222-3333-bbbbbbbbbbbb",
        ]),
      );
      await plugin.dispose();
    });

    test("deleteSession on an unknown id is a silent no-op", () async {
      final plugin = newPlugin();
      await expectLater(
        plugin.deleteSession("does-not-exist"),
        completes,
      );
      await plugin.dispose();
    });

    test("getChildSessions returns empty (documented limitation)", () async {
      final plugin = newPlugin();
      expect(
        await plugin.getChildSessions("019a0000-1111-2222-3333-aaaaaaaaaaaa"),
        isEmpty,
      );
      await plugin.dispose();
    });
  });
}

void _writeRollout(
  Directory codexHome, {
  required String path,
  required String sessionId,
  required String cwd,
}) {
  final full = p.join(codexHome.path, path);
  Directory(p.dirname(full)).createSync(recursive: true);
  final line = jsonEncode({
    "timestamp": "2026-04-17T10:00:00Z",
    "type": "session_meta",
    "payload": {
      "id": sessionId,
      "timestamp": "2026-04-17T10:00:00Z",
      "cwd": cwd,
      "cli_version": "0.121.0",
      "model_provider": "openai",
    },
  });
  File(full).writeAsStringSync("$line\n");
}
