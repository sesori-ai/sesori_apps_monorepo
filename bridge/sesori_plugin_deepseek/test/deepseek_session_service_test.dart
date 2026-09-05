import "package:acp_plugin/acp_plugin.dart";
import "package:deepseek_plugin/deepseek_plugin.dart";
import "package:deepseek_plugin/deepseek_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("child reads merge persisted and live sessions with persisted rows winning", () async {
    final tracker = AcpChildSessionTracker();
    tracker
      ..spawn(
        sessionId: "root",
        spawn: const AcpChildSpawn(
          childSessionId: "persisted-child",
          description: "Live duplicate",
          agent: "deepseek",
          prompt: "Synthetic prompt",
          isBackground: false,
        ),
        directory: "/project",
      )
      ..spawn(
        sessionId: "root",
        spawn: const AcpChildSpawn(
          childSessionId: "live-child",
          description: "Live only",
          agent: "deepseek",
          prompt: "Synthetic prompt",
          isBackground: true,
        ),
        directory: "/project",
      );
    final service = DeepSeekSessionService(
      repository: const DeepSeekSessionRepository(
        api: DeepSeekAcpApi(pluginId: DeepSeekIdentity.id),
      ),
      childSessions: tracker,
    );
    const persisted = PluginSession(
      id: "persisted-child",
      projectID: "/project",
      directory: "/project",
      parentID: "root",
      title: "Persisted title",
      time: PluginSessionTime(created: 1, updated: 2, archived: null),
    );

    final children = service.getChildSessions(
      sessionId: "root",
      directory: "/project",
      persistedSessions: const [
        persisted,
        PluginSession(
          id: "other-child",
          projectID: "/project",
          directory: "/project",
          parentID: "root",
          title: "Persisted only",
          time: null,
        ),
        PluginSession(
          id: "another-root-child",
          projectID: "/project",
          directory: "/project",
          parentID: "another-root",
          title: null,
          time: null,
        ),
      ],
    );

    expect(children.map((session) => session.id), ["persisted-child", "other-child", "live-child"]);
    expect(children.first, persisted);
    expect(children.last.title, "Live only");
    await tracker.dispose();
  });
}
