import "dart:async";
import "dart:convert";
import "dart:typed_data";

import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockSessionApi() extends Mock implements SessionApi;

class _MockAuthSession() extends Mock implements AuthSession;

class _FakeAuthSession(AuthState initial) extends Fake implements AuthSession {
  final BehaviorSubject<AuthState> states = BehaviorSubject.seeded(initial);

  @override
  ValueStream<AuthState> get authStateStream => states.stream;

  @override
  AuthState get currentState => states.value;

  void emit(AuthState state) => states.add(state);
}

class _FakeAttachmentThumbnailStorage() implements AttachmentThumbnailStorage {
  final Map<String, Map<String, Uint8List>> entries = {};
  final Map<String, Map<String, DateTime>> modifiedAt = {};
  final Map<String, int> sizeOverrides = {};
  final List<({String scope, String key})> reads = [];
  final List<({String scope, String key})> writes = [];
  final List<({String scope, String key})> deletes = [];
  final List<String> deletedScopes = [];
  Object? readFailure;
  Object? writeFailure;
  Object? listFailure;
  Object? deleteFailure;
  Object? deleteScopeFailure;
  Completer<void>? writeGate;
  Completer<void>? writeStarted;
  Completer<void>? deleteScopeGate;
  DateTime clock = DateTime.utc(2026);

  @override
  Future<Uint8List?> read({required String scope, required String key}) async {
    reads.add((scope: scope, key: key));
    if (readFailure case final failure?) throw failure;
    final bytes = entries[scope]?[key];
    return bytes == null ? null : Uint8List.fromList(bytes);
  }

  @override
  Future<void> write({required String scope, required String key, required Uint8List bytes}) async {
    writes.add((scope: scope, key: key));
    if (writeFailure case final failure?) throw failure;
    final started = writeStarted;
    if (started != null && !started.isCompleted) started.complete();
    if (writeGate case final gate?) await gate.future;
    entries.putIfAbsent(scope, () => {})[key] = Uint8List.fromList(bytes);
    modifiedAt.putIfAbsent(scope, () => {})[key] = clock;
    clock = clock.add(const Duration(seconds: 1));
  }

  @override
  Future<List<AttachmentThumbnailMetadata>> listMetadata({required String scope}) async {
    if (listFailure case final failure?) throw failure;
    return [
      for (final entry in entries[scope]?.entries ?? const <MapEntry<String, Uint8List>>[])
        AttachmentThumbnailMetadata(
          key: entry.key,
          sizeBytes: sizeOverrides[entry.key] ?? entry.value.length,
          modifiedAt: modifiedAt[scope]![entry.key]!,
        ),
    ];
  }

  @override
  Future<void> delete({required String scope, required String key}) async {
    deletes.add((scope: scope, key: key));
    if (deleteFailure case final failure?) throw failure;
    entries[scope]?.remove(key);
    modifiedAt[scope]?.remove(key);
  }

  @override
  Future<void> deleteScope({required String scope}) async {
    deletedScopes.add(scope);
    if (deleteScopeFailure case final failure?) throw failure;
    if (deleteScopeGate case final gate?) await gate.future;
    entries.remove(scope);
    modifiedAt.remove(scope);
  }
}

const _userA = AuthUser(
  id: "account-a",
  provider: AuthProvider.github,
  providerUserId: "provider-a",
  providerUsername: "alice",
);
const _userB = AuthUser(
  id: "account-b",
  provider: AuthProvider.github,
  providerUserId: "provider-b",
  providerUsername: "bob",
);
const _pngBytes = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
const MessageAttachmentStoredImage _stored = MessageAttachment.storedImage(
  attachmentId: "attachment-1",
  bridgeId: "bridge-1",
  mime: "image/png; charset=binary",
  filename: "preview.exe",
  byteLength: 8,
) as MessageAttachmentStoredImage;

