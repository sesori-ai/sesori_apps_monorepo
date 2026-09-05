import "package:sesori_dart_core/src/services/transcript_snapshot_calculator.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

const _sessionId = "session-1";

Message _user({required String id, required int? created}) => Message.user(
  id: id,
  sessionID: _sessionId,
  agent: "build",
  time: created == null ? null : MessageTime(created: created, completed: null),
  promptId: null,
);

Message _assistant({required String id, required int created, required String modelID}) => Message.assistant(
  id: id,
  sessionID: _sessionId,
  agent: "build",
  modelID: modelID,
  providerID: "provider",
  time: MessageTime(created: created, completed: null),
);

MessagePart _text({required String messageId, required String id, required String text}) =>
    MessagePart.text(id: id, sessionID: _sessionId, messageID: messageId, text: text);

MessageWithParts _message(Message info, {List<MessagePart> parts = const []}) =>
    MessageWithParts(info: info, parts: parts);

void main() {
  const calculator = TranscriptSnapshotCalculator();
  final user1 = _user(id: "m1", created: 100);
  final user2 = _user(id: "m2", created: 200);
  final user3 = _user(id: "m3", created: 300);

  group("TranscriptSnapshotCalculator.reconcile", () {
    test("an unchanged transcript installs the fetched page as-is", () {
      final before = [_message(user1), _message(user2)];
      final fetched = [
        _message(
          user1,
          parts: [_text(messageId: "m1", id: "p1", text: "fresh")],
        ),
        _message(user2),
      ];
      expect(calculator.reconcile(before: before, live: before, fetched: fetched), fetched);
    });

    test("keeps both the fetched replacement of a part and a part added live during the fetch", () {
      final stale = _text(messageId: "m1", id: "p-before", text: "stale");
      final live = _text(messageId: "m1", id: "p-during", text: "live");
      final fresh = _text(messageId: "m1", id: "p-before", text: "fresh snapshot");

      final result = calculator.reconcile(
        before: [
          _message(user1, parts: [stale]),
        ],
        live: [
          _message(user1, parts: [stale, live]),
        ],
        fetched: [
          _message(user1, parts: [fresh]),
        ],
      );

      expect(result, [
        _message(user1, parts: [fresh, live]),
      ]);
    });

    test("a message removed live is omitted even when the page still contains it", () {
      final result = calculator.reconcile(
        before: [_message(user1), _message(user2)],
        live: [_message(user2)],
        fetched: [_message(user1), _message(user2)],
      );
      expect(result, [_message(user2)]);
    });

    test("a message added live joins the page at its creation time", () {
      final result = calculator.reconcile(
        before: [_message(user1), _message(user3)],
        live: [_message(user1), _message(user2), _message(user3)],
        fetched: [_message(user1), _message(user3)],
      );
      expect(result, [_message(user1), _message(user2), _message(user3)]);
    });

    test("a message changed live is retained when the page omits it", () {
      final changed = _message(_assistant(id: "a1", created: 150, modelID: "new"));
      final result = calculator.reconcile(
        before: [
          _message(user1),
          _message(_assistant(id: "a1", created: 150, modelID: "old")),
        ],
        live: [_message(user1), changed],
        fetched: [_message(user1)],
      );
      expect(result, [_message(user1), changed]);
    });

    test("a message the page omits without any live change is gone", () {
      final result = calculator.reconcile(
        before: [_message(user1), _message(user2)],
        live: [_message(user1), _message(user2)],
        fetched: [_message(user2)],
      );
      expect(result, [_message(user2)]);
    });

    test("a changed live envelope keeps the fetched part list", () {
      final beforeEnvelope = _assistant(id: "a1", created: 150, modelID: "old");
      final liveEnvelope = _assistant(id: "a1", created: 150, modelID: "new");
      final fetchedPart = _text(messageId: "a1", id: "p1", text: "answer");
      final result = calculator.reconcile(
        before: [_message(beforeEnvelope)],
        live: [_message(liveEnvelope)],
        fetched: [
          _message(beforeEnvelope, parts: [fetchedPart]),
        ],
      );
      expect(result, [
        _message(liveEnvelope, parts: [fetchedPart]),
      ]);
    });

    test("parts overlay independently: fetched-only kept, live change wins, live removal drops", () {
      final kept = _text(messageId: "m1", id: "kept", text: "kept");
      final changedBefore = _text(messageId: "m1", id: "changed", text: "old");
      final changedLive = _text(messageId: "m1", id: "changed", text: "new");
      final changedFetched = _text(messageId: "m1", id: "changed", text: "fetched");
      final removed = _text(messageId: "m1", id: "removed", text: "removed");
      final fetchedOnly = _text(messageId: "m1", id: "fetched-only", text: "fetched only");

      final result = calculator.reconcile(
        before: [
          _message(user1, parts: [kept, changedBefore, removed]),
        ],
        live: [
          _message(user1, parts: [kept, changedLive]),
        ],
        fetched: [
          _message(user1, parts: [kept, changedFetched, removed, fetchedOnly]),
        ],
      );

      expect(result, [
        _message(user1, parts: [kept, changedLive, fetchedOnly]),
      ]);
    });

    test("a part unchanged live but absent from the page is dropped", () {
      final stale = _text(messageId: "m1", id: "stale", text: "stale");
      final result = calculator.reconcile(
        before: [
          _message(user1, parts: [stale]),
        ],
        live: [
          _message(user1, parts: [stale]),
        ],
        fetched: [_message(user1)],
      );
      expect(result, [_message(user1)]);
    });
  });

  group("TranscriptSnapshotCalculator.insertionIndex", () {
    test("inserts before the first later message and appends without a creation time", () {
      final messages = [_message(user1), _message(user3)];
      expect(calculator.insertionIndex(messages: messages, message: user2), 1);
      expect(
        calculator.insertionIndex(
          messages: messages,
          message: _user(id: "m4", created: 400),
        ),
        2,
      );
      expect(
        calculator.insertionIndex(
          messages: messages,
          message: _user(id: "m5", created: null),
        ),
        2,
      );
    });
  });
}
