import "dart:io";
import "dart:typed_data";

import "package:path/path.dart" as path;
import "package:sesori_bridge/src/api/attachment_spill_storage.dart";
import "package:sesori_bridge/src/api/database/history/chat_history_database.dart";
import "package:test/test.dart";

import "../../helpers/test_chat_history.dart";

void main() {
  group("chat history purge", () {
    late TestChatHistory history;

    setUp(() {
      history = createTestChatHistory();
    });

    Future<void> seedSession({required String sessionId}) async {
      final database = history.database;
      await database
          .into(database.historyMessagesTable)
          .insert(
            HistoryMessagesTableCompanion.insert(
              sessionId: sessionId,
              messageId: "msg-1",
              seq: 1,
              infoJson: "{}",
              updatedAt: 10,
            ),
          );
      await database
          .into(database.historyPartsTable)
          .insert(
            HistoryPartsTableCompanion.insert(
              sessionId: sessionId,
              messageId: "msg-1",
              partId: "part-1",
              orderIndex: 0,
              partJson: "{}",
              updatedAt: 10,
            ),
          );
      await database
          .into(database.historySyncStateTable)
          .insert(
            HistorySyncStateTableCompanion.insert(
              sessionId: sessionId,
              watermark: 10,
              backendActivityAt: 10,
            ),
          );
      await history.spillStorage.write(
        scope: testAttachmentStorageScope(sessionId: sessionId),
        bytes: Uint8List.fromList([1, 2, 3]),
      );
    }

    test("removes only local rows and retains shared spill files", () async {
      await seedSession(sessionId: "ses_a");
      await seedSession(sessionId: "ses_b");
      final firstScope = Directory(
        history.spillStorage.scopeDirectoryPath(
          scope: testAttachmentStorageScope(sessionId: "ses_a"),
        ),
      );
      final secondScope = Directory(
        history.spillStorage.scopeDirectoryPath(
          scope: testAttachmentStorageScope(sessionId: "ses_b"),
        ),
      );

      await history.service.purgeSessionHistory(sessionId: "ses_a");

      final database = history.database;
      expect(
        (await database.select(database.historyMessagesTable).get()).map((row) => row.sessionId),
        const ["ses_b"],
      );
      expect(
        (await database.select(database.historyPartsTable).get()).map((row) => row.sessionId),
        const ["ses_b"],
      );
      expect(
        (await database.select(database.historySyncStateTable).get()).map((row) => row.sessionId),
        const ["ses_b"],
      );
      expect(firstScope.existsSync(), isTrue);
      expect(secondScope.existsSync(), isTrue);
    });

    test("purging an unknown session is a no-op", () async {
      await seedSession(sessionId: "ses_a");

      await history.service.purgeSessionHistory(sessionId: "ses_missing");

      final database = history.database;
      expect(await database.select(database.historyMessagesTable).get(), hasLength(1));
    });

    test("writes for one session run one at a time", () async {
      await seedSession(sessionId: "ses_a");

      final first = history.service.purgeSessionHistory(sessionId: "ses_a");
      final second = history.service.purgeSessionHistory(sessionId: "ses_a");
      await Future.wait([first, second]);

      final database = history.database;
      expect(await database.select(database.historyMessagesTable).get(), isEmpty);
    });

    test("a family is purged in one batch", () async {
      await seedSession(sessionId: "ses_root");
      await seedSession(sessionId: "ses_child");
      await seedSession(sessionId: "ses_other");

      await history.service.purgeSessionsHistory(sessionIds: ["ses_root", "ses_child"]);

      final database = history.database;
      expect(
        (await database.select(database.historyMessagesTable).get()).map((row) => row.sessionId),
        const ["ses_other"],
      );
      for (final sessionId in ["ses_root", "ses_child", "ses_other"]) {
        expect(
          Directory(
            history.spillStorage.scopeDirectoryPath(
              scope: testAttachmentStorageScope(sessionId: sessionId),
            ),
          ).existsSync(),
          isTrue,
        );
      }
    });

    test("a family larger than SQLite's bind-variable limit still purges", () async {
      // Rows only: the chunking under test is a SQL-statement concern, and
      // seeding spill files for every id would make this a filesystem
      // benchmark instead.
      final sessionIds = [for (var index = 0; index < 1200; index++) "ses_$index"];
      final database = history.database;
      await database.batch((batch) {
        batch.insertAll(database.historyMessagesTable, [
          for (final sessionId in [...sessionIds, "ses_survivor"])
            HistoryMessagesTableCompanion.insert(
              sessionId: sessionId,
              messageId: "msg-1",
              seq: 1,
              infoJson: "{}",
              updatedAt: 10,
            ),
        ]);
      });

      await history.service.purgeSessionsHistory(sessionIds: sessionIds);

      expect(
        (await database.select(database.historyMessagesTable).get()).map((row) => row.sessionId),
        const ["ses_survivor"],
      );
    });

    test("an empty batch is a no-op", () async {
      await seedSession(sessionId: "ses_a");

      await history.service.purgeSessionsHistory(sessionIds: const []);

      final database = history.database;
      expect(await database.select(database.historyMessagesTable).get(), hasLength(1));
    });

    test("reading a malformed digest is refused instead of escaping the directory", () async {
      expect(
        () => history.spillStorage.read(
          scope: testAttachmentStorageScope(sessionId: "ses_a"),
          digest: "../../../etc/passwd",
        ),
        throwsArgumentError,
      );
    });

    test("identical attachment bytes are stored once per backend session", () async {
      final bytes = Uint8List.fromList([9, 9, 9]);
      final scope = testAttachmentStorageScope(sessionId: "ses_a");
      final first = await history.spillStorage.write(scope: scope, bytes: bytes);
      final second = await history.spillStorage.write(scope: scope, bytes: bytes);

      expect(first, second);
      final scopeDirectory = Directory(history.spillStorage.scopeDirectoryPath(scope: scope));
      expect(scopeDirectory.listSync(), hasLength(1));
      expect(await history.spillStorage.read(scope: scope, digest: first), bytes);
      expect(await history.spillStorage.read(scope: scope, digest: "0" * 64), isNull);
    });

    test("separate bridge stores reuse one durable backend-session scope", () async {
      final root = path.join(history.directory.path, "shared-attachments");
      final firstStore = AttachmentSpillStorage(directoryPath: root)..ensureDirectory();
      final secondStore = AttachmentSpillStorage(directoryPath: root)..ensureDirectory();
      const firstScope = AttachmentStorageScope(
        pluginId: "opencode",
        backendSessionId: "backend-session-1",
      );
      const secondScope = AttachmentStorageScope(
        pluginId: "opencode",
        backendSessionId: "backend-session-1",
      );
      final bytes = Uint8List.fromList([7, 8, 9]);

      final firstDigest = await firstStore.write(scope: firstScope, bytes: bytes);
      final secondDigest = await secondStore.write(scope: secondScope, bytes: bytes);

      expect(secondDigest, firstDigest);
      expect(
        Directory(firstStore.scopeDirectoryPath(scope: firstScope)).listSync(),
        hasLength(1),
      );
      expect(await secondStore.read(scope: secondScope, digest: firstDigest), bytes);
    });

    test("the same digest in another backend-session scope is isolated", () async {
      final bytes = Uint8List.fromList([4, 5, 6]);
      final firstScope = testAttachmentStorageScope(sessionId: "ses_a");
      final digest = await history.spillStorage.write(scope: firstScope, bytes: bytes);
      final otherScope = testAttachmentStorageScope(sessionId: "ses_b");

      expect(await history.spillStorage.read(scope: otherScope, digest: digest), isNull);
    });

    test("plugin and backend identifiers cannot traverse the shared root", () async {
      final root = path.join(history.directory.path, "traversal-attachments");
      final storage = AttachmentSpillStorage(directoryPath: root)..ensureDirectory();
      const scope = AttachmentStorageScope(
        pluginId: "../../plugin",
        backendSessionId: "../backend/session",
      );
      final bytes = Uint8List.fromList([1, 3, 5]);

      final digest = await storage.write(scope: scope, bytes: bytes);

      expect(path.isWithin(root, storage.scopeDirectoryPath(scope: scope)), isTrue);
      expect(await storage.read(scope: scope, digest: digest), bytes);
    });
  });
}
