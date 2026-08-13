import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:sesori_bridge/src/bridge/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/services/chat_history_reconcile_service.dart";
import "package:sesori_bridge/src/bridge/services/session_event_dispatcher.dart";
import "package:sesori_bridge/src/listeners/chat_history_listener.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_chat_history.dart";

void main() {
  group("chat history capture", () {
    test("stores a message and its parts in arrival order", () async {
      final history = createTestChatHistory();

      await history.service.captureMessage(
        sessionId: "ses_a",
        message: _message(id: "m1"),
      );
      await history.service.capturePart(
        sessionId: "ses_a",
        part: _part(id: "p1", messageId: "m1", text: "one"),
      );
      await history.service.capturePart(
        sessionId: "ses_a",
        part: _part(id: "p2", messageId: "m1", text: "two"),
      );

      final stored = await _storedMessages(history: history, sessionId: "ses_a");
      expect(stored, hasLength(1));
      expect(stored.single.info.id, "m1");
      expect(stored.single.parts.map((part) => part.text), const ["one", "two"]);
    });

    test("a part arriving before its message is kept and joined later", () async {
      final history = createTestChatHistory();

      await history.service.capturePart(
        sessionId: "ses_a",
        part: _part(id: "p1", messageId: "m1", text: "early"),
      );
      await history.service.captureMessage(
        sessionId: "ses_a",
        message: _message(id: "m1"),
      );

      final stored = await _storedMessages(history: history, sessionId: "ses_a");
      expect(stored.single.parts.single.text, "early");
    });

    test("updating a part in place keeps its position", () async {
      final history = createTestChatHistory();
      await history.service.captureMessage(
        sessionId: "ses_a",
        message: _message(id: "m1"),
      );
      await history.service.capturePart(
        sessionId: "ses_a",
        part: _part(id: "p1", messageId: "m1", text: "one"),
      );
      await history.service.capturePart(
        sessionId: "ses_a",
        part: _part(id: "p2", messageId: "m1", text: "two"),
      );

      await history.service.capturePart(
        sessionId: "ses_a",
        part: _part(id: "p1", messageId: "m1", text: "one (final)"),
      );

      final stored = await _storedMessages(history: history, sessionId: "ses_a");
      expect(stored.single.parts.map((part) => part.text), const ["one (final)", "two"]);
    });

    test("removals drop the message and its parts", () async {
      final history = createTestChatHistory();
      await history.service.captureMessage(
        sessionId: "ses_a",
        message: _message(id: "m1"),
      );
      await history.service.capturePart(
        sessionId: "ses_a",
        part: _part(id: "p1", messageId: "m1", text: "one"),
      );
      await history.service.capturePart(
        sessionId: "ses_a",
        part: _part(id: "p2", messageId: "m1", text: "two"),
      );

      await history.service.capturePartRemoved(
        sessionId: "ses_a",
        messageId: "m1",
        partId: "p1",
        shouldCapture: () => true,
      );
      expect(
        (await _storedMessages(history: history, sessionId: "ses_a")).single.parts.map((part) => part.id),
        const ["p2"],
      );

      await history.service.captureMessageRemoved(
        sessionId: "ses_a",
        messageId: "m1",
        shouldCapture: () => true,
      );
      expect(await _storedMessages(history: history, sessionId: "ses_a"), isEmpty);
    });

    test("capture creates a sync row that is not marked synced", () async {
      final history = createTestChatHistory();

      await history.service.captureMessage(
        sessionId: "ses_a",
        message: _message(id: "m1"),
      );

      final state = await history.repository.getSyncState(sessionId: "ses_a");
      expect(state, isNotNull);
      expect(state!.syncedAt, isNull, reason: "only a completed backfill may claim a complete transcript");
      expect(state.watermark, greaterThan(0));
      expect(state.backendActivityAt, greaterThan(0));
    });

    test("an event-stream gap invalidates only this plugin's stored history", () async {
      final repository = _FakeSessionRepository(
        transcript: [_messageWithParts(id: "m1")],
        pluginSessionIds: const {
          "opencode": {"ses_a"},
          "codex": {"ses_b"},
        },
      );
      final history = createTestChatHistory(sessionRepository: repository);
      await history.service.backfillSession(sessionId: "ses_a");
      await history.service.backfillSession(sessionId: "ses_b");
      expect((await history.repository.getSyncState(sessionId: "ses_a"))!.syncedAt, isNotNull);
      expect((await history.repository.getSyncState(sessionId: "ses_b"))!.syncedAt, isNotNull);

      await history.service.invalidatePluginHistory(pluginId: "opencode");
      await history.service.captureMessage(
        sessionId: "ses_a",
        message: _message(id: "m2"),
      );

      expect(
        (await history.repository.getSyncState(sessionId: "ses_a"))!.syncedAt,
        isNull,
        reason: "live captures cannot claim that events missed during the gap were recovered",
      );
      expect(
        (await history.repository.getSyncState(sessionId: "ses_b"))!.syncedAt,
        isNotNull,
        reason: "another plugin's transcript did not cross the event-stream gap",
      );
    });

    test("a server-connected event invalidates its source plugin", () async {
      final repository = _FakeSessionRepository(
        transcript: [_messageWithParts(id: "m1")],
        pluginSessionIds: const {
          "opencode": {"ses_a"},
        },
      );
      final history = createTestChatHistory(sessionRepository: repository);
      await history.service.backfillSession(sessionId: "ses_a");
      final source = StreamController<NormalizedSourcedBridgeEvent>();
      final listener = ChatHistoryListener(
        source: source.stream,
        chatHistoryService: history.service,
      )..start();

      source.add((
        pluginId: "opencode",
        generation: 1,
        event: const BridgeSseServerConnected(),
        allowDuringStop: false,
        terminalHandoffConsumed: null,
      ));
      await source.close();
      await listener.dispose();

      expect((await history.repository.getSyncState(sessionId: "ses_a"))!.syncedAt, isNull);
    });

    test("the listener no longer stores finalized parts", () async {
      final history = createTestChatHistory();
      final source = StreamController<NormalizedSourcedBridgeEvent>();
      final listener = ChatHistoryListener(
        source: source.stream,
        chatHistoryService: history.service,
      )..start();

      source.add((
        pluginId: "opencode",
        generation: 1,
        event: const BridgeSseMessagePartUpdated(
          part: PluginMessagePart(
            id: "p1",
            sessionID: "ses_a",
            messageID: "m1",
            type: PluginMessagePartType.text,
            text: "one",
            tool: null,
            state: null,
            prompt: null,
            description: null,
            agent: null,
            agentName: null,
            attempt: null,
            retryError: null,
            attachment: null,
          ),
        ),
        allowDuringStop: false,
        terminalHandoffConsumed: null,
      ));
      await source.close();
      await listener.dispose();

      expect(
        await history.database.chatHistoryDao.getParts(sessionId: "ses_a"),
        isEmpty,
        reason: "part capture belongs to the Orchestrator, which owns live attachment materialization",
      );
    });

    test("an invalidation failure does not fail listener teardown", () async {
      final repository = _FakeSessionRepository(
        transcript: const [],
        pluginSessionLookupError: StateError("database unavailable"),
      );
      final history = createTestChatHistory(sessionRepository: repository);
      final source = StreamController<NormalizedSourcedBridgeEvent>();
      final listener = ChatHistoryListener(
        source: source.stream,
        chatHistoryService: history.service,
      )..start();

      source.add((
        pluginId: "opencode",
        generation: 1,
        event: const BridgeSseServerConnected(),
        allowDuringStop: false,
        terminalHandoffConsumed: null,
      ));
      await source.close();

      await expectLater(listener.dispose(), completes);
    });

    test("inline attachment bytes are spilled to disk, never stored in the database", () async {
      final history = createTestChatHistory();
      final bytes = Uint8List.fromList(List<int>.generate(64, (index) => index));
      await history.service.captureMessage(
        sessionId: "ses_a",
        message: _message(id: "m1"),
      );

      await history.service.capturePart(
        sessionId: "ses_a",
        part: _part(
          id: "p1",
          messageId: "m1",
          text: "look",
          attachment: MessageAttachment.inlineImage(
            mime: "image/png",
            base64: base64Encode(bytes),
            filename: "shot.png",
          ),
        ),
      );

      final rows = await history.database.chatHistoryDao.getParts(sessionId: "ses_a");
      expect(rows.single.partJson, isNot(contains(base64Encode(bytes))));
      expect(rows.single.partJson, contains("stored_file"));

      final served = (await _storedMessages(history: history, sessionId: "ses_a")).single.parts.single;
      expect(
        served.attachment,
        isA<MessageAttachmentInlineImage>()
            .having((image) => image.base64, "base64", base64Encode(bytes))
            .having((image) => image.filename, "filename", "shot.png"),
      );
    });

    test("a lost spill file degrades the attachment instead of failing the read", () async {
      final history = createTestChatHistory();
      await history.service.captureMessage(
        sessionId: "ses_a",
        message: _message(id: "m1"),
      );
      await history.service.capturePart(
        sessionId: "ses_a",
        part: _part(
          id: "p1",
          messageId: "m1",
          text: "look",
          attachment: MessageAttachment.inlineImage(
            mime: "image/png",
            base64: base64Encode(Uint8List.fromList([1, 2, 3])),
            filename: "shot.png",
          ),
        ),
      );

      await Directory(
        history.spillStorage.scopeDirectoryPath(
          scope: testAttachmentStorageScope(sessionId: "ses_a"),
        ),
      ).delete(recursive: true);

      final served = (await _storedMessages(history: history, sessionId: "ses_a")).single.parts.single;
      expect(
        served.attachment,
        isA<MessageAttachmentMetadata>().having((data) => data.filename, "filename", "shot.png"),
      );
    });
  });

  group("chat history backfill", () {
    test("marks the session synced and numbers the transcript in order", () async {
      final repository = _FakeSessionRepository(
        transcript: [
          _messageWithParts(id: "m1"),
          _messageWithParts(id: "m2"),
        ],
      );
      final history = createTestChatHistory(sessionRepository: repository);

      await history.service.backfillSession(sessionId: "ses_a");

      final stored = await _storedMessages(history: history, sessionId: "ses_a");
      expect(stored.map((message) => message.info.id), const ["m1", "m2"]);
      expect((await history.repository.getSyncState(sessionId: "ses_a"))!.syncedAt, isNotNull);
    });

    test("keeps live messages the fetched transcript does not contain", () async {
      final repository = _FakeSessionRepository(transcript: [_messageWithParts(id: "m1")]);
      final history = createTestChatHistory(sessionRepository: repository);
      await history.service.captureMessage(
        sessionId: "ses_a",
        message: _message(id: "live"),
      );

      await history.service.backfillSession(sessionId: "ses_a");

      final stored = await _storedMessages(history: history, sessionId: "ses_a");
      expect(
        stored.map((message) => message.info.id),
        const ["m1", "live"],
        reason: "a message captured after the fetch must survive above the imported maximum",
      );
    });

    test("a capture during the fetch keeps its newer freshness marks", () async {
      final repository = _FakeSessionRepository(transcript: [_messageWithParts(id: "m1")]);
      final history = createTestChatHistory(sessionRepository: repository);
      // Seed a row so the backfill's pre-fetch snapshot exists and is provably
      // older than the capture that lands during the fetch.
      await history.service.captureMessage(
        sessionId: "ses_a",
        message: _message(id: "seed"),
      );
      final beforeFetch = (await history.repository.getSyncState(sessionId: "ses_a"))!;
      repository.onFetch = () => history.service.captureMessage(
        sessionId: "ses_a",
        message: _message(id: "during-fetch"),
      );

      await history.service.backfillSession(sessionId: "ses_a");

      final state = (await history.repository.getSyncState(sessionId: "ses_a"))!;
      expect(
        state.watermark,
        greaterThanOrEqualTo(beforeFetch.watermark),
        reason: "a backfill must not rewind a watermark advanced during its fetch",
      );
      expect(state.backendActivityAt, greaterThanOrEqualTo(beforeFetch.backendActivityAt));
      expect(state.syncedAt, isNotNull);
    });

    test("a removal captured before the backfill defers to the fetched transcript", () async {
      final repository = _FakeSessionRepository(
        transcript: [
          _messageWithParts(id: "m1"),
          _messageWithParts(id: "m2"),
        ],
      );
      final history = createTestChatHistory(sessionRepository: repository);
      await history.service.captureMessage(
        sessionId: "ses_a",
        message: _message(id: "m2"),
      );

      await history.service.captureMessageRemoved(
        sessionId: "ses_a",
        messageId: "m2",
        shouldCapture: () => true,
      );
      await history.service.backfillSession(sessionId: "ses_a");

      // The fetch happens after the removal, so its transcript is the newer
      // observation. A message the backend still reports is not deleted yet,
      // and mirroring the backend is the point of a backfill.
      expect(
        (await _storedMessages(history: history, sessionId: "ses_a")).map((message) => message.info.id),
        const ["m1", "m2"],
      );
    });

    test("a removal captured during the fetch is not resurrected", () async {
      final repository = _FakeSessionRepository(
        transcript: [
          _messageWithParts(id: "m1"),
          _messageWithParts(id: "m2"),
        ],
      );
      final history = createTestChatHistory(sessionRepository: repository);
      Future<void>? removal;
      repository.onFetch = () async {
        removal = history.service.captureMessageRemoved(
          sessionId: "ses_a",
          messageId: "m2",
          shouldCapture: () => true,
        );
      };

      await history.service.backfillSession(sessionId: "ses_a");
      await removal;

      expect(
        (await _storedMessages(history: history, sessionId: "ses_a")).map((message) => message.info.id),
        const ["m1"],
      );
    });

    test("a part removal racing the backfill is not resurrected", () async {
      final repository = _FakeSessionRepository(transcript: [_messageWithParts(id: "m1")]);
      final history = createTestChatHistory(sessionRepository: repository);
      Future<void>? removal;
      repository.onFetch = () async {
        removal = history.service.capturePartRemoved(
          sessionId: "ses_a",
          messageId: "m1",
          partId: "m1-p1",
          shouldCapture: () => true,
        );
      };

      await history.service.backfillSession(sessionId: "ses_a");
      await removal;

      final stored = await _storedMessages(history: history, sessionId: "ses_a");
      expect(stored.single.parts, isEmpty, reason: "the removal is newer than the fetched transcript");
    });

    test("concurrent reads share one fetch", () async {
      final repository = _FakeSessionRepository(transcript: [_messageWithParts(id: "m1")]);
      final history = createTestChatHistory(sessionRepository: repository);

      await Future.wait([
        history.service.backfillSession(sessionId: "ses_a"),
        history.service.backfillSession(sessionId: "ses_a"),
      ]);

      expect(repository.fetchCount, 1);
    });

    test("a failed fetch propagates and leaves the session unsynced", () async {
      final repository = _FakeSessionRepository(transcript: const [], error: StateError("backend down"));
      final history = createTestChatHistory(sessionRepository: repository);

      await expectLater(history.service.backfillSession(sessionId: "ses_a"), throwsStateError);
      expect(await history.repository.getSyncState(sessionId: "ses_a"), isNull);
    });

    test("an empty transcript is a valid synced state", () async {
      final repository = _FakeSessionRepository(transcript: const []);
      final history = createTestChatHistory(sessionRepository: repository);

      await history.service.backfillSession(sessionId: "ses_a");

      expect(await _storedMessages(history: history, sessionId: "ses_a"), isEmpty);
      expect((await history.repository.getSyncState(sessionId: "ses_a"))!.syncedAt, isNotNull);
    });
  });

  group("chat history reconcile", () {
    test("purges history whose session left the catalog and keeps the rest", () async {
      final repository = _FakeSessionRepository(transcript: const [], existingSessionIds: {"ses_known"});
      final history = createTestChatHistory(sessionRepository: repository);
      await history.service.captureMessage(
        sessionId: "ses_known",
        message: _message(id: "m1"),
      );
      await history.service.captureMessage(
        sessionId: "ses_orphan",
        message: _message(id: "m2"),
      );

      await ChatHistoryReconcileService(
        sessionRepository: repository,
        chatHistoryService: history.service,
      ).reconcile();

      expect(await _storedMessages(history: history, sessionId: "ses_known"), hasLength(1));
      expect(await _storedMessages(history: history, sessionId: "ses_orphan"), isEmpty);
      expect(await history.repository.getSyncState(sessionId: "ses_orphan"), isNull);
    });
  });
}

