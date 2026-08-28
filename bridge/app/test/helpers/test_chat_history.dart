import "dart:io";

import "package:drift/native.dart";
import "package:path/path.dart" as path;
import "package:sesori_bridge/src/api/archived_session_storage.dart";
import "package:sesori_bridge/src/api/attachment_spill_storage.dart";
import "package:sesori_bridge/src/api/database/history/chat_history_database.dart";
import "package:sesori_bridge/src/auth/bridge_id_provider.dart";
import "package:sesori_bridge/src/repositories/attachment_thumbnail_builder.dart";
import "package:sesori_bridge/src/repositories/chat_history_repository.dart";
import "package:sesori_bridge/src/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/services/chat_history_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

typedef TestChatHistory = ({
  ChatHistoryDatabase database,
  AttachmentSpillStorage spillStorage,
  ArchivedSessionStorage archivedStorage,
  TestChatHistoryRepository repository,
  TestChatHistoryService service,
  Directory directory,
});

/// An in-memory chat history stack with spill files under a temp directory.
///
/// Registers its own teardown, so it must be created from a test, `setUp`, or
/// another callback the test framework is running.
///
/// [sessionRepository] is only needed by backfill; tests that never backfill
/// can leave it null and get a repository that fails loudly if asked.
TestChatHistory createTestChatHistory({
  SessionRepository? sessionRepository,
  AttachmentThumbnailBuilder attachmentThumbnailBuilder = const AttachmentThumbnailBuilder(),
  int? storedSessionArchivedAt,
  BridgeIdProvider bridgeIdProvider = const _TestBridgeIdProvider("br_test1234"),
}) {
  final directory = Directory.systemTemp.createTempSync("sesori_chat_history_test");
  final database = ChatHistoryDatabase(NativeDatabase.memory());
  final spillStorage = AttachmentSpillStorage(
    directoryPath: path.join(directory.path, "attachments"),
  );
  final archivedStorage = ArchivedSessionStorage(
    directoryPath: archiveDirectoryPath(dataDirectory: directory.path),
  );
  final repository = TestChatHistoryRepository(
    chatHistoryDao: database.chatHistoryDao,
    attachmentSpillStorage: spillStorage,
    archivedSessionStorage: archivedStorage,
  );
  addTearDown(() async {
    await database.close();
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });
  return (
    database: database,
    spillStorage: spillStorage,
    archivedStorage: archivedStorage,
    repository: repository,
    service: TestChatHistoryService(
      chatHistoryRepository: repository,
      sessionRepository: sessionRepository ?? _UnusedSessionRepository(archivedAt: storedSessionArchivedAt),
      attachmentThumbnailBuilder: attachmentThumbnailBuilder,
      bridgeIdProvider: bridgeIdProvider,
    ),
    directory: directory,
  );
}

AttachmentStorageScope testAttachmentStorageScope({required String sessionId}) =>
    AttachmentStorageScope(pluginId: "opencode", backendSessionId: sessionId);

class TestChatHistoryRepository({
  required super.chatHistoryDao,
  required super.attachmentSpillStorage,
  required super.archivedSessionStorage,
}) extends ChatHistoryRepository {
  @override
  Future<ChatHistoryPage> getSessionMessages({
    required String sessionId,
    required AttachmentStorageScope storageScope,
    int? limit,
    int? before,
    MessageAttachmentProjection attachmentProjection = const InlineMessageAttachmentProjection(),
  }) => super.getSessionMessages(
    sessionId: sessionId,
    storageScope: storageScope,
    limit: limit,
    before: before,
    attachmentProjection: attachmentProjection,
  );
}

class TestChatHistoryService({
  required super.chatHistoryRepository,
  required super.sessionRepository,
  required super.attachmentThumbnailBuilder,
  required super.bridgeIdProvider,
}) extends ChatHistoryService {
  @override
  Future<SessionMessagesPage> getSessionMessages({
    required String sessionId,
    int? limit,
    int? before,
    MessageAttachmentDelivery attachmentDelivery = MessageAttachmentDelivery.inline,
  }) => super.getSessionMessages(
    sessionId: sessionId,
    limit: limit,
    before: before,
    attachmentDelivery: attachmentDelivery,
  );

  @override
  Future<ChatHistoryPage?> getArchivedSessionMessages({
    required String sessionId,
    int? limit,
    int? before,
    MessageAttachmentDelivery attachmentDelivery = MessageAttachmentDelivery.inline,
  }) => super.getArchivedSessionMessages(
    sessionId: sessionId,
    limit: limit,
    before: before,
    attachmentDelivery: attachmentDelivery,
  );
}

class const _TestBridgeIdProvider(@override final String? bridgeId) implements BridgeIdProvider;

/// Fails on any call: a test that reaches the plugin path should have supplied
/// its own repository instead of silently backfilling from nothing.
class _UnusedSessionRepository({required final int? archivedAt}) implements SessionRepository {
  @override
  Future<StoredSession?> getStoredSession({required String sessionId}) async => StoredSession(
    id: sessionId,
    backendSessionId: sessionId,
    pluginId: "opencode",
    projectId: "project-1",
    parentSessionId: null,
    directory: "/tmp/project-1",
    worktreePath: null,
    branchName: null,
    isDedicated: false,
    archivedAt: archivedAt,
    baseBranch: null,
    baseCommit: null,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      "createTestChatHistory() was called without a sessionRepository, but "
      "${invocation.memberName} was invoked",
    );
  }
}
