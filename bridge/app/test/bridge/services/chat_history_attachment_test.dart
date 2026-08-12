import "dart:async";
import "dart:io";
import "dart:typed_data";

import "package:image/image.dart" as image;
import "package:sesori_bridge/src/api/attachment_spill_storage.dart";
import "package:sesori_bridge/src/auth/bridge_id_provider.dart";
import "package:sesori_bridge/src/bridge/repositories/attachment_thumbnail_builder.dart";
import "package:sesori_bridge/src/bridge/repositories/chat_history_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/services/chat_history_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_chat_history.dart";

void main() {
  test("serves stored originals with detected MIME", () async {
    final history = createTestChatHistory();
    final bytes = _pngBytes();
    final digest = await history.spillStorage.write(
      scope: testAttachmentStorageScope(sessionId: "session-1"),
      bytes: bytes,
    );

    final result = await history.service.getSessionAttachment(
      sessionId: "session-1",
      attachmentId: digest,
      rendition: SessionAttachmentRendition.original,
    );

    expect(result, isA<SessionAttachmentFound>());
    final found = result as SessionAttachmentFound;
    expect(found.bytes, bytes);
    expect(found.mime, "image/png");
  });

  test("generates one thumbnail and reuses its stored rendition", () async {
    final builder = _CountingThumbnailBuilder();
    final history = createTestChatHistory(attachmentThumbnailBuilder: builder);
    final scope = testAttachmentStorageScope(sessionId: "session-1");
    final digest = await history.spillStorage.write(scope: scope, bytes: _pngBytes());

    final first = await history.service.getSessionAttachment(
      sessionId: "session-1",
      attachmentId: digest,
      rendition: SessionAttachmentRendition.thumbnail,
    );
    final second = await history.service.getSessionAttachment(
      sessionId: "session-1",
      attachmentId: digest,
      rendition: SessionAttachmentRendition.thumbnail,
    );

    expect(first, isA<SessionAttachmentFound>());
    expect(second, isA<SessionAttachmentFound>());
    expect(builder.calls, 1);
    expect(await history.spillStorage.readThumbnail(scope: scope, digest: digest), isNotNull);
  });

  test("an archived session uses the shared attachment scope", () async {
    final history = createTestChatHistory(storedSessionArchivedAt: 1);
    const sessionId = "session-1";
    final scope = testAttachmentStorageScope(sessionId: sessionId);
    final digest = await history.spillStorage.write(scope: scope, bytes: _pngBytes());
    final result = await history.service.getSessionAttachment(
      sessionId: sessionId,
      attachmentId: digest,
      rendition: SessionAttachmentRendition.thumbnail,
    );

    expect(result, isA<SessionAttachmentFound>());
    expect(await history.spillStorage.readThumbnail(scope: scope, digest: digest), isNotNull);
  });

  test("rejects an orphan spill after its session row is deleted", () async {
    final history = createTestChatHistory(sessionRepository: _MissingSessionRepository());
    final digest = await history.spillStorage.write(
      scope: testAttachmentStorageScope(sessionId: "session-1"),
      bytes: _pngBytes(),
    );

    final result = await history.service.getSessionAttachment(
      sessionId: "session-1",
      attachmentId: digest,
      rendition: SessionAttachmentRendition.original,
    );

    expect(result, isA<SessionAttachmentMissing>());
  });

  test("a purge queued behind generation retains the shared attachment scope", () async {
    final history = createTestChatHistory();
    const sessionId = "session-1";
    final scope = testAttachmentStorageScope(sessionId: sessionId);
    final digest = await history.spillStorage.write(scope: scope, bytes: _pngBytes());

    final rendition = history.service.getSessionAttachment(
      sessionId: sessionId,
      attachmentId: digest,
      rendition: SessionAttachmentRendition.thumbnail,
    );
    final purge = history.service.purgeSessionHistory(sessionId: sessionId);
    expect(await rendition, isA<SessionAttachmentFound>());
    await purge;

    expect(Directory(history.spillStorage.scopeDirectoryPath(scope: scope)).existsSync(), isTrue);
    expect(await history.spillStorage.readThumbnail(scope: scope, digest: digest), isNotNull);
  });

  test("rejects missing, malformed, unsupported, and oversized originals", () async {
    final history = createTestChatHistory();
    expect(
      await history.service.getSessionAttachment(
        sessionId: "session-1",
        attachmentId: "../../etc/passwd",
        rendition: SessionAttachmentRendition.original,
      ),
      isA<SessionAttachmentMissing>(),
    );

    final corrupt = await history.spillStorage.write(
      scope: testAttachmentStorageScope(sessionId: "session-1"),
      bytes: Uint8List.fromList([1, 2, 3]),
    );
    expect(
      await history.service.getSessionAttachment(
        sessionId: "session-1",
        attachmentId: corrupt,
        rendition: SessionAttachmentRendition.original,
      ),
      isA<SessionAttachmentUnsupported>(),
    );

    final oversized = await history.spillStorage.write(
      scope: testAttachmentStorageScope(sessionId: "session-1"),
      bytes: Uint8List(20 * 1024 * 1024 + 1),
    );
    expect(
      await history.service.getSessionAttachment(
        sessionId: "session-1",
        attachmentId: oversized,
        rendition: SessionAttachmentRendition.original,
      ),
      isA<SessionAttachmentTooLarge>(),
    );
  });

  test("serializes thumbnail decodes across sessions", () async {
    final builder = _TrackingThumbnailBuilder();
    final history = createTestChatHistory(attachmentThumbnailBuilder: builder);
    final first = await history.spillStorage.write(
      scope: testAttachmentStorageScope(sessionId: "session-1"),
      bytes: _pngBytes(),
    );
    final second = await history.spillStorage.write(
      scope: testAttachmentStorageScope(sessionId: "session-2"),
      bytes: _pngBytes(),
    );

    await Future.wait([
      history.service.getSessionAttachment(
        sessionId: "session-1",
        attachmentId: first,
        rendition: SessionAttachmentRendition.thumbnail,
      ),
      history.service.getSessionAttachment(
        sessionId: "session-2",
        attachmentId: second,
        rendition: SessionAttachmentRendition.thumbnail,
      ),
    ]);

    expect(builder.maxActive, 1);
  });

  test("serializes original reads for thumbnail generation across sessions", () async {
    final repository = _TrackingChatHistoryRepository();
    final service = ChatHistoryService(
      chatHistoryRepository: repository,
      sessionRepository: _PresentSessionRepository(),
      attachmentThumbnailBuilder: const AttachmentThumbnailBuilder(),
      bridgeIdProvider: const _BridgeIdProvider(),
    );

    await Future.wait([
      service.getSessionAttachment(
        sessionId: "session-1",
        attachmentId: "1" * 64,
        rendition: SessionAttachmentRendition.thumbnail,
      ),
      service.getSessionAttachment(
        sessionId: "session-2",
        attachmentId: "2" * 64,
        rendition: SessionAttachmentRendition.thumbnail,
      ),
    ]);

    expect(repository.maxActiveReads, 1);
  });
}

