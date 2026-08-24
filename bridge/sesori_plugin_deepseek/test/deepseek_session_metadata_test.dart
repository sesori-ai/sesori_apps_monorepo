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
    const api = DeepSeekAcpApi(pluginId: DeepSeekIdentity.id);
    final mapper = DeepSeekEventMapper(
      launchDirectory: "/repo",
      pluginId: DeepSeekIdentity.id,
      configurationTracker: configurationTracker,
      api: api,
    );
    final plugin = DeepSeekPlugin(
      launchSpec: const AcpLaunchSpec(command: "deepseek", args: [], cwd: "/repo", environment: {}),
      launchDirectory: "/repo",
      mapper: mapper,
      api: api,
      historyRepository: DeepSeekHistoryRepository(api: api, eventMapper: mapper, pluginId: DeepSeekIdentity.id),
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

    final sessionRow = {
      "sessionId": "child",
      "cwd": "/repo",
      "title": "Child",
      "updatedAt": 2000,
      "_meta": {
        "sesori.ai/deepseek": {"createdAt": 1000, "parentSessionId": "parent"},
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
              "sessions": [sessionRow],
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
        },
      });
      expect(await connecting, isTrue);

      final sessions = await plugin.listAllSessions(knownDirectories: const {});
      final child = sessions.single;
      expect(child.parentID, "parent");
      expect(child.time, const PluginSessionTime(created: 1000, updated: 2000, archived: null));

      final children = await plugin.getChildSessions("parent");
      expect(children.map((session) => session.id), ["child"]);

      final events = mapper.map(
        const AcpNotification(
          method: "session/update",
          params: {
            "sessionId": "child",
            "update": {"sessionUpdate": "session_info_update", "updatedAt": 3000},
          },
        ),
      );
      expect(
        events.whereType<BridgeSseSessionUpdated>().single.info["time"],
        const {"created": 1000, "updated": 3000},
      );
    } finally {
      responding = false;
      await responder;
      await plugin.dispose();
      await fake.close();
    }
  });
}
