import "dart:convert";
import "dart:io";

import "package:acp_plugin/acp_plugin.dart";
import "package:grok_plugin/src/api/grok_session_store_api.dart";
import "package:grok_plugin/src/repositories/grok_session_catalog_repository.dart";
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

    String sessionDirectory(String sessionId) =>
        p.join(sessions.path, Uri.encodeComponent(persistedDirectory), sessionId);

    setUp(() {
      sessions = Directory.systemTemp.createTempSync("grok-child-service-");
      tracker = AcpChildSessionTracker();
      final repository = GrokSessionCatalogRepository(
        api: GrokSessionStoreApi(sessionsRoot: sessions.path, pluginId: "grok-test"),
      );
      service = GrokSessionService(catalogRepository: repository, liveTracker: tracker);

      File(p.join(sessionDirectory(rootId), "summary.json"))
        ..createSync(recursive: true)
        ..writeAsStringSync(
          jsonEncode({
            "info": {"id": rootId, "cwd": persistedDirectory},
          }),
        );
      File(p.join(sessionDirectory(rootId), "updates.jsonl")).writeAsStringSync(
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
      File(p.join(sessionDirectory(persistedChildId), "summary.json"))
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
      expect(children.map((session) => session.directory), everyElement(persistedDirectory));
      expect(
        service.parentId(
          info: const AcpSessionInfo(
            sessionId: persistedChildId,
            cwd: null,
            title: null,
            updatedAtMs: null,
          ),
          fallbackDirectory: "/launch-directory",
        ),
        rootId,
      );
      expect(
        service.parentId(
          info: const AcpSessionInfo(
            sessionId: "live-child",
            cwd: null,
            title: null,
            updatedAtMs: null,
          ),
          fallbackDirectory: "/launch-directory",
        ),
        rootId,
      );
    });

    test("derived all-session enumeration includes the persisted child family", () {
      final sessions = service.includeChildrenInAllSessions(
        sessions: const [
          PluginSession(
            id: rootId,
            projectID: persistedDirectory,
            directory: persistedDirectory,
            parentID: null,
            title: "Root",
            time: null,
          ),
        ],
      );

      expect(sessions.map((session) => session.id), [rootId, persistedChildId]);
      expect(sessions.last.parentID, rootId);
    });
  });
}
