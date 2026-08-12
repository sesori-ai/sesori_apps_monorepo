import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:image/image.dart" as image;
import "package:sesori_bridge/src/bridge/routing/get_session_attachment_handler.dart";
import "package:sesori_bridge/src/bridge/services/chat_history_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_chat_history.dart";
import "routing_test_helpers.dart";

void main() {
  group("GetSessionAttachmentHandler", () {
    test("handles only POST /session/attachment", () {
      final handler = GetSessionAttachmentHandler(chatHistoryService: createTestChatHistory().service);

      expect(handler.canHandle(makeRequest("POST", "/session/attachment")), isTrue);
      expect(handler.canHandle(makeRequest("GET", "/session/attachment")), isFalse);
      expect(handler.canHandle(makeRequest("POST", "/session/messages")), isFalse);
    });

    test("returns an encoded original with its decoded byte length", () async {
      final history = createTestChatHistory();
      final bytes = _pngBytes();
      final digest = await history.spillStorage.write(
        scope: testAttachmentStorageScope(sessionId: "session-1"),
        bytes: bytes,
      );
      final handler = GetSessionAttachmentHandler(chatHistoryService: history.service);

      final response = await handler.handle(
        makeRequest("POST", "/session/attachment"),
        body: SessionAttachmentRequest(
          sessionId: "session-1",
          attachmentId: digest,
          rendition: SessionAttachmentRendition.original,
        ),
        pathParams: const {},
        queryParams: const {},
        fragment: null,
      );

      expect(response.mime, "image/png");
      expect(response.byteLength, bytes.length);
      expect(base64Decode(response.base64), bytes);
    });

    test("maps invalid and unavailable requests to bounded status codes", () async {
      final history = createTestChatHistory();
      final corrupt = await history.spillStorage.write(
        scope: testAttachmentStorageScope(sessionId: "session-1"),
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      final handler = GetSessionAttachmentHandler(chatHistoryService: history.service);

      await _expectStatus(
        handler: handler,
        request: const SessionAttachmentRequest(
          sessionId: "",
          attachmentId: "missing",
          rendition: SessionAttachmentRendition.original,
        ),
        status: 400,
      );
      await _expectStatus(
        handler: handler,
        request: const SessionAttachmentRequest(
          sessionId: "session-1",
          attachmentId: "missing",
          rendition: SessionAttachmentRendition.original,
        ),
        status: 404,
      );
      await _expectStatus(
        handler: handler,
        request: SessionAttachmentRequest(
          sessionId: "session-1",
          attachmentId: corrupt,
          rendition: SessionAttachmentRendition.thumbnail,
        ),
        status: 422,
      );
    });

    test("handleInternal parses the typed request body", () async {
      final history = createTestChatHistory();
      final bytes = _pngBytes();
      final digest = await history.spillStorage.write(
        scope: testAttachmentStorageScope(sessionId: "session-1"),
        bytes: bytes,
      );
      final handler = GetSessionAttachmentHandler(chatHistoryService: history.service);

      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/session/attachment",
          body: jsonEncode(
            SessionAttachmentRequest(
              sessionId: "session-1",
              attachmentId: digest,
              rendition: SessionAttachmentRendition.thumbnail,
            ).toJson(),
          ),
        ),
        pathParams: const {},
        queryParams: const {},
        fragment: null,
      );

      expect(response.status, 200);
      expect(response.body, isNot(contains(base64Encode(bytes))));
    });

    test("handleInternal keeps storage paths out of failure responses", () async {
      final handler = GetSessionAttachmentHandler(chatHistoryService: _FileFailingChatHistoryService());

      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/session/attachment",
          body: jsonEncode(
            const SessionAttachmentRequest(
              sessionId: "session-1",
              attachmentId: "attachment-1",
              rendition: SessionAttachmentRendition.original,
            ).toJson(),
          ),
        ),
        pathParams: const {},
        queryParams: const {},
        fragment: null,
      );

      expect(response.status, 500);
      expect(response.body, isNot(contains("/Users/alex/private/attachments")));
    });
  });
}

Future<void> _expectStatus({
  required GetSessionAttachmentHandler handler,
  required SessionAttachmentRequest request,
  required int status,
}) {
  return expectLater(
    () => handler.handle(
      makeRequest("POST", "/session/attachment"),
      body: request,
      pathParams: const {},
      queryParams: const {},
      fragment: null,
    ),
    throwsA(isA<RelayResponse>().having((response) => response.status, "status", status)),
  );
}

Uint8List _pngBytes() {
  final source = image.Image(width: 16, height: 8, numChannels: 3);
  image.fill(source, color: image.ColorRgb8(30, 80, 140));
  return image.encodePng(source);
}

class _FileFailingChatHistoryService implements ChatHistoryService {
  @override
  Future<SessionAttachmentResult> getSessionAttachment({
    required String sessionId,
    required String attachmentId,
    required SessionAttachmentRendition rendition,
  }) {
    throw const ProcessException(
      "chmod",
      ["/Users/alex/private/attachments/image.png"],
      "permission denied",
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