Uint8List _pngBytes() {
  final source = image.Image(width: 16, height: 8, numChannels: 3);
  image.fill(source, color: image.ColorRgb8(30, 80, 140));
  return image.encodePng(source);
}

class _CountingThumbnailBuilder extends AttachmentThumbnailBuilder {
  int calls = 0;

  @override
  Future<AttachmentThumbnailBuildResult> build({required Uint8List bytes}) {
    calls++;
    return super.build(bytes: bytes);
  }
}

class _TrackingThumbnailBuilder extends AttachmentThumbnailBuilder {
  int _active = 0;
  int maxActive = 0;

  @override
  Future<AttachmentThumbnailBuildResult> build({required Uint8List bytes}) async {
    _active++;
    if (_active > maxActive) maxActive = _active;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    try {
      return await super.build(bytes: bytes);
    } finally {
      _active--;
    }
  }
}

class _MissingSessionRepository implements SessionRepository {
  @override
  Future<StoredSession?> getStoredSession({required String sessionId}) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _PresentSessionRepository implements SessionRepository {
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
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _TrackingChatHistoryRepository implements ChatHistoryRepository {
  int _activeReads = 0;
  int maxActiveReads = 0;

  @override
  Future<StoredAttachmentThumbnail?> readStoredAttachmentThumbnail({
    required AttachmentStorageScope storageScope,
    required String attachmentId,
  }) async => null;

  @override
  Future<Uint8List?> readStoredAttachment({
    required AttachmentStorageScope storageScope,
    required String attachmentId,
  }) async {
    _activeReads++;
    if (_activeReads > maxActiveReads) maxActiveReads = _activeReads;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    _activeReads--;
    return _pngBytes();
  }

  @override
  Future<bool> writeStoredAttachmentThumbnail({
    required AttachmentStorageScope storageScope,
    required String attachmentId,
    required AttachmentThumbnailFormat format,
    required Uint8List bytes,
  }) async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _BridgeIdProvider implements BridgeIdProvider {
  const _BridgeIdProvider();

  @override
  String get bridgeId => "br_test1234";
}
