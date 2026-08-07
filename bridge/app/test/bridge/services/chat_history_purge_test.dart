import "dart:io";
import "dart:typed_data";

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
        sessionId: sessionId,
        bytes: Uint8List.fromList([1, 2, 3]),
      );
    }

    test("removes only the purged session's rows and spill files", () async {
      await seedSession(sessionId: "ses_a");
      await seedSession(sessionId: "ses_b");
      final spillRoot = Directory(
        attachmentSpillDirectoryPath(dataDirectory: history.directory.path),
      );
      expect(spillRoot.listSync(), hasLength(2));

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
      expect(spillRoot.listSync(), hasLength(1));
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
      final spillRoot = Directory(
        attachmentSpillDirectoryPath(dataDirectory: history.directory.path),
      );
      expect(spillRoot.listSync(), hasLength(1));
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
        () => history.spillStorage.read(sessionId: "ses_a", digest: "../../../etc/passwd"),
        throwsArgumentError,
      );
    });

    test("identical attachment bytes are stored once per session", () async {
      final bytes = Uint8List.fromList([9, 9, 9]);
      final first = await history.spillStorage.write(sessionId: "ses_a", bytes: bytes);
      final second = await history.spillStorage.write(sessionId: "ses_a", bytes: bytes);

      expect(first, second);
      final spillRoot = Directory(
        attachmentSpillDirectoryPath(dataDirectory: history.directory.path),
      );
      expect(spillRoot.listSync().single, isA<Directory>());
      expect(await history.spillStorage.read(sessionId: "ses_a", digest: first), bytes);
      expect(await history.spillStorage.read(sessionId: "ses_a", digest: "0" * 64), isNull);
    });
  });
}
