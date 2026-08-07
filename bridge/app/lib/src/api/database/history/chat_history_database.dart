import "dart:io";

import "package:drift/drift.dart";
import "package:drift/native.dart";
import "package:path/path.dart" as path;

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
class ChatHistoryDatabase extends _$ChatHistoryDatabase {
  ChatHistoryDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => m.createAll(),
    beforeOpen: (details) async {
      await customStatement("PRAGMA foreign_keys = ON");
    },
  );

  static ChatHistoryDatabase create({required String dataDirectory}) {
    final dbDir = Directory(dataDirectory);
    if (!dbDir.existsSync()) {
      dbDir.createSync(recursive: true);
    }
    if (!Platform.isWindows) {
      _setUnixMode(targetPath: dbDir.path, mode: "700");
    }
    final dbFile = File(path.join(dbDir.path, "chat_history.db"));
    if (!Platform.isWindows) {
      if (!dbFile.existsSync()) {
        dbFile.createSync();
      }
      _setUnixMode(targetPath: dbFile.path, mode: "600");
    }
    return openFile(file: dbFile);
  }

  static void _setUnixMode({required String targetPath, required String mode}) {
    final result = Process.runSync("chmod", [mode, targetPath]);
    if (result.exitCode != 0) {
      throw FileSystemException("Failed to set mode $mode", targetPath);
    }
  }

  static ChatHistoryDatabase openFile({required File file}) {
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
