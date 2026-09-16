import "dart:convert";
import "dart:io";

import "package:acp_plugin/acp_plugin.dart";
import "package:grok_plugin/src/api/grok_acp_api.dart";
import "package:grok_plugin/src/api/grok_session_store_api.dart";
import "package:grok_plugin/src/repositories/grok_session_catalog_repository.dart";
import "package:grok_plugin/src/repositories/grok_session_control_repository.dart";
import "package:grok_plugin/src/repositories/grok_session_history_repository.dart";
import "package:grok_plugin/src/services/grok_session_service.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("GrokSessionService", () {
    late Directory sessions;
    late AcpChildSessionTracker tracker;
    late GrokSessionService service;
    const persistedDirectory = "/outside-launch-directory";
    const rootId = "root";
    const persistedChildId = "persisted-child";

    String sessionDirectory({required String sessionId}) =>
        p.join(sessions.path, Uri.encodeComponent(persistedDirectory), sessionId);

    PluginSession rootSession() => const PluginSession(
      id: rootId,
      projectID: "/launch-directory",
      directory: "/launch-directory",
      parentID: null,
      title: "Root",
      time: null,
    );

    setUp(() {
      sessions = Directory.systemTemp.createTempSync("grok-child-service-");
      tracker = AcpChildSessionTracker();
      final storeApi = GrokSessionStoreApi(sessionsRoot: sessions.path, pluginId: "grok-test");
      final repository = GrokSessionCatalogRepository(api: storeApi);
      service = GrokSessionService(
        catalogRepository: repository,
        controlRepository: GrokSessionControlRepository(
          api: GrokAcpApi(
            binaryPath: "grok",
            processFactory: (_) => throw StateError("unused"),
            environment: const {},
          ),
        ),
        historyRepository: GrokSessionHistoryRepository(api: storeApi),
        liveTracker: tracker,
      );

      File(p.join(sessionDirectory(sessionId: rootId), "summary.json"))
        ..createSync(recursive: true)
        ..writeAsStringSync(
          jsonEncode({
            "info": {"id": rootId, "cwd": persistedDirectory},
          }),
        );
      File(p.join(sessionDirectory(sessionId: rootId), "updates.jsonl")).writeAsStringSync(
        jsonEncode({
          "method": "_x.ai/session/update",
          "params": {
            "sessionId": rootId,
            "update": {
              "sessionUpdate": "subagent_spawned",
              "subagent_id": persistedChildId,
              "child_session_id": persistedChildId,
              "parent_session_id": rootId,
              "description": "Persisted child",
            },
          },
        }),
      );
      File(p.join(sessionDirectory(sessionId: persistedChildId), "summary.json"))
        ..createSync(recursive: true)
        ..writeAsStringSync(
          jsonEncode({
            "info": {"id": persistedChildId, "cwd": persistedDirectory},
            "session_kind": "subagent",
          }),
        );
    });

    tearDown(() async {
      await tracker.dispose();
      sessions.deleteSync(recursive: true);
    });

    test("resolves persisted children outside the launch directory and merges live children", () {
      tracker.spawn(
        sessionId: rootId,
        spawn: const AcpChildSpawn(
          childSessionId: "live-child",
          description: "Live child",
          agent: "general-purpose",
          prompt: null,
          isBackground: false,
        ),
        directory: persistedDirectory,
      );

      final children = service.childSessions(
        rootSessionId: rootId,
        fallbackDirectory: "/launch-directory",
      );

      expect(children.map((session) => session.id), [persistedChildId, "live-child"]);
      expect(children.map((session) => session.parentID), everyElement(rootId));
      expect(children.map((session) => session.directory), everyElement(persistedDirectory));
    });

    test("derived all-session enumeration includes the persisted child family", () {
      final sessions = service.includeChildrenInAllSessions(sessions: [rootSession()]);

      expect(sessions.map((session) => session.id), [rootId, persistedChildId]);
      expect(sessions.first.directory, persistedDirectory);
      expect(sessions.last.parentID, rootId);
      expect(sessions.last.directory, persistedDirectory);
    });

    test("history context uses persisted directory and excludes live-only children", () async {
      File(p.join(sessionDirectory(sessionId: persistedChildId), "updates.jsonl")).writeAsStringSync(
        jsonEncode({
          "method": "session/update",
          "params": {
            "sessionId": persistedChildId,
            "update": {
              "sessionUpdate": "user_message_chunk",
              "content": {"type": "text", "text": "Persisted prompt"},
            },
          },
        }),
      );
      tracker.spawn(
        sessionId: rootId,
        spawn: const AcpChildSpawn(
          childSessionId: "live-only",
          description: "Live child",
          agent: "general-purpose",
          prompt: "Live prompt",
          isBackground: false,
        ),
        directory: persistedDirectory,
      );

      final context = await service.prepareReplayContext(
        sessionId: rootId,
        fallbackDirectory: "/launch-directory",
      );

      expect(context.childPrompts, {persistedChildId: "Persisted prompt"});
    });

    test("derived all-session enumeration repairs a root directory even when it has no children", () {
      File(p.join(sessionDirectory(sessionId: rootId), "updates.jsonl")).writeAsStringSync("");

      final sessions = service.includeChildrenInAllSessions(sessions: [rootSession()]);

      expect(sessions, hasLength(1));
      expect(sessions.single.projectID, persistedDirectory);
      expect(sessions.single.directory, persistedDirectory);
    });
  });
}
