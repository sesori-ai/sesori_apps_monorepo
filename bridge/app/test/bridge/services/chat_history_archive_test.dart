import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:sesori_bridge/src/api/archived_session_storage.dart";
import "package:sesori_bridge/src/api/models/archived_session_file_dto.dart";
import "package:sesori_bridge/src/repositories/chat_history_repository.dart";
import "package:sesori_bridge/src/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/services/chat_history_reconcile_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_chat_history.dart";

void main() {
  group("archiving history", () {
    late TestChatHistory history;
    late _FakeSessionRepository repository;

    setUp(() async {
      repository = _FakeSessionRepository(
        transcript: [
          _messageWithParts(id: "m1"),
          _messageWithParts(id: "m2"),
        ],
      )..archived = true;
      history = createTestChatHistory(sessionRepository: repository);
      await history.service.backfillSession(sessionId: "ses_a");
    });

    Future<void> export() => history.service.exportSessionHistory(
      session: _storedSession(),
      title: "Archived session",
      lastAgent: "build",
      lastAgentModel: "claude-sonnet",
      createdAt: 100,
      updatedAt: 200,
      archivedAt: 300,
    );

    test("the audit file round-trips the transcript", () async {
      await export();

      final page = await history.service.getArchivedSessionMessages(sessionId: "ses_a");
      expect(page!.messages.map((message) => message.info.id), const ["m1", "m2"]);
      expect(page.nextCursor, isNull);
    });

    test("rehydrates a released flattened part from an audit file", () async {
      await export();
      final raw = jsonDecodeMap((await history.archivedStorage.read(sessionId: "ses_a"))!);
      final messages = raw["messages"] as List<dynamic>;
      final firstMessage = messages.first as Map<String, dynamic>;
      firstMessage["parts"] = [
        {
          "id": "legacy-retry",
          "sessionID": "ses_a",
          "messageID": "m1",
          "type": "retry",
          "attempt": 2,
        },
      ];
      await history.archivedStorage.write(sessionId: "ses_a", contents: jsonEncode(raw));

      final page = await history.service.getArchivedSessionMessages(sessionId: "ses_a");

      expect(
        page!.messages.first.parts.single,
        const MessagePart.retry(
          id: "legacy-retry",
          sessionID: "ses_a",
          messageID: "m1",
          attempt: 2,
          retryError: null,
        ),
      );
    });

    test("the archived transcript survives purging the live store", () async {
      await export();
      await history.service.purgeSessionHistory(sessionId: "ses_a");

      expect(
        (await history.repository.getSessionMessages(
          sessionId: "ses_a",
          storageScope: testAttachmentStorageScope(sessionId: "ses_a"),
        )).messages,
        isEmpty,
      );
      final served = await history.service.getSessionMessages(sessionId: "ses_a");
      expect(
        served.messages.map((message) => message.info.id),
        const ["m1", "m2"],
        reason: "an archived session reads from its audit file, not the purged store",
      );
      expect(repository.fetchCount, 1, reason: "an archived read must not consult the backend");
    });

    test("archived attachments round-trip through the shared scope", () async {
      final bytes = Uint8List.fromList(List<int>.generate(32, (index) => index));
      await history.service.capturePart(
        sessionId: "ses_a",
        part: _part(
          id: "m1-att",
          messageId: "m1",
          attachment: MessageAttachment.inlineImage(
            mime: "image/png",
            base64: base64Encode(bytes),
            filename: "shot.png",
          ),
        ),
      );

      await export();
      await history.service.purgeSessionHistory(sessionId: "ses_a");

      final page = await history.service.getArchivedSessionMessages(sessionId: "ses_a");
      final attachment = page!.messages
          .expand((message) => message.parts)
          .whereType<MessagePartFile>()
          .map((part) => part.attachment)
          .whereType<MessageAttachmentInlineImage>()
          .single;
      expect(attachment.base64, base64Encode(bytes));
      expect(attachment.filename, "shot.png");
    });

    test("archived pages use the same exclusive cursor as the live store", () async {
      await export();
      await history.service.purgeSessionHistory(sessionId: "ses_a");

      final first = await history.service.getArchivedSessionMessages(sessionId: "ses_a", limit: 1);
      expect(first!.messages.single.info.id, "m2");
      expect(first.nextCursor, isNotNull);

      final second = await history.service.getArchivedSessionMessages(
        sessionId: "ses_a",
        limit: 1,
        before: first.nextCursor,
      );
      expect(second!.messages.single.info.id, "m1");
      expect(second.nextCursor, isNull, reason: "the start of the transcript ends paging");
    });

    test("an export that cannot reach the backend is recorded as store-only", () async {
      repository.error = StateError("backend gone");
      await history.repository.clearSyncedAt(sessionId: "ses_a");

      await export();

      final file = ArchivedSessionFileDto.fromJson(
        jsonDecodeMap((await history.archivedStorage.read(sessionId: "ses_a"))!),
      );
      expect(file.completeness, ArchivedSessionCompleteness.storeOnly);
      expect(file.messages, hasLength(2), reason: "it still archives what the store held");
    });

    test("a corrupt audit file is quarantined rather than deleted", () async {
      await export();
      await history.service.purgeSessionHistory(sessionId: "ses_a");
      await history.archivedStorage.write(sessionId: "ses_a", contents: "{ not json");

      expect(await history.service.getArchivedSessionMessages(sessionId: "ses_a"), isNull);

      final quarantined = Directory(
        history.directory.path,
      ).listSync(recursive: true).whereType<File>().where((file) => file.path.contains(".corrupt-"));
      expect(quarantined, hasLength(1), reason: "the only copy of the transcript is preserved for inspection");
    });

    test("a newer schema version is refused instead of silently misread", () async {
      await history.archivedStorage.write(
        sessionId: "ses_a",
        contents: jsonEncode({
          "schemaVersion": 99,
          "archivedAt": 1,
          "completeness": "complete",
          "session": _storedSessionJson(),
          "messages": <Map<String, dynamic>>[],
        }),
      );

      await expectLater(
        history.service.getArchivedSessionMessages(sessionId: "ses_a"),
        throwsA(isA<ChatHistoryArchiveVersionException>()),
      );
    });

    test("an orphan audit file does not shadow a still-live transcript", () async {
      // Export writes the file before the archive flip, so a failed archive
      // leaves a file for a session that is still live. Serving it would hide
      // messages the store has and the file does not.
      repository.archived = false;
      await export();
      await history.service.captureMessage(
        sessionId: "ses_a",
        message: _message(id: "m3"),
      );

      final served = await history.service.getSessionMessages(sessionId: "ses_a");

      expect(
        served.messages.map((message) => message.info.id),
        containsAll(const ["m1", "m2", "m3"]),
        reason: "a session that is not archived reads from the live store",
      );
    });

    test("reconcile keeps live rows when the archive never completed", () async {
      repository.archived = false;
      await export();
      repository.existingSessionIds = {"ses_a"};
      repository.archivedSessionIds = const {};

      await ChatHistoryReconcileService(
        sessionRepository: repository,
        chatHistoryService: history.service,
      ).reconcile();

      expect(
        (await history.repository.getSessionMessages(
          sessionId: "ses_a",
          storageScope: testAttachmentStorageScope(sessionId: "ses_a"),
        )).messages,
        hasLength(2),
        reason: "a pre-flip export failure must not cost the only copy of the transcript",
      );
    });

    test("re-archiving does not overwrite a complete audit file", () async {
      await export();
      await history.service.purgeSessionHistory(sessionId: "ses_a");
      // The live store is empty now, and the backend is unreachable, so a
      // second export would write an empty store-only archive.
      repository.error = StateError("backend gone");

      await history.service.exportSessionHistory(
        session: _archivedStoredSession(),
        title: "Archived session",
        lastAgent: null,
        lastAgentModel: null,
        createdAt: 100,
        updatedAt: 200,
        archivedAt: 400,
      );

      final page = await history.service.getArchivedSessionMessages(sessionId: "ses_a");
      expect(
        page!.messages.map((message) => message.info.id),
        const ["m1", "m2"],
        reason: "the durable transcript must survive a repeated archive request",
      );
    });

    test("archived paging refuses a non-positive limit without crashing", () async {
      await export();
      await history.service.purgeSessionHistory(sessionId: "ses_a");

      final page = await history.service.getArchivedSessionMessages(sessionId: "ses_a", limit: 0);

      expect(page!.messages, isEmpty);
      expect(page.nextCursor, isNull);
    });

    test("the archived snapshot keeps the agent metadata", () async {
      await export();

      final file = ArchivedSessionFileDto.fromJson(
        jsonDecodeMap((await history.archivedStorage.read(sessionId: "ses_a"))!),
      );
      expect(file.session.lastAgent, "build");
      expect(file.session.lastAgentModel, "claude-sonnet");
    });

    test("an unrecognised schema version is refused, not decoded as v1", () async {
      for (final version in <Object?>[0, 99, "1", null]) {
        await history.archivedStorage.write(
          sessionId: "ses_a",
          contents: jsonEncode({
            "schemaVersion": version,
            "archivedAt": 1,
            "completeness": "complete",
            "session": _storedSessionJson(),
            "messages": <Map<String, dynamic>>[],
          }),
        );

        await expectLater(
          history.service.getArchivedSessionMessages(sessionId: "ses_a"),
          throwsA(isA<ChatHistoryArchiveVersionException>()),
          reason: "version $version is not the supported format",
        );
      }
    });

    test("malformed audit bytes are quarantined instead of failing the read", () async {
      await export();
      await history.service.purgeSessionHistory(sessionId: "ses_a");
      // Invalid UTF-8, not merely invalid JSON.
      final archiveDirectory = Directory(archiveDirectoryPath(dataDirectory: history.directory.path));
      for (final file in archiveDirectory.listSync().whereType<File>()) {
        file.writeAsBytesSync([0xC3, 0x28, 0xA0, 0xA1]);
      }

      expect(await history.service.getArchivedSessionMessages(sessionId: "ses_a"), isNull);

      final quarantined = archiveDirectory.listSync().whereType<File>().where(
        (file) => file.path.contains(".corrupt-"),
      );
      expect(quarantined, hasLength(1));
    });

    test("an interrupted write leaves the previous transcript readable", () async {
      await export();
      final original = await history.archivedStorage.read(sessionId: "ses_a");
      // A newer generation that never finished writing: present, but not
      // valid content.
      final archiveDirectory = Directory(archiveDirectoryPath(dataDirectory: history.directory.path));
      File(
        "${archiveDirectory.path}/${base64Url.encode(utf8.encode("ses_a"))}.99.json",
      ).writeAsBytesSync([0xC3, 0x28, 0xA0, 0xA1]);

      expect(
        await history.archivedStorage.read(sessionId: "ses_a"),
        original,
        reason: "a half-written newer generation must not cost the previous transcript",
      );
      expect(await history.archivedStorage.exists(sessionId: "ses_a"), isTrue);
    });

    test("a decode failure on the newest generation keeps the older one", () async {
      await export();
      final original = await history.archivedStorage.read(sessionId: "ses_a");
      // Valid UTF-8 but not a valid envelope: the repository decodes it, fails,
      // and quarantines. The older generation must survive as the fallback.
      final archiveDirectory = Directory(archiveDirectoryPath(dataDirectory: history.directory.path));
      File(
        "${archiveDirectory.path}/${base64Url.encode(utf8.encode("ses_a"))}.99.json",
      ).writeAsStringSync("{ not an envelope");

      // First read quarantines the bad newest generation.
      await history.service.getArchivedSessionMessages(sessionId: "ses_a");

      expect(
        await history.archivedStorage.read(sessionId: "ses_a"),
        original,
        reason: "quarantining the unreadable newest must not take the last good archive with it",
      );
    });

    test("an interrupted first write leaves no partial generation", () async {
      // Nothing under a generation name is ever partial: writes land through a
      // temp file, so a crash leaves a .tmp that no reader matches.
      final archiveDirectory = Directory(archiveDirectoryPath(dataDirectory: history.directory.path));
      await archiveDirectory.create(recursive: true);
      File(
        "${archiveDirectory.path}/${base64Url.encode(utf8.encode("ses_b"))}.1.json.1234.5678.tmp",
      ).writeAsStringSync("{ partial");

      expect(await history.archivedStorage.exists(sessionId: "ses_b"), isFalse);
      expect(await history.archivedStorage.read(sessionId: "ses_b"), isNull);
      expect(await history.archivedStorage.listArchivedSessionIds(), isNot(contains("ses_b")));
    });

    test("writing again supersedes the previous generation", () async {
      await export();

      await history.archivedStorage.write(sessionId: "ses_a", contents: '{"schemaVersion":1}');

      final archiveDirectory = Directory(archiveDirectoryPath(dataDirectory: history.directory.path));
      final files = archiveDirectory.listSync().whereType<File>().toList();
      expect(files, hasLength(1), reason: "superseded generations are removed");
      expect(await history.archivedStorage.read(sessionId: "ses_a"), contains("schemaVersion"));
    });

    test("deleting a session removes every generation", () async {
      await export();
      // A leftover older generation, as an interrupted cleanup would leave.
      final archiveDirectory = Directory(archiveDirectoryPath(dataDirectory: history.directory.path));
      File("${archiveDirectory.path}/${base64Url.encode(utf8.encode("ses_a"))}.1.json").writeAsStringSync("{}");

      await history.service.purgeSessionHistory(sessionId: "ses_a", includeArchive: true);

      expect(await history.archivedStorage.listArchivedSessionIds(), isEmpty);
      expect(await history.archivedStorage.exists(sessionId: "ses_a"), isFalse);
    });

    test("deleting a session removes its archive too", () async {
      await export();

      await history.service.purgeSessionHistory(sessionId: "ses_a", includeArchive: true);

      expect(await history.archivedStorage.read(sessionId: "ses_a"), isNull);
      expect(await history.service.getArchivedSessionMessages(sessionId: "ses_a"), isNull);
    });

    test("reconcile finishes a purge interrupted between the flip and the purge", () async {
      await export();
      // The crash window: the audit file is durable but the live rows survive.
      expect(
        (await history.repository.getSessionMessages(
          sessionId: "ses_a",
          storageScope: testAttachmentStorageScope(sessionId: "ses_a"),
        )).messages,
        hasLength(2),
      );
      repository.existingSessionIds = {"ses_a"};
      repository.archivedSessionIds = {"ses_a"};

      await ChatHistoryReconcileService(
        sessionRepository: repository,
        chatHistoryService: history.service,
      ).reconcile();

      expect(
        (await history.repository.getSessionMessages(
          sessionId: "ses_a",
          storageScope: testAttachmentStorageScope(sessionId: "ses_a"),
        )).messages,
        isEmpty,
      );
      expect(
        await history.archivedStorage.read(sessionId: "ses_a"),
        isNotNull,
        reason: "the archive is authoritative and must survive",
      );
    });

    test("reconcile purges an archive whose session left the catalog", () async {
      await export();
      repository.existingSessionIds = const {};

      await ChatHistoryReconcileService(
        sessionRepository: repository,
        chatHistoryService: history.service,
      ).reconcile();

      expect(await history.archivedStorage.read(sessionId: "ses_a"), isNull);
    });
  });
}

