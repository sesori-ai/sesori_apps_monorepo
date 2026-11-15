import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

MessageWithParts _user({required String id, MessageHandoff? handoff, String text = "Fix the build"}) =>
    MessageWithParts(
      info: Message.user(
        invocation: null,
        handoff: handoff,
        id: id,
        sessionID: "s",
        agent: null,
        time: null,
        promptId: null,
      ),
      parts: [MessagePart.text(id: "$id-text", sessionID: "s", messageID: id, text: text)],
    );

MessageWithParts _agent({required String id, required List<MessagePart> parts}) => MessageWithParts(
  info: Message.assistant(
    id: id,
    sessionID: "s",
    agent: null,
    modelID: null,
    providerID: null,
    sender: MessageSender.agent,
    time: null,
  ),
  parts: parts,
);

MessagePart _text({required String text}) =>
    MessagePart.text(id: "text-$text", sessionID: "s", messageID: "m", text: text);

MessagePart _runningTool() => const MessagePart.tool(
  id: "tool",
  sessionID: "s",
  messageID: "m",
  tool: "read",
  state: ToolState(status: ToolStatus.running, title: null, shellCommand: null, output: null, error: null),
);

const _sent = MessageHandoff.sent(targetSessionId: "target", targetTitle: "Fix login");
const _notSent = MessageHandoff.notSent(targetSessionId: "target", targetTitle: null);

TranscriptHandoffs _build({required List<MessageWithParts> messages, required bool isBusy}) =>
    const TranscriptHandoffBuilder().build(
      messages: messages,
      turns: const TranscriptTurnBuilder().build(messages: messages, hasOlderMessages: false),
      isBusy: isBusy,
    );

void main() {
  group("TranscriptHandoffBuilder", () {
    test("folds a running summary turn into a writing marker", () {
      final handoffs = _build(
        messages: [
          _user(id: "request", handoff: _sent),
          _agent(
            id: "reply",
            parts: [_text(text: "Goal: fix")],
          ),
        ],
        isBusy: true,
      );

      final marker = handoffs.markers["request"];
      expect(marker?.status, TranscriptHandoffMarkerStatus.writing);
      expect(marker?.targetSessionId, "target");
      expect(marker?.targetTitle, "Fix login");
      expect(handoffs.foldedMessageIds, {"reply"});
      expect(handoffs.writing, isTrue);
    });

    test("an ended summary turn reads as sent, with the agent's text as the summary", () {
      final handoffs = _build(
        messages: [
          _user(id: "earlier"),
          _agent(
            id: "earlier-reply",
            parts: [_text(text: "Done.")],
          ),
          _user(id: "request", handoff: _sent),
          _agent(
            id: "reply-1",
            parts: [_text(text: "Goal: fix")],
          ),
          _agent(
            id: "reply-2",
            parts: [
              _text(text: "  "),
              _text(text: "Next: test "),
            ],
          ),
        ],
        isBusy: false,
      );

      final marker = handoffs.markers["request"];
      expect(marker?.status, TranscriptHandoffMarkerStatus.sent);
      expect(marker?.summary, "Goal: fix\n\nNext: test");
      expect(handoffs.foldedMessageIds, {"reply-1", "reply-2"});
      expect(handoffs.writing, isFalse);
      expect(handoffs.markers.keys, ["request"]);
    });

    test("a summary turn that a newer turn follows is sent while the session works", () {
      final handoffs = _build(
        messages: [
          _user(id: "request", handoff: _sent),
          _agent(
            id: "reply",
            parts: [_text(text: "Goal: fix")],
          ),
          _user(id: "next"),
        ],
        isBusy: true,
      );

      expect(handoffs.markers["request"]?.status, TranscriptHandoffMarkerStatus.sent);
      expect(handoffs.foldedMessageIds, {"reply"});
      expect(handoffs.writing, isFalse);
    });

    test("a send that did not complete folds into a not-sent marker, with any reply", () {
      final withReply = _build(
        messages: [
          _user(id: "request", handoff: _notSent),
          _agent(
            id: "reply",
            parts: [_text(text: "Partial")],
          ),
        ],
        isBusy: false,
      );
      final withoutReply = _build(
        messages: [_user(id: "request", handoff: _notSent)],
        isBusy: false,
      );

      expect(withReply.markers["request"]?.status, TranscriptHandoffMarkerStatus.notSent);
      expect(withReply.markers["request"]?.summary, "Partial");
      expect(withReply.foldedMessageIds, {"reply"});
      expect(withoutReply.markers["request"]?.status, TranscriptHandoffMarkerStatus.notSent);
      expect(withoutReply.markers["request"]?.summary, isNull);
    });

    test("a follow-up steered into the summary turn is folded too, and stays out of the summary", () {
      final handoffs = _build(
        messages: [
          _user(id: "request", handoff: _sent),
          _agent(
            id: "step",
            parts: [
              _text(text: "Goal: fix"),
              _runningTool(),
            ],
          ),
          _user(id: "steer", text: "Also mention the tests"),
          _agent(
            id: "after",
            parts: [_text(text: "Tests: green")],
          ),
        ],
        isBusy: true,
      );

      expect(handoffs.markers.keys, ["request"]);
      expect(handoffs.markers["request"]?.status, TranscriptHandoffMarkerStatus.writing);
      expect(handoffs.markers["request"]?.summary, "Goal: fix");
      expect(handoffs.foldedMessageIds, {"step", "steer", "after"});
    });

    test("a request the turn rule reads as a follow-up folds from where it is", () {
      final handoffs = _build(
        messages: [
          _user(id: "earlier"),
          _agent(id: "mid-step", parts: [_runningTool()]),
          _user(id: "request", handoff: _sent),
          _agent(
            id: "reply",
            parts: [_text(text: "Goal: fix")],
          ),
        ],
        isBusy: false,
      );

      expect(handoffs.markers.keys, ["request"]);
      expect(handoffs.foldedMessageIds, {"reply"});
    });

    test("a handoff prompt in the target becomes a card", () {
      final handoffs = _build(
        messages: [
          _user(
            id: "handoff",
            handoff: const MessageHandoff.received(
              sourceSessionId: "source",
              sourceTitle: "Old work",
              summary: "Goal: fix",
              transcriptPath: "/tmp/t.md",
            ),
          ),
          _agent(
            id: "reply",
            parts: [_text(text: "On it")],
          ),
        ],
        isBusy: false,
      );

      final card = handoffs.cards["handoff"];
      expect(card?.sourceSessionId, "source");
      expect(card?.sourceTitle, "Old work");
      expect(card?.summary, "Goal: fix");
      expect(card?.transcriptPath, "/tmp/t.md");
      expect(handoffs.markers, isEmpty);
      expect(handoffs.foldedMessageIds, isEmpty);
    });

    test("ordinary and unknown-kind messages keep their own rows", () {
      final handoffs = _build(
        messages: [
          _user(id: "plain"),
          _agent(
            id: "reply",
            parts: [_text(text: "Done.")],
          ),
          _user(id: "later", handoff: const MessageHandoff.unknown()),
        ],
        isBusy: false,
      );

      expect(handoffs.markers, isEmpty);
      expect(handoffs.cards, isEmpty);
      expect(handoffs.foldedMessageIds, isEmpty);
      expect(handoffs.writing, isFalse);
    });
  });
}