Future<List<MessageWithParts>> _storedMessages({
  required TestChatHistory history,
  required String sessionId,
}) async => (await history.repository.getSessionMessages(
  sessionId: sessionId,
  storageScope: testAttachmentStorageScope(sessionId: sessionId),
)).messages;

Message _message({required String id}) =>
    Message.user(id: id, sessionID: "ses_a", agent: null, time: const MessageTime(created: 1, completed: null));

MessagePart _part({
  required String id,
  required String messageId,
  required String text,
  MessageAttachment? attachment,
}) => MessagePart(
  id: id,
  sessionID: "ses_a",
  messageID: messageId,
  type: MessagePartType.text,
  text: text,
  tool: null,
  state: null,
  prompt: null,
  description: null,
  agent: null,
  agentName: null,
  attempt: null,
  retryError: null,
  attachment: attachment,
);

MessageWithParts _messageWithParts({required String id}) => MessageWithParts(
  info: _message(id: id),
  parts: [_part(id: "$id-p1", messageId: id, text: "text of $id")],
);

class _FakeSessionRepository({
  required final List<MessageWithParts> transcript,
  final Object? error,
  final Object? pluginSessionLookupError,
  final Set<String> existingSessionIds = const {},
  final Map<String, Set<String>> pluginSessionIds = const {},
}) implements SessionRepository {
  int fetchCount = 0;

  /// Runs while the fetch is in flight, so a test can interleave live events.
  Future<void> Function()? onFetch;

  @override
  Future<List<MessageWithParts>> getSessionMessages({required String sessionId}) async {
    fetchCount++;
    // Yield so a second caller can observe the in-flight fetch.
    await Future<void>.delayed(Duration.zero);
    // Deliberately not awaited: production dispatches captures without
    // awaiting them, and awaiting one here would wait on the very queue this
    // fetch is holding.
    unawaited(Future<void>.sync(() => onFetch?.call() ?? Future<void>.value()));
    await Future<void>.delayed(Duration.zero);
    final failure = error;
    if (failure != null) throw failure;
    return transcript;
  }

  @override
  Future<Set<String>> getExistingSessionIds({required Set<String> sessionIds}) async =>
      sessionIds.intersection(existingSessionIds);

  @override
  Future<Set<String>> getStoredSessionIdsForPlugin({required String pluginId}) async {
    final failure = pluginSessionLookupError;
    if (failure != null) throw failure;
    return pluginSessionIds[pluginId] ?? const {};
  }

  @override
  Future<Set<String>> getArchivedSessionIds({required Set<String> sessionIds}) async => const {};

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
    archivedAt: null,
    baseBranch: null,
    baseCommit: null,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
