import "package:sesori_dart_core/src/cubits/session_detail/deferred_part_event_buffer.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

const _sessionId = "session-1";
const _messageId = "message-1";

MessagePart _textPart({required String id, required String text}) => MessagePart(
  id: id,
  sessionID: _sessionId,
  messageID: _messageId,
  type: MessagePartType.text,
  text: text,
  tool: null,
  state: null,
  prompt: null,
  description: null,
  agent: null,
  childSessionID: null,
  agentName: null,
  attempt: null,
  retryError: null,
  attachment: null,
);

void main() {
  group("DeferredPartEventBuffer", () {
    late DeferredPartEventBuffer buffer;

    setUp(() => buffer = DeferredPartEventBuffer());

    test("keeps only the latest event for a part without moving its position", () {
      buffer.deferUpdated(
        part: _textPart(id: "part-a", text: "old"),
      );
      buffer.deferUpdated(
        part: _textPart(id: "part-b", text: "second"),
      );
      buffer.deferUpdated(
        part: _textPart(id: "part-a", text: "new"),
      );

      final events = buffer.takeForMessage(messageId: _messageId);

      expect(events, hasLength(2));
      expect(
        events.map(
          (event) => switch (event) {
            SesoriMessagePartUpdated(:final part) => (part.id, part.text),
            SesoriMessagePartRemoved(:final partID) => (partID, null),
            _ => throw StateError("Unexpected deferred event: $event"),
          },
        ),
        [("part-a", "new"), ("part-b", "second")],
      );
    });

    test("a removal tombstone replaces an earlier update", () {
      buffer.deferUpdated(
        part: _textPart(id: "part-a", text: "old"),
      );
      buffer.deferRemoved(
        sessionId: _sessionId,
        messageId: _messageId,
        partId: "part-a",
      );

      expect(
        buffer.takeForMessage(messageId: _messageId),
        [
          const SesoriMessagePartRemoved(
            sessionID: _sessionId,
            messageID: _messageId,
            partID: "part-a",
          ),
        ],
      );
    });

    test("a later update replaces a removal tombstone", () {
      buffer.deferRemoved(
        sessionId: _sessionId,
        messageId: _messageId,
        partId: "part-a",
      );
      buffer.deferUpdated(
        part: _textPart(id: "part-a", text: "restored"),
      );

      expect(
        buffer.takeForMessage(messageId: _messageId),
        [
          SesoriMessagePartUpdated(
            part: _textPart(id: "part-a", text: "restored"),
          ),
        ],
      );
    });

    test("snapshot watermark discards older events but keeps newer replacements", () {
      buffer.deferUpdated(
        part: _textPart(id: "part-a", text: "stale"),
      );
      buffer.deferUpdated(
        part: _textPart(id: "part-b", text: "also stale"),
      );
      final snapshotWatermark = buffer.latestSequence;
      buffer.deferUpdated(
        part: _textPart(id: "part-a", text: "live"),
      );

      buffer.discardForMessagesThrough(
        messageIds: [_messageId],
        sequence: snapshotWatermark,
      );

      expect(
        buffer.takeForMessage(messageId: _messageId),
        [
          SesoriMessagePartUpdated(
            part: _textPart(id: "part-a", text: "live"),
          ),
        ],
      );
    });
  });
}
