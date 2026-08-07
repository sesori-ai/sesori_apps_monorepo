import "dart:io";

import "package:drift/native.dart";
import "package:sesori_bridge/src/api/attachment_spill_storage.dart";
import "package:sesori_bridge/src/api/database/history/chat_history_database.dart";
import "package:sesori_bridge/src/bridge/repositories/chat_history_repository.dart";
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
TestChatHistory createTestChatHistory() {
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
    service: ChatHistoryService(chatHistoryRepository: repository),
    directory: directory,
  );
}
