import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:deepseek_plugin/deepseek_plugin.dart";
import "package:deepseek_plugin/deepseek_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("Step 9 preserves DeepSeek session-list metadata in event snapshots", () async {
    final fake = FakeAcpProcess();
    final configurationTracker = AcpSessionConfigurationTracker();
    final commandTracker = AcpCommandTracker();
    final childSessionTracker = AcpChildSessionTracker();
    const api = DeepSeekAcpApi(pluginId: DeepSeekIdentity.id);
    final mapper = DeepSeekEventMapper(
      launchDirectory: "/repo",
      pluginId: DeepSeekIdentity.id,
      configurationTracker: configurationTracker,
      childSessions: childSessionTracker,
      api: api,
      messageTimeParser: const DeepSeekMessageTimeParser(),
      subagentMapper: const DeepSeekSubagentMapper(agentId: DeepSeekIdentity.id),
    );
    final plugin = DeepSeekPlugin(
      launchSpec: const AcpLaunchSpec(command: "deepseek", args: [], cwd: "/repo", environment: {}),
      launchDirectory: "/repo",
      childSessionTracker: childSessionTracker,
      mapper: mapper,
      api: api,
      historyRepository: DeepSeekHistoryRepository(
        api: api,
        eventMapper: mapper,
        pluginId: DeepSeekIdentity.id,
        messageTimeParser: const DeepSeekMessageTimeParser(),
        subagentMapper: const DeepSeekSubagentMapper(agentId: DeepSeekIdentity.id),
      ),
      deepSeekSessionService: DeepSeekSessionService(
        repository: const DeepSeekSessionRepository(api: api),
        childSessions: childSessionTracker,
      ),
      deepSeekSessionOptionsService: DeepSeekSessionOptionsService(
        repository: const DeepSeekCatalogRepository(api: api, mapper: DeepSeekCatalogMapper()),
        configurationTracker: configurationTracker,
        pluginId: DeepSeekIdentity.id,
        discoveryTimeout: const Duration(seconds: 30),
      ),
      commandTracker: commandTracker,
      sessionOptionsService: AcpSessionOptionsService(
        configurationTracker: configurationTracker,
        commandTracker: commandTracker,
        pluginId: DeepSeekIdentity.id,
        agentDisplayName: "DeepSeek",
      ),
      processFactory: (_) async => fake,
    );

    Future<Map<String, dynamic>> frame(String method, {int count = 1}) async {
      for (var i = 0; i < 200; i++) {
        final frames = fake.written.where((frame) => frame["method"] == method).toList();
        if (frames.length >= count) return frames[count - 1];
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      throw StateError("DeepSeek never wrote $count '$method' frame(s)");
    }

    final parentRow = {
      "sessionId": "parent",
      "cwd": "/other",
      "title": "Parent",
      "updatedAt": 2000,
      "_meta": {
        "sesori.ai/deepseek": {"createdAt": 1000},
      },
    };
    final sessionRow = {
      "sessionId": "child",
      "cwd": "/other",
      "title": "Child",
      "updatedAt": 2000,
      "_meta": {
        "sesori.ai/deepseek": {"createdAt": 1000, "parentSessionId": "parent"},
      },
    };
    final malformedParentRow = {
      "sessionId": "malformed-parent",
      "cwd": "/repo",
      "title": "Malformed parent",
      "updatedAt": 2000,
      "_meta": {
        "sesori.ai/deepseek": {"createdAt": 1000, "parentSessionId": 42},
      },
    };
    final blankParentRow = {
      "sessionId": "blank-parent",
      "cwd": "/repo",
      "title": "Blank parent",
      "updatedAt": 2000,
      "_meta": {
        "sesori.ai/deepseek": {"createdAt": 1000, "parentSessionId": "  "},
      },
    };
    final answered = <Object?>{};
    var responding = true;
    final responder = () async {
      while (responding) {
        for (final request in fake.written.where((frame) => frame["method"] == "session/list")) {
          if (!answered.add(request["id"])) continue;
          fake.emit({
            "jsonrpc": "2.0",
            "id": request["id"],
            "result": {
              "sessions": [parentRow, sessionRow, malformedParentRow, blankParentRow],
            },
          });
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }();

    try {
      final connecting = plugin.ensureConnected();
      final initialize = await frame(AcpMethods.initialize);
      fake.emit({
        "jsonrpc": "2.0",
        "id": initialize["id"],
        "result": {
          "protocolVersion": 1,
          "agentCapabilities": {
            "loadSession": true,
            "sessionCapabilities": {"list": <String, dynamic>{}},
          },
          "authMethods": <Object?>[],
          "_meta": {
            "sesori.ai/deepseek": {
              "extensionProtocolVersion": 1,
              "adapterVersion": DeepSeekPluginDescriptor.targetVersion,
              "harnessVersion": "0.1.1-rc.2",
              "persistenceOwner": "sesori",
            },
          },
        },
      });
      expect(await connecting, isTrue);

      childSessionTracker.spawn(
        sessionId: "parent",
        spawn: const AcpChildSpawn(
          childSessionId: "live-child",
          description: "Live child",
          agent: DeepSeekIdentity.id,
          prompt: "Inspect",
          isBackground: true,
        ),
        directory: "/repo",
      );
      final children = await plugin.getChildSessions("parent");
      expect(children.map((session) => session.id), ["child", "live-child"]);
      expect(children.singleWhere((session) => session.id == "live-child").projectID, "/other");

      final sessions = await plugin.listAllSessions(knownDirectories: const {});
      final child = sessions.singleWhere((session) => session.id == "child");
      expect(child.parentID, "parent");
      expect(child.time, const PluginSessionTime(created: 1000, updated: 2000, archived: null));
      expect(sessions.singleWhere((session) => session.id == "malformed-parent").parentID, isNull);
      expect(sessions.singleWhere((session) => session.id == "blank-parent").parentID, isNull);

      final events = mapper.map(
        const AcpNotification(
          method: "session/update",
          params: {
            "sessionId": "child",
            "update": {"sessionUpdate": "session_info_update", "updatedAt": 3000},
          },
        ),
      );
      final updatedChild = events.whereType<BridgeSseSessionUpdated>().single.info;
      expect(updatedChild["projectID"], "/other");
      expect(updatedChild["time"], const {"created": 1000, "updated": 3000});
    } finally {
      responding = false;
      await responder;
      await plugin.dispose();
      await fake.close();
    }
  });
}