void main() {
  setUpAll(() {
    registerFallbackValue(SessionAttachmentRendition.thumbnail);
  });

  late _MockSessionApi sessionApi;
  late _MockAuthSession authSession;
  late _FakeAttachmentThumbnailStorage thumbnailStorage;
  late MessageImageRepository repository;

  setUp(() {
    sessionApi = _MockSessionApi();
    authSession = _MockAuthSession();
    thumbnailStorage = _FakeAttachmentThumbnailStorage();
    when(() => authSession.currentState).thenReturn(const AuthState.authenticated(user: _userA));
    repository = MessageImageRepository(
      api: MessageImageApi(client: MockClient((_) async => http.Response("unexpected", 500))),
      sessionApi: sessionApi,
      authSession: authSession,
      attachmentThumbnailStorage: thumbnailStorage,
    );
  });

  test("rejects oversized or mismatched remote image responses", () async {
    final responses = [
      http.Response.bytes(Uint8List(maxInlineMessageAttachmentBytes + 1), 200),
      http.Response.bytes([0, 1, 2], 200),
    ];
    var index = 0;
    final remoteRepository = MessageImageRepository(
      api: MessageImageApi(client: MockClient((_) async => responses[index++])),
      sessionApi: sessionApi,
      authSession: authSession,
      attachmentThumbnailStorage: thumbnailStorage,
    );
    const attachment = MessageAttachment.remoteUrl(
      mime: "image/png",
      url: "https://files.example.com/image.png",
      filename: "image.png",
    );

    for (var request = 0; request < responses.length; request++) {
      expect(
        await remoteRepository.load(
          sessionId: "session-1",
          attachment: attachment,
          rendition: SessionAttachmentRendition.thumbnail,
        ),
        isA<MessageImageLoadRejected>(),
      );
    }
  });

  test("does not fetch insecure remote URL", () async {
    var requests = 0;
    final remoteRepository = MessageImageRepository(
      api: MessageImageApi(
        client: MockClient((_) async {
          requests++;
          return http.Response("unexpected", 500);
        }),
      ),
      sessionApi: sessionApi,
      authSession: authSession,
      attachmentThumbnailStorage: thumbnailStorage,
    );

    expect(
      await remoteRepository.load(
        sessionId: "session-1",
        attachment: const MessageAttachment.remoteUrl(
          mime: "image/png",
          url: "http://files.example.com/image.png",
          filename: "image.png",
        ),
        rendition: SessionAttachmentRendition.thumbnail,
      ),
      isA<MessageImageLoadUnsupported>(),
    );
    expect(requests, 0);
  });

  test("rejects HTTPS redirect that downgrades to HTTP", () async {
    final remoteRepository = MessageImageRepository(
      api: MessageImageApi(
        client: MockClient(
          (_) async => http.Response("", 302, headers: {"location": "http://files.example.com/image.png"}),
        ),
      ),
      sessionApi: sessionApi,
      authSession: authSession,
      attachmentThumbnailStorage: thumbnailStorage,
    );

    expect(
      await remoteRepository.load(
        sessionId: "session-1",
        attachment: const MessageAttachment.remoteUrl(
          mime: "image/png",
          url: "https://files.example.com/image.png",
          filename: "image.png",
        ),
        rendition: SessionAttachmentRendition.thumbnail,
      ),
      isA<MessageImageLoadRejected>(),
    );
  });

  test("rejects malformed inline image data", () async {
    expect(
      await repository.load(
        sessionId: "session-1",
        attachment: const MessageAttachment.inlineImage(mime: "image/png", base64: "%%%", filename: "broken.png"),
        rendition: SessionAttachmentRendition.thumbnail,
      ),
      isA<MessageImageLoadRejected>(),
    );
  });

  test("uses raster MIME extension for action filename", () async {
    const cases = <({String mime, List<int> bytes, String filename})>[
      (mime: "image/bmp", bytes: [0x42, 0x4D], filename: "image.bmp"),
      (mime: "image/gif", bytes: [0x47, 0x49, 0x46, 0x38, 0x39, 0x61], filename: "image.gif"),
      (mime: "image/jpeg", bytes: [0xFF, 0xD8, 0xFF], filename: "image.jpg"),
      (mime: "image/png", bytes: _pngBytes, filename: "image.png"),
      (mime: "image/webp", bytes: [0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50], filename: "image.webp"),
    ];

    for (final imageCase in cases) {
      final result = await repository.load(
        sessionId: "session-1",
        attachment: MessageAttachment.inlineImage(
          mime: imageCase.mime,
          base64: base64Encode(imageCase.bytes),
          filename: null,
        ),
        rendition: SessionAttachmentRendition.thumbnail,
      );
      expect((result as MessageImageLoadSuccess).actionFilename, imageCase.filename);
    }
  });

  test("bounds UTF-8 action filename and replaces Windows reserved name", () async {
    for (final filename in ["${List.filled(200, "😀").join()}.png", "CON.preview.png"]) {
      final result = await repository.load(
        sessionId: "session-1",
        attachment: MessageAttachment.inlineImage(
          mime: "image/png",
          base64: base64Encode(_pngBytes),
          filename: filename,
        ),
        rendition: SessionAttachmentRendition.thumbnail,
      );
      final actionFilename = (result as MessageImageLoadSuccess).actionFilename;
      expect(utf8.encode(actionFilename).length, lessThanOrEqualTo(255));
      expect(actionFilename, filename.startsWith("CON") ? "image.png" : endsWith(".png"));
    }
  });

  test("requires a message-owned session ID", () async {
    final result = await repository.load(
      sessionId: " ",
      attachment: _stored,
      rendition: SessionAttachmentRendition.thumbnail,
    );

    expect(result, isA<MessageImageLoadRejected>());
    verifyNever(
      () => sessionApi.getAttachment(
        sessionId: any(named: "sessionId"),
        attachmentId: any(named: "attachmentId"),
        rendition: any(named: "rendition"),
      ),
    );
  });

  test("captures authenticated account and coalesces only matching active stored scope", () async {
    final first = Completer<ApiResponse<SessionAttachmentResponse>>();
    var requests = 0;
    when(
      () => sessionApi.getAttachment(
        sessionId: any(named: "sessionId"),
        attachmentId: any(named: "attachmentId"),
        rendition: any(named: "rendition"),
      ),
    ).thenAnswer((_) {
      requests++;
      return first.future;
    });

    final loadA = repository.load(
      sessionId: "session-1",
      attachment: _stored,
      rendition: SessionAttachmentRendition.thumbnail,
    );
    final duplicate = repository.load(
      sessionId: "session-1",
      attachment: _stored,
      rendition: SessionAttachmentRendition.thumbnail,
    );
    await Future<void>.delayed(Duration.zero);
    expect(requests, 1);

    when(() => authSession.currentState).thenReturn(const AuthState.authenticated(user: _userB));
    final otherAccount = repository.load(
      sessionId: "session-1",
      attachment: _stored,
      rendition: SessionAttachmentRendition.thumbnail,
    );
    await Future<void>.delayed(Duration.zero);
    expect(requests, 2);

    first.complete(
      ApiResponse.success(
        SessionAttachmentResponse(mime: "image/png", base64: base64Encode(_pngBytes), byteLength: 8),
      ),
    );
    expect(await loadA, isA<MessageImageLoadSuccess>());
    expect(await duplicate, isA<MessageImageLoadSuccess>());
    expect(await otherAccount, isA<MessageImageLoadSuccess>());

    await repository.load(
      sessionId: "session-1",
      attachment: _stored,
      rendition: SessionAttachmentRendition.thumbnail,
    );
    expect(requests, 2, reason: "completed thumbnail requests must use persisted cache");
  });

  test("scope separates bridge, session, attachment, and rendition", () async {
    var requests = 0;
    when(
      () => sessionApi.getAttachment(
        sessionId: any(named: "sessionId"),
        attachmentId: any(named: "attachmentId"),
        rendition: any(named: "rendition"),
      ),
    ).thenAnswer((_) async {
      requests++;
      await Future<void>.delayed(Duration.zero);
      return ApiResponse.success(
        SessionAttachmentResponse(mime: "image/png", base64: base64Encode(_pngBytes), byteLength: 8),
      );
    });

    await Future.wait([
      repository.load(
        sessionId: "session-1",
        attachment: _stored,
        rendition: SessionAttachmentRendition.thumbnail,
      ),
      repository.load(
        sessionId: "session-2",
        attachment: _stored,
        rendition: SessionAttachmentRendition.thumbnail,
      ),
      repository.load(
        sessionId: "session-1",
        attachment: _stored.copyWith(bridgeId: "bridge-2"),
        rendition: SessionAttachmentRendition.thumbnail,
      ),
      repository.load(
        sessionId: "session-1",
        attachment: _stored.copyWith(attachmentId: "attachment-2"),
        rendition: SessionAttachmentRendition.thumbnail,
      ),
      repository.load(
        sessionId: "session-1",
        attachment: _stored,
        rendition: SessionAttachmentRendition.original,
      ),
    ]);

    expect(requests, 5);
  });

  test("coalesces transport while mapping each caller's metadata", () async {
    final response = Completer<ApiResponse<SessionAttachmentResponse>>();
    var requests = 0;
    when(
      () => sessionApi.getAttachment(
        sessionId: any(named: "sessionId"),
        attachmentId: any(named: "attachmentId"),
        rendition: any(named: "rendition"),
      ),
    ).thenAnswer((_) {
      requests++;
      return response.future;
    });

    final first = repository.load(
      sessionId: "session-1",
      attachment: _stored,
      rendition: SessionAttachmentRendition.thumbnail,
    );
    final differentFilename = repository.load(
      sessionId: "session-1",
      attachment: _stored.copyWith(filename: "other.png"),
      rendition: SessionAttachmentRendition.thumbnail,
    );
    final differentLength = repository.load(
      sessionId: "session-1",
      attachment: _stored.copyWith(byteLength: 9),
      rendition: SessionAttachmentRendition.thumbnail,
    );
    final differentMime = repository.load(
      sessionId: "session-1",
      attachment: _stored.copyWith(mime: "image/gif"),
      rendition: SessionAttachmentRendition.thumbnail,
    );

    await Future<void>.delayed(Duration.zero);
    expect(requests, 1);
    response.complete(
      ApiResponse.success(
        SessionAttachmentResponse(mime: "image/png", base64: base64Encode(_pngBytes), byteLength: 8),
      ),
    );
    final results = await Future.wait([first, differentFilename, differentLength, differentMime]);
    expect((results[0] as MessageImageLoadSuccess).actionFilename, "preview.png");
    expect((results[1] as MessageImageLoadSuccess).actionFilename, "other.png");
    expect(results[2], isA<MessageImageLoadSuccess>());
    expect((results[3] as MessageImageLoadSuccess).mime, "image/png");
  });

  test("validates stored MIME, base64, byte length, bounds, and raster signature", () async {
    final responses = <SessionAttachmentResponse>[
      SessionAttachmentResponse(mime: "image/jpeg", base64: base64Encode(_pngBytes), byteLength: 8),
      const SessionAttachmentResponse(mime: "image/png", base64: "%%%", byteLength: 2),
      SessionAttachmentResponse(mime: "image/png", base64: base64Encode(_pngBytes), byteLength: 7),
      SessionAttachmentResponse(
        mime: "image/png",
        base64: base64Encode(_pngBytes),
        byteLength: maxInlineMessageAttachmentBytes + 1,
      ),
      SessionAttachmentResponse(mime: "image/png", base64: base64Encode([0, 1, 2]), byteLength: 3),
    ];
    var index = 0;
    when(
      () => sessionApi.getAttachment(
        sessionId: any(named: "sessionId"),
        attachmentId: any(named: "attachmentId"),
        rendition: any(named: "rendition"),
      ),
    ).thenAnswer((_) async => ApiResponse.success(responses[index++]));

    for (var request = 0; request < responses.length; request++) {
      expect(
        await repository.load(
          sessionId: "session-1",
          attachment: _stored,
          rendition: SessionAttachmentRendition.thumbnail,
        ),
        isA<MessageImageLoadRejected>(),
      );
    }
  });

  test("accepts a transcoded stored thumbnail MIME", () async {
    when(
      () => sessionApi.getAttachment(
        sessionId: any(named: "sessionId"),
        attachmentId: any(named: "attachmentId"),
        rendition: SessionAttachmentRendition.thumbnail,
      ),
    ).thenAnswer(
      (_) async => ApiResponse.success(
        SessionAttachmentResponse(mime: "image/png", base64: base64Encode(_pngBytes), byteLength: 8),
      ),
    );

    final result = await repository.load(
      sessionId: "session-1",
      attachment: _stored.copyWith(mime: "image/gif"),
      rendition: SessionAttachmentRendition.thumbnail,
    );

    expect(result, isA<MessageImageLoadSuccess>());
    expect((result as MessageImageLoadSuccess).mime, "image/png");
  });

  test("validates original against transcript and declared original byte lengths", () async {
    when(
      () => sessionApi.getAttachment(
        sessionId: any(named: "sessionId"),
        attachmentId: any(named: "attachmentId"),
        rendition: SessionAttachmentRendition.original,
      ),
    ).thenAnswer(
      (_) async => ApiResponse.success(
        SessionAttachmentResponse(mime: "image/png", base64: base64Encode(_pngBytes), byteLength: 8),
      ),
    );

    final valid = await repository.load(
      sessionId: "session-1",
      attachment: _stored,
      rendition: SessionAttachmentRendition.original,
    );
    final mismatchedClaim = await repository.load(
      sessionId: "session-1",
      attachment: _stored.copyWith(byteLength: 9),
      rendition: SessionAttachmentRendition.original,
    );
    final oversizedClaim = await repository.load(
      sessionId: "session-1",
      attachment: _stored.copyWith(byteLength: maxTranscriptImageBytes + 1),
      rendition: SessionAttachmentRendition.original,
    );

    expect(valid, isA<MessageImageLoadSuccess>());
    expect(mismatchedClaim, isA<MessageImageLoadRejected>());
    expect(oversizedClaim, isA<MessageImageLoadRejected>());
    expect(repository.canLoadOriginal(attachment: _stored), isTrue);
    expect(repository.canLoadOriginal(attachment: _stored.copyWith(byteLength: maxTranscriptImageBytes + 1)), isFalse);
    verify(
      () => sessionApi.getAttachment(
        sessionId: "session-1",
        attachmentId: "attachment-1",
        rendition: SessionAttachmentRendition.original,
      ),
    ).called(2);
  });

  test("returns privacy-safe typed transport failure with inner cause", () async {
    final inner = StateError("socket failed");
    when(
      () => sessionApi.getAttachment(
        sessionId: any(named: "sessionId"),
        attachmentId: any(named: "attachmentId"),
        rendition: any(named: "rendition"),
      ),
    ).thenAnswer((_) async => ApiResponse.error(ApiError.dartHttpClient(inner)));

    final result = await repository.load(
      sessionId: "session-1",
      attachment: _stored,
      rendition: SessionAttachmentRendition.thumbnail,
    );

    final failure = result as MessageImageLoadFailure;
    final cause = failure.cause as MessageImageRequestException;
    expect(cause.kind, MessageImageRequestFailureKind.network);
    expect(cause.innerError, same(inner));
    expect(failure.stackTrace, isNotNull);
    expect(cause.toString(), isNot(contains("socket failed")));
  });

  test("preserves typed non-network failure as the inner cause", () async {
    final apiError = ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null);
    when(
      () => sessionApi.getAttachment(
        sessionId: any(named: "sessionId"),
        attachmentId: any(named: "attachmentId"),
        rendition: any(named: "rendition"),
      ),
    ).thenAnswer((_) async => ApiResponse.error(apiError));

    final result = await repository.load(
      sessionId: "session-1",
      attachment: _stored,
      rendition: SessionAttachmentRendition.thumbnail,
    );

    final failure = result as MessageImageLoadFailure;
    final cause = failure.cause as MessageImageRequestException;
    expect(cause.kind, MessageImageRequestFailureKind.rejected);
    expect(cause.innerError, same(apiError));
    expect(failure.stackTrace, isNotNull);
  });

  test("does not request stored data without authenticated account", () async {
    when(() => authSession.currentState).thenReturn(const AuthState.unauthenticated());

    final result = await repository.load(
      sessionId: "session-1",
      attachment: _stored,
      rendition: SessionAttachmentRendition.thumbnail,
    );

    expect((result as MessageImageLoadFailure).cause, isA<MessageImageAuthenticationRequiredException>());
    verifyNever(
      () => sessionApi.getAttachment(
        sessionId: any(named: "sessionId"),
        attachmentId: any(named: "attachmentId"),
        rendition: any(named: "rendition"),
      ),
    );
  });

  test("reuses validated thumbnail across repository instances without exposing raw IDs", () async {
    var requests = 0;
    when(
      () => sessionApi.getAttachment(
        sessionId: any(named: "sessionId"),
        attachmentId: any(named: "attachmentId"),
        rendition: SessionAttachmentRendition.thumbnail,
      ),
    ).thenAnswer((_) async {
      requests++;
      return ApiResponse.success(
        SessionAttachmentResponse(mime: "image/png", base64: base64Encode(_pngBytes), byteLength: 8),
      );
    });

    expect(
      await repository.load(
        sessionId: "private-session",
        attachment: _stored.copyWith(attachmentId: "private-attachment", bridgeId: "private-bridge"),
        rendition: SessionAttachmentRendition.thumbnail,
      ),
      isA<MessageImageLoadSuccess>(),
    );
    final restartedRepository = MessageImageRepository(
      api: MessageImageApi(client: MockClient((_) async => http.Response("unexpected", 500))),
      sessionApi: sessionApi,
      authSession: authSession,
      attachmentThumbnailStorage: thumbnailStorage,
    );
    final warm = await restartedRepository.load(
      sessionId: "private-session",
      attachment: _stored.copyWith(
        attachmentId: "private-attachment",
        bridgeId: "private-bridge",
        filename: "warm.gif",
      ),
      rendition: SessionAttachmentRendition.thumbnail,
    );

    expect(requests, 1);
    expect((warm as MessageImageLoadSuccess).actionFilename, "warm.png");
    final storedIdentity = "${thumbnailStorage.writes.single.scope}/${thumbnailStorage.writes.single.key}";
    expect(storedIdentity, matches(RegExp(r"^[a-f0-9]{64}/[a-f0-9]{64}$")));
    for (final rawId in ["account-a", "private-bridge", "private-session", "private-attachment"]) {
      expect(storedIdentity, isNot(contains(rawId)));
    }
  });

  test("deletes corrupt warm entry and refetches it", () async {
    var requests = 0;
    when(
      () => sessionApi.getAttachment(
        sessionId: any(named: "sessionId"),
        attachmentId: any(named: "attachmentId"),
        rendition: SessionAttachmentRendition.thumbnail,
      ),
    ).thenAnswer((_) async {
      requests++;
      return ApiResponse.success(
        SessionAttachmentResponse(mime: "image/png", base64: base64Encode(_pngBytes), byteLength: 8),
      );
    });
    await repository.load(
      sessionId: "session-1",
      attachment: _stored,
      rendition: SessionAttachmentRendition.thumbnail,
    );
    final stored = thumbnailStorage.writes.single;
    thumbnailStorage.entries[stored.scope]![stored.key] = Uint8List.fromList([1, 2, 3]);

    final restartedRepository = MessageImageRepository(
      api: MessageImageApi(client: MockClient((_) async => http.Response("unexpected", 500))),
      sessionApi: sessionApi,
      authSession: authSession,
      attachmentThumbnailStorage: thumbnailStorage,
    );
    expect(
      await restartedRepository.load(
        sessionId: "session-1",
        attachment: _stored,
        rendition: SessionAttachmentRendition.thumbnail,
      ),
      isA<MessageImageLoadSuccess>(),
    );

    expect(requests, 2);
    expect(thumbnailStorage.deletes, contains(stored));
  });

  test("original requests bypass thumbnail storage", () async {
    when(
      () => sessionApi.getAttachment(
        sessionId: "session-1",
        attachmentId: "attachment-1",
        rendition: SessionAttachmentRendition.original,
      ),
    ).thenAnswer(
      (_) async => ApiResponse.success(
        SessionAttachmentResponse(mime: "image/png", base64: base64Encode(_pngBytes), byteLength: 8),
      ),
    );

    expect(
      await repository.load(
        sessionId: "session-1",
        attachment: _stored,
        rendition: SessionAttachmentRendition.original,
      ),
      isA<MessageImageLoadSuccess>(),
    );
    expect(thumbnailStorage.reads, isEmpty);
    expect(thumbnailStorage.writes, isEmpty);
    expect(thumbnailStorage.deletedScopes, isEmpty);
  });

  test("late thumbnail fetch during logout never writes", () async {
    final session = _FakeAuthSession(const AuthState.authenticated(user: _userA));
    final serviceRepository = MessageImageRepository(
      api: MessageImageApi(client: MockClient((_) async => http.Response("unexpected", 500))),
      sessionApi: sessionApi,
      authSession: session,
      attachmentThumbnailStorage: thumbnailStorage,
    );
    final service = MessageThumbnailCacheService(repository: serviceRepository, authSession: session);
    final response = Completer<ApiResponse<SessionAttachmentResponse>>();
    when(
      () => sessionApi.getAttachment(
        sessionId: any(named: "sessionId"),
        attachmentId: any(named: "attachmentId"),
        rendition: SessionAttachmentRendition.thumbnail,
      ),
    ).thenAnswer((_) => response.future);

    final load = serviceRepository.load(
      sessionId: "session-1",
      attachment: _stored,
      rendition: SessionAttachmentRendition.thumbnail,
    );
    await Future<void>.delayed(Duration.zero);
    session.emit(const AuthState.unauthenticated());
    await Future<void>.delayed(Duration.zero);
    response.complete(
      ApiResponse.success(
        SessionAttachmentResponse(mime: "image/png", base64: base64Encode(_pngBytes), byteLength: 8),
      ),
    );

    expect(await load, isA<MessageImageLoadSuccess>());
    await serviceRepository.waitForThumbnailCacheCleanup();
    expect(thumbnailStorage.writes, isEmpty);
    expect(thumbnailStorage.deletedScopes, hasLength(1));
    await service.dispose();
    await session.states.close();
  });

  test("same-account logout and relogin waits for cleanup then writes", () async {
    final session = _FakeAuthSession(const AuthState.authenticated(user: _userA));
    final serviceRepository = MessageImageRepository(
      api: MessageImageApi(client: MockClient((_) async => http.Response("unexpected", 500))),
      sessionApi: sessionApi,
      authSession: session,
      attachmentThumbnailStorage: thumbnailStorage,
    );
    final service = MessageThumbnailCacheService(repository: serviceRepository, authSession: session);
    final cleanupGate = Completer<void>();
    thumbnailStorage.deleteScopeGate = cleanupGate;
    session.emit(const AuthState.unauthenticated());
    session.emit(const AuthState.authenticated(user: _userA));
    await Future<void>.delayed(Duration.zero);
    var requests = 0;
    when(
      () => sessionApi.getAttachment(
        sessionId: any(named: "sessionId"),
        attachmentId: any(named: "attachmentId"),
        rendition: SessionAttachmentRendition.thumbnail,
      ),
    ).thenAnswer((_) async {
      requests++;
      return ApiResponse.success(
        SessionAttachmentResponse(mime: "image/png", base64: base64Encode(_pngBytes), byteLength: 8),
      );
    });

    final reloginLoad = serviceRepository.load(
      sessionId: "session-1",
      attachment: _stored,
      rendition: SessionAttachmentRendition.thumbnail,
    );
    await Future<void>.delayed(Duration.zero);
    expect(requests, 0);
    expect(thumbnailStorage.writes, isEmpty);

    cleanupGate.complete();
    expect(await reloginLoad, isA<MessageImageLoadSuccess>());
    expect(requests, 1);
    expect(thumbnailStorage.writes, hasLength(1));
    await service.dispose();
    await session.states.close();
  });

  test("load waiting for cleanup rejects after the account logs out again", () async {
    final session = _FakeAuthSession(const AuthState.authenticated(user: _userA));
    final serviceRepository = MessageImageRepository(
      api: MessageImageApi(client: MockClient((_) async => http.Response("unexpected", 500))),
      sessionApi: sessionApi,
      authSession: session,
      attachmentThumbnailStorage: thumbnailStorage,
    );
    final service = MessageThumbnailCacheService(repository: serviceRepository, authSession: session);
    final cleanupGate = Completer<void>();
    thumbnailStorage.deleteScopeGate = cleanupGate;
    session.emit(const AuthState.unauthenticated());
    session.emit(const AuthState.authenticated(user: _userA));
    await Future<void>.delayed(Duration.zero);
    var requests = 0;
    when(
      () => sessionApi.getAttachment(
        sessionId: any(named: "sessionId"),
        attachmentId: any(named: "attachmentId"),
        rendition: SessionAttachmentRendition.thumbnail,
      ),
    ).thenAnswer((_) async {
      requests++;
      return ApiResponse.success(
        SessionAttachmentResponse(mime: "image/png", base64: base64Encode(_pngBytes), byteLength: 8),
      );
    });

    final load = serviceRepository.load(
      sessionId: "session-1",
      attachment: _stored,
      rendition: SessionAttachmentRendition.thumbnail,
    );
    await Future<void>.delayed(Duration.zero);
    session.emit(const AuthState.unauthenticated());
    cleanupGate.complete();

    expect(
      await load,
      isA<MessageImageLoadFailure>().having(
        (result) => result.cause,
        "cause",
        isA<MessageImageAuthenticationRequiredException>(),
      ),
    );
    expect(requests, 0);
    expect(thumbnailStorage.writes, isEmpty);
    await service.dispose();
    await session.states.close();
  });

  test("logout waits for a started thumbnail write before deleting its scope", () async {
    final session = _FakeAuthSession(const AuthState.authenticated(user: _userA));
    final serviceRepository = MessageImageRepository(
      api: MessageImageApi(client: MockClient((_) async => http.Response("unexpected", 500))),
      sessionApi: sessionApi,
      authSession: session,
      attachmentThumbnailStorage: thumbnailStorage,
    );
    final service = MessageThumbnailCacheService(repository: serviceRepository, authSession: session);
    when(
      () => sessionApi.getAttachment(
        sessionId: any(named: "sessionId"),
        attachmentId: any(named: "attachmentId"),
        rendition: SessionAttachmentRendition.thumbnail,
      ),
    ).thenAnswer(
      (_) async => ApiResponse.success(
        SessionAttachmentResponse(mime: "image/png", base64: base64Encode(_pngBytes), byteLength: 8),
      ),
    );
    final writeStarted = Completer<void>();
    final writeGate = Completer<void>();
    thumbnailStorage
      ..writeStarted = writeStarted
      ..writeGate = writeGate;

    final load = serviceRepository.load(
      sessionId: "session-1",
      attachment: _stored,
      rendition: SessionAttachmentRendition.thumbnail,
    );
    await writeStarted.future;
    final scope = thumbnailStorage.writes.single.scope;
    session.emit(const AuthState.unauthenticated());
    await Future<void>.delayed(Duration.zero);
    expect(thumbnailStorage.deletedScopes, isEmpty);

    writeGate.complete();
    expect(await load, isA<MessageImageLoadSuccess>());
    await serviceRepository.waitForThumbnailCacheCleanup();
    expect(thumbnailStorage.deletedScopes, [scope]);
    expect(thumbnailStorage.entries, isNot(contains(scope)));
    await service.dispose();
    await session.states.close();
  });

  test("prunes oldest entries and breaks modified-time ties by key", () async {
    when(
      () => sessionApi.getAttachment(
        sessionId: any(named: "sessionId"),
        attachmentId: any(named: "attachmentId"),
        rendition: SessionAttachmentRendition.thumbnail,
      ),
    ).thenAnswer(
      (_) async => ApiResponse.success(
        SessionAttachmentResponse(mime: "image/png", base64: base64Encode(_pngBytes), byteLength: 8),
      ),
    );
    await repository.load(
      sessionId: "session-1",
      attachment: _stored,
      rendition: SessionAttachmentRendition.thumbnail,
    );
    final stored = thumbnailStorage.writes.single;
    final scopeEntries = thumbnailStorage.entries[stored.scope]!;
    final scopeTimes = thumbnailStorage.modifiedAt[stored.scope]!;
    final oldTime = DateTime.utc(2025);
    final tiedTime = DateTime.utc(2025, 1, 2);
    scopeEntries
      ..["old"] = Uint8List(1)
      ..["z"] = Uint8List(1)
      ..["a"] = Uint8List(1);
    scopeTimes
      ..["old"] = oldTime
      ..["z"] = tiedTime
      ..["a"] = tiedTime;
    thumbnailStorage.sizeOverrides
      ..["old"] = 10 * 1024 * 1024
      ..["z"] = 30 * 1024 * 1024
      ..["a"] = 30 * 1024 * 1024
      ..[stored.key] = 8 * 1024 * 1024;

    await repository.load(
      sessionId: "session-1",
      attachment: _stored.copyWith(attachmentId: "attachment-2"),
      rendition: SessionAttachmentRendition.thumbnail,
    );

    expect(thumbnailStorage.deletes.map((entry) => entry.key), ["old", "a"]);
  });

  test("recovers from storage read, write, list, corrupt-delete, and prune-delete failures", () async {
    var requests = 0;
    when(
      () => sessionApi.getAttachment(
        sessionId: any(named: "sessionId"),
        attachmentId: any(named: "attachmentId"),
        rendition: SessionAttachmentRendition.thumbnail,
      ),
    ).thenAnswer((_) async {
      requests++;
      return ApiResponse.success(
        SessionAttachmentResponse(mime: "image/png", base64: base64Encode(_pngBytes), byteLength: 8),
      );
    });

    thumbnailStorage.readFailure = StateError("read");
    expect(
      await repository.load(
        sessionId: "session-1",
        attachment: _stored,
        rendition: SessionAttachmentRendition.thumbnail,
      ),
      isA<MessageImageLoadSuccess>(),
    );
    thumbnailStorage.readFailure = null;
    thumbnailStorage.writeFailure = StateError("write");
    expect(
      await repository.load(
        sessionId: "session-1",
        attachment: _stored.copyWith(attachmentId: "write-failure"),
        rendition: SessionAttachmentRendition.thumbnail,
      ),
      isA<MessageImageLoadSuccess>(),
    );
    thumbnailStorage.writeFailure = null;
    thumbnailStorage.listFailure = StateError("list");
    expect(
      await repository.load(
        sessionId: "session-1",
        attachment: _stored.copyWith(attachmentId: "list-failure"),
        rendition: SessionAttachmentRendition.thumbnail,
      ),
      isA<MessageImageLoadSuccess>(),
    );
    thumbnailStorage.listFailure = null;

    final stored = thumbnailStorage.writes.last;
    thumbnailStorage.entries[stored.scope]![stored.key] = Uint8List.fromList([1]);
    thumbnailStorage.deleteFailure = StateError("delete");
    expect(
      await repository.load(
        sessionId: "session-1",
        attachment: _stored.copyWith(attachmentId: "list-failure"),
        rendition: SessionAttachmentRendition.thumbnail,
      ),
      isA<MessageImageLoadSuccess>(),
    );
    final oversizedKey = thumbnailStorage.writes.last.key;
    thumbnailStorage.sizeOverrides[oversizedKey] = 65 * 1024 * 1024;
    expect(
      await repository.load(
        sessionId: "session-1",
        attachment: _stored.copyWith(attachmentId: "prune-failure"),
        rendition: SessionAttachmentRendition.thumbnail,
      ),
      isA<MessageImageLoadSuccess>(),
    );
    thumbnailStorage.deleteFailure = null;
    expect(requests, 5);
  });

  test("cache service deletes switched account scope and permits next account writes", () async {
    final session = _FakeAuthSession(const AuthState.authenticated(user: _userA));
    final serviceRepository = MessageImageRepository(
      api: MessageImageApi(client: MockClient((_) async => http.Response("unexpected", 500))),
      sessionApi: sessionApi,
      authSession: session,
      attachmentThumbnailStorage: thumbnailStorage,
    );
    when(
      () => sessionApi.getAttachment(
        sessionId: any(named: "sessionId"),
        attachmentId: any(named: "attachmentId"),
        rendition: SessionAttachmentRendition.thumbnail,
      ),
    ).thenAnswer(
      (_) async => ApiResponse.success(
        SessionAttachmentResponse(mime: "image/png", base64: base64Encode(_pngBytes), byteLength: 8),
      ),
    );
    final service = MessageThumbnailCacheService(repository: serviceRepository, authSession: session);

    await serviceRepository.load(
      sessionId: "session-1",
      attachment: _stored,
      rendition: SessionAttachmentRendition.thumbnail,
    );
    final accountAScope = thumbnailStorage.writes.single.scope;
    session.emit(const AuthState.authenticated(user: _userB));
    await Future<void>.delayed(Duration.zero);
    await serviceRepository.waitForThumbnailCacheCleanup();
    expect(thumbnailStorage.deletedScopes, [accountAScope]);

    await serviceRepository.load(
      sessionId: "session-1",
      attachment: _stored,
      rendition: SessionAttachmentRendition.thumbnail,
    );
    expect(thumbnailStorage.writes, hasLength(2));
    expect(thumbnailStorage.writes.last.scope, isNot(accountAScope));
    await service.dispose();
    await session.states.close();
  });

  test("cache service continues after cleanup storage failure", () async {
    final session = _FakeAuthSession(const AuthState.authenticated(user: _userA));
    final serviceRepository = MessageImageRepository(
      api: MessageImageApi(client: MockClient((_) async => http.Response("unexpected", 500))),
      sessionApi: sessionApi,
      authSession: session,
      attachmentThumbnailStorage: thumbnailStorage,
    );
    when(
      () => sessionApi.getAttachment(
        sessionId: any(named: "sessionId"),
        attachmentId: any(named: "attachmentId"),
        rendition: SessionAttachmentRendition.thumbnail,
      ),
    ).thenAnswer(
      (_) async => ApiResponse.success(
        SessionAttachmentResponse(mime: "image/png", base64: base64Encode(_pngBytes), byteLength: 8),
      ),
    );
    final service = MessageThumbnailCacheService(repository: serviceRepository, authSession: session);
    thumbnailStorage.deleteScopeFailure = StateError("cleanup");

    session.emit(const AuthState.unauthenticated());
    await serviceRepository.waitForThumbnailCacheCleanup();
    thumbnailStorage.deleteScopeFailure = null;
    session.emit(const AuthState.authenticated(user: _userA));
    expect(
      await serviceRepository.load(
        sessionId: "session-1",
        attachment: _stored,
        rendition: SessionAttachmentRendition.thumbnail,
      ),
      isA<MessageImageLoadSuccess>(),
    );
    expect(thumbnailStorage.writes, hasLength(1));
    await service.dispose();
    await session.states.close();
  });

  test("cache service disposal waits for active cleanup and cancels auth listener", () async {
    final session = _FakeAuthSession(const AuthState.authenticated(user: _userA));
    final serviceRepository = MessageImageRepository(
      api: MessageImageApi(client: MockClient((_) async => http.Response("unexpected", 500))),
      sessionApi: sessionApi,
      authSession: session,
      attachmentThumbnailStorage: thumbnailStorage,
    );
    final service = MessageThumbnailCacheService(repository: serviceRepository, authSession: session);
    final cleanupGate = Completer<void>();
    thumbnailStorage.deleteScopeGate = cleanupGate;

    session.emit(const AuthState.unauthenticated());
    await Future<void>.delayed(Duration.zero);
    var disposed = false;
    final disposal = service.dispose().then((_) => disposed = true);
    await Future<void>.delayed(Duration.zero);
    expect(disposed, isFalse);

    cleanupGate.complete();
    await disposal;
    session.emit(const AuthState.authenticated(user: _userA));
    await Future<void>.delayed(Duration.zero);
    expect(thumbnailStorage.deletedScopes, hasLength(1));
    await session.states.close();
  });
}
