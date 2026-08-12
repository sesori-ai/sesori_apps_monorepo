import "dart:async";
import "dart:convert";
import "dart:typed_data";

import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockSessionApi extends Mock implements SessionApi;

class _MockAuthSession extends Mock implements AuthSession;

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
  late MessageImageRepository repository;

  setUp(() {
    sessionApi = _MockSessionApi();
    authSession = _MockAuthSession();
    when(() => authSession.currentState).thenReturn(const AuthState.authenticated(user: _userA));
    repository = MessageImageRepository(
      api: MessageImageApi(client: MockClient((_) async => http.Response("unexpected", 500))),
      sessionApi: sessionApi,
      authSession: authSession,
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
    expect(requests, 1);

    when(() => authSession.currentState).thenReturn(const AuthState.authenticated(user: _userB));
    final otherAccount = repository.load(
      sessionId: "session-1",
      attachment: _stored,
      rendition: SessionAttachmentRendition.thumbnail,
    );
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
    expect(requests, 3, reason: "completed requests must leave active map");
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
}
