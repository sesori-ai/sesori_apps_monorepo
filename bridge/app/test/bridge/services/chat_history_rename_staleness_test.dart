import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "../../helpers/test_chat_history.dart";
import "../../helpers/test_database.dart";
import "../routing/routing_test_helpers.dart";

void main() {
  // The staleness comparison must react to backend activity only. Renaming is
  // a bridge-local write that moves the catalog `updatedAt`; if the store
  // compared against that, every rename would cold-start the backend — the
  // exact cost this feature exists to remove. Uses the real repository and DAO
  // so the rename genuinely writes the column it would be compared against.
  test("renaming a synced session does not re-fetch its history", () async {
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
    await history.service.getSessionMessages(sessionId: "ses_a");
    expect(plugin.lastGetMessagesSessionId, isNotNull);

    plugin.lastGetMessagesSessionId = null;
    await sessionRepository.setSessionTitleIfStored(sessionId: "ses_a", title: "renamed");
    await history.service.getSessionMessages(sessionId: "ses_a");

    expect(
      plugin.lastGetMessagesSessionId,
      isNull,
      reason: "a rename is a bridge-local write, not backend activity",
    );
  });
}
