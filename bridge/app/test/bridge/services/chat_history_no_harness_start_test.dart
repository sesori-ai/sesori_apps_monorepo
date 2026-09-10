import "package:sesori_bridge/src/repositories/session_unseen_calculator.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show Message, MessageTime;
import "package:test/test.dart";

import "../../helpers/test_chat_history.dart";
import "../../helpers/test_database.dart";
import "../routing/routing_test_helpers.dart";

void main() {
  // Success Criterion 1: reading history must not start a harness. Harnesses
  // respond poorly for a while after starting, so waking one to render a
  // transcript the bridge already has is the exact cost this feature removes.
  // Asserted against the real SessionRepository and plugin runtime, because a
  // faked repository could not observe a start.
  test("a synced session is served without starting the plugin", () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final plugin = FakeBridgePlugin()
      ..messagesResult = const [
        PluginMessageWithParts(
          info: PluginMessage.user(
            promptId: null,
            id: "m1",
            sessionID: "backend-a",
            agent: null,
            time: PluginMessageTime(created: 1, completed: null),
          ),
          parts: [],
        ),
      ];
    addTearDown(plugin.close);

    final sessionRepository = singlePluginSessionRepository(
      plugin: plugin,
      sessionDao: database.sessionDao,
      projectsDao: database.projectsDao,
      pullRequestDao: database.pullRequestDao,
      unseenCalculator: const SessionUnseenCalculator(),
    );
    addTearDown(sessionRepository.dispose);
    final history = createTestChatHistory(sessionRepository: sessionRepository);
    await recordSessionBinding(
      database: database,
      sessionId: "ses_a",
      backendSessionId: "backend-a",
      pluginId: plugin.id,
      projectId: "project-a",
      parentSessionId: null,
    );

    // First read is allowed to reach the backend: nothing is stored yet.
    await history.service.getSessionMessages(sessionId: "ses_a");
    expect(plugin.lastGetMessagesSessionId, "backend-a");

    plugin.lastGetMessagesSessionId = null;
    final served = (await history.service.getSessionMessages(sessionId: "ses_a")).messages;

    expect(served.single.info.id, "m1");
    expect(
      plugin.lastGetMessagesSessionId,
      isNull,
      reason: "a synced store must render history with the harness untouched",
    );
  });

  // A store-only read makes that guarantee unconditional. Freshness is the
  // bridge's own bookkeeping, so a client that cannot wake the harness at all —
  // it is disabled, or needs authentication — must not have its transcript
  // depend on it.
  test("an unsynced session is served store-only without starting the plugin", () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final plugin = FakeBridgePlugin();
    addTearDown(plugin.close);

    final sessionRepository = singlePluginSessionRepository(
      plugin: plugin,
      sessionDao: database.sessionDao,
      projectsDao: database.projectsDao,
      pullRequestDao: database.pullRequestDao,
      unseenCalculator: const SessionUnseenCalculator(),
    );
    addTearDown(sessionRepository.dispose);
    final history = createTestChatHistory(sessionRepository: sessionRepository);
    await recordSessionBinding(
      database: database,
      sessionId: "ses_a",
      backendSessionId: "backend-a",
      pluginId: plugin.id,
      projectId: "project-a",
      parentSessionId: null,
    );
    // A live capture creates rows without ever marking the session synced, so
    // an ordinary read here would backfill.
    await history.service.captureMessage(
      sessionId: "ses_a",
      message: const Message.user(
        promptId: null,
        id: "live",
        sessionID: "ses_a",
        agent: null,
        time: MessageTime(created: 1, completed: null),
      ),
    );

    final page = await history.service.getSessionMessages(sessionId: "ses_a", storedOnly: true);

    expect(page.messages.single.info.id, "live");
    expect(page.awaitingHarnessSync, isTrue);
    expect(
      plugin.lastGetMessagesSessionId,
      isNull,
      reason: "a store-only read must serve an unsynced store without waking the harness",
    );
  });
}
