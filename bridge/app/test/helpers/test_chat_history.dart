import "dart:io";

import "package:drift/native.dart";
import "package:sesori_bridge/src/api/attachment_spill_storage.dart";
import "package:sesori_bridge/src/api/database/history/chat_history_database.dart";
import "package:sesori_bridge/src/bridge/repositories/chat_history_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/services/chat_history_service.dart";
import "package:test/test.dart";

typedef TestChatHistory = ({
  ChatHistoryDatabase database,
  AttachmentSpillStorage spillStorage,
  ChatHistoryRepository repository,
  ChatHistoryService service,
  Directory directory,
});

/// An in-memory chat history stack with spill files under a temp directory.
///
/// Registers its own teardown, so it must be created from a test, `setUp`, or
/// another callback the test framework is running.
///
/// [sessionRepository] is only needed by backfill; tests that never backfill
/// can leave it null and get a repository that fails loudly if asked.
TestChatHistory createTestChatHistory({SessionRepository? sessionRepository}) {
  final directory = Directory.systemTemp.createTempSync("sesori_chat_history_test");
  final database = ChatHistoryDatabase(NativeDatabase.memory());
  final spillStorage = AttachmentSpillStorage(
    directoryPath: attachmentSpillDirectoryPath(dataDirectory: directory.path),
  );
  final repository = ChatHistoryRepository(
    chatHistoryDao: database.chatHistoryDao,
    attachmentSpillStorage: spillStorage,
  );
  addTearDown(() async {
    await database.close();
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });
  return (
    database: database,
    spillStorage: spillStorage,
    repository: repository,
    service: ChatHistoryService(
      chatHistoryRepository: repository,
      sessionRepository: sessionRepository ?? _UnusedSessionRepository(),
    ),
    directory: directory,
  );
}

/// Fails on any call: a test that reaches the plugin path should have supplied
/// its own repository instead of silently backfilling from nothing.
class _UnusedSessionRepository implements SessionRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      "createTestChatHistory() was called without a sessionRepository, but "
      "${invocation.memberName} was invoked",
    );
  }
}
