import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/sse_event.dart";
import "package:sesori_shared/sesori_shared.dart";

void main() {
  group("SseEvent.sessionId lazy getter", () {
    test("extracts sessionId from SesoriSessionDiff", () {
      final event = SseEvent(
        data: const SesoriSessionDiff(
          sessionID: "session-diff-1",
        ),
      );

      expect(event.sessionId, equals("session-diff-1"));
    });

    test("extracts sessionId from SesoriSessionError", () {
      final event = SseEvent(
        data: const SesoriSessionError(
          sessionID: "session-error-1",
        ),
      );

      expect(event.sessionId, equals("session-error-1"));
    });

    test("extracts sessionId from SesoriSessionCompacted", () {
      final event = SseEvent(
        data: const SesoriSessionCompacted(
          sessionID: "session-compacted-1",
        ),
      );

      expect(event.sessionId, equals("session-compacted-1"));
    });

    test("extracts sessionId from SesoriMessageRemoved", () {
      final event = SseEvent(
        data: const SesoriMessageRemoved(
          sessionID: "session-msg-removed-1",
          messageID: "msg-1",
        ),
      );

      expect(event.sessionId, equals("session-msg-removed-1"));
    });

    test("extracts sessionId from SesoriMessagePartDelta", () {
      final event = SseEvent(
        data: const SesoriMessagePartDelta(
          sessionID: "session-delta-1",
          messageID: "msg-1",
          partID: "part-1",
          field: "content",
          delta: "delta text",
        ),
      );

      expect(event.sessionId, equals("session-delta-1"));
    });

    test("extracts sessionId from SesoriMessagePartRemoved", () {
      final event = SseEvent(
        data: const SesoriMessagePartRemoved(
          sessionID: "session-part-removed-1",
          messageID: "msg-1",
          partID: "part-1",
        ),
      );

      expect(event.sessionId, equals("session-part-removed-1"));
    });

    test("extracts sessionId from SesoriPermissionAsked", () {
      final event = SseEvent(
        data: const SesoriPermissionAsked(
          sessionID: "session-perm-1",
          requestID: "req-1",
          tool: "test_tool",
          description: "Test permission",
        ),
      );

      expect(event.sessionId, equals("session-perm-1"));
    });

    test("extracts sessionId from SesoriQuestionAsked", () {
      final event = SseEvent(
        data: const SesoriQuestionAsked(
          sessionID: "session-q-1",
          id: "q-1",
          questions: [],
        ),
      );

      expect(event.sessionId, equals("session-q-1"));
    });

    test("extracts sessionId from SesoriQuestionReplied", () {
      final event = SseEvent(
        data: const SesoriQuestionReplied(
          sessionID: "session-qr-1",
          requestID: "req-1",
        ),
      );

      expect(event.sessionId, equals("session-qr-1"));
    });

    test("extracts sessionId from SesoriQuestionRejected", () {
      final event = SseEvent(
        data: const SesoriQuestionRejected(
          sessionID: "session-qrej-1",
          requestID: "req-1",
        ),
      );

      expect(event.sessionId, equals("session-qrej-1"));
    });

    test("extracts sessionId from SesoriTodoUpdated", () {
      final event = SseEvent(
        data: const SesoriTodoUpdated(
          sessionID: "session-todo-1",
        ),
      );

      expect(event.sessionId, equals("session-todo-1"));
    });

    test("returns null for non-session-scoped events", () {
      final event = SseEvent(
        data: const SesoriServerConnected(),
      );

      expect(event.sessionId, isNull);
    });

    test("sessionId is lazy-evaluated only once", () {
      final event = SseEvent(
        data: const SesoriSessionDiff(
          sessionID: "session-lazy-1",
        ),
      );

      final firstAccess = event.sessionId;
      final secondAccess = event.sessionId;

      expect(firstAccess, equals("session-lazy-1"));
      expect(secondAccess, equals("session-lazy-1"));
      expect(identical(firstAccess, secondAccess), isTrue);
    });
  });
}
