import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/pending_interaction_support.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "../routing/routing_test_helpers.dart";

void main() {
  // An archived session refuses replies, so its pending questions and
  // permissions are hidden like its forms and external actions. Archive
  // enforcement belongs to the actual owner, not the display parent.
  group("PendingInteractionSupport archived owners", () {
    late AppDatabase database;
    late PendingInteractionSupport support;

    setUp(() async {
      database = createTestDatabase();
      addTearDown(database.close);
      support = PendingInteractionSupport(sessionDao: database.sessionDao);
      for (final (sessionId, parentSessionId) in [("root", null), ("child", "root")]) {
        await recordSessionBinding(
          database: database,
          sessionId: sessionId,
          backendSessionId: "$sessionId-native",
          pluginId: "fake",
          projectId: "project",
          parentSessionId: parentSessionId,
        );
      }
    });

    Future<List<String>> visibleOwners() async {
      final questions = await support.mapQuestions(
        pluginId: "fake",
        questions: [
          for (final owner in ["root-native", "child-native"])
            PluginPendingQuestion(
              interactionKind: PluginQuestionInteractionKind.question,
              id: "question-$owner",
              sessionID: owner,
              displaySessionId: "root-native",
              questions: const [],
            ),
        ],
      );
      final permissions = await support.mapPermissions(
        pluginId: "fake",
        permissions: [
          for (final owner in ["root-native", "child-native"])
            PluginPendingPermission(
              id: "permission-$owner",
              sessionID: owner,
              displaySessionId: "root-native",
              tool: "bash",
              description: "Run ls",
              allowAlways: false,
            ),
        ],
      );
      return [
        for (final question in questions) "question:${question.sessionID}",
        for (final permission in permissions) "permission:${permission.sessionID}",
      ];
    }

    test("an archived owner's questions and permissions are hidden", () async {
      await database.sessionDao.setArchived(sessionId: "child", archivedAt: 2, updatedAt: 2, projectionUpdatedAt: 2);
      expect(await visibleOwners(), ["question:root", "permission:root"]);
    });

    test("an archived display parent does not hide an active child's own requests", () async {
      await database.sessionDao.setArchived(sessionId: "root", archivedAt: 2, updatedAt: 2, projectionUpdatedAt: 2);
      expect(await visibleOwners(), ["question:child", "permission:child"]);
    });
  });
}
