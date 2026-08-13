import "dart:io";

import "package:drift/drift.dart";
import "package:drift/native.dart";
import "package:path/path.dart" as path;

import "../../data_directory_hardening.dart";
import "chat_history_dao.dart";
import "tables/history_messages_table.dart";
import "tables/history_parts_table.dart";
import "tables/history_sync_state_table.dart";

part "chat_history_database.g.dart";

/// Live chat transcripts, deliberately kept out of `sesori.db`.
///
/// Transcript rows churn far more than catalog rows and are purged wholesale
/// when a session is archived or deleted, so they get their own file: the main
/// database stays small, its WAL stays quiet, and reclaiming space after a
/// purge is a cheap `incremental_vacuum` here instead of a full vacuum there.
/// `sessionId` references `sesori.db` only logically; there are no cross-file
/// foreign keys, and cross-store consistency is reconciled at startup.
@DriftDatabase(
  tables: [HistoryMessagesTable, HistoryPartsTable, HistorySyncStateTable],
  daos: [ChatHistoryDao],
)
class ChatHistoryDatabase(super.e) extends _$ChatHistoryDatabase {
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => await m.createAll(),
    beforeOpen: (details) async {
      await customStatement("PRAGMA foreign_keys = ON");
    },
  );

  static ChatHistoryDatabase create({required String dataDirectory}) {
    final directory = createHardenedDirectory(directoryPath: dataDirectory);
    return _openFile(
      file: createHardenedFile(filePath: path.join(directory.path, "chat_history.db")),
    );
  }

  static ChatHistoryDatabase _openFile({required File file}) {
    return ChatHistoryDatabase(
      NativeDatabase.createInBackground(
        file,
        setup: (database) {
          // Must precede table creation to take effect on a fresh file; a
          // no-op on an already-populated one. Purge-on-archive then returns
          // space through incremental_vacuum instead of a full VACUUM.
          database.execute("PRAGMA auto_vacuum = INCREMENTAL");
          database.execute("PRAGMA journal_mode = WAL");
        },
      ),
    );
  }
}