StoredSession _archivedStoredSession() => const StoredSession(
  id: "ses_a",
  backendSessionId: "backend-a",
  pluginId: "fake",
  projectId: "project-a",
  parentSessionId: null,
  directory: "/projects/a",
  worktreePath: null,
  branchName: null,
  isDedicated: false,
  archivedAt: 300,
  baseBranch: null,
  baseCommit: null,
);

StoredSession _storedSession() => const StoredSession(
  id: "ses_a",
  backendSessionId: "backend-a",
  pluginId: "fake",
  projectId: "project-a",
  parentSessionId: null,
  directory: "/projects/a",
  worktreePath: null,
  branchName: null,
  isDedicated: false,
  archivedAt: null,
  baseBranch: null,
  baseCommit: null,
);

Map<String, dynamic> _storedSessionJson() => {
  "sessionId": "ses_a",
  "backendSessionId": "backend-a",
  "pluginId": "fake",
  "projectId": "project-a",
  "directory": "/projects/a",
  "createdAt": 1,
  "updatedAt": 2,
};

Message _message({required String id}) => Message.user(
  promptId: null,
  id: id,
  sessionID: "ses_a",
  agent: null,
  time: const MessageTime(created: 1, completed: null),
);

MessagePart _part({
  required String id,
  required String messageId,
  MessageAttachment? attachment,
}) => attachment == null
    ? MessagePart.text(id: id, sessionID: "ses_a", messageID: messageId, text: "text of $messageId")
    : MessagePart.file(id: id, sessionID: "ses_a", messageID: messageId, attachment: attachment);

MessageWithParts _messageWithParts({required String id}) => MessageWithParts(
  info: _message(id: id),
  parts: [_part(id: "$id-p1", messageId: id)],
);

class _FakeSessionRepository({required final List<MessageWithParts> transcript}) implements SessionRepository {
  Object? error;
  Set<String> existingSessionIds = const {};
  Set<String> archivedSessionIds = const {};
  bool archived = false;
  int fetchCount = 0;

  @override
  Future<StoredSession?> getStoredSession({required String sessionId}) async =>
      archived ? _archivedStoredSession() : _storedSession();

  @override
  Future<Set<String>> getArchivedSessionIds({required Set<String> sessionIds}) async =>
      sessionIds.intersection(archivedSessionIds);

  @override
  Future<List<MessageWithParts>> getSessionMessages({required String sessionId}) async {
    fetchCount++;
    final failure = error;
    if (failure != null) throw failure;
    return transcript;
  }

  @override
  Future<Set<String>> getExistingSessionIds({required Set<String> sessionIds}) async =>
      sessionIds.intersection(existingSessionIds);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
