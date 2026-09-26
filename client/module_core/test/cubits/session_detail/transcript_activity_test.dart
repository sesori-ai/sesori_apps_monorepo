import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

MessageWithParts _prompt({required String id, required int? at}) => MessageWithParts(
  info: Message.user(
    id: id,
    sessionID: "s",
    agent: null,
    time: at == null ? null : MessageTime(created: at, completed: null),
    promptId: null,
  ),
  parts: [MessagePart.text(id: "$id-text", sessionID: "s", messageID: id, text: "Fix the build")],
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

MessagePart _tool({required ToolStatus status}) => MessagePart.tool(
  id: "tool",
  sessionID: "s",
  messageID: "a",
  tool: "read",
  state: ToolState(status: status, title: null, shellCommand: null, output: null, error: null),
);

/// The activity over [messages], with the inputs the message list passes.
TranscriptActivity _activity({
  required List<MessageWithParts> messages,
  required bool isBusy,
  String? retryErrorMessage,
  Map<String, String> streamingText = const {},
}) {
  final transcript = const TranscriptBuilder().build(
    messages: messages,
    streamingText: streamingText,
    children: const [],
    childStatuses: const {},
  );
  return const TranscriptActivityBuilder().build(
    transcript: transcript,
    turns: const TranscriptTurnBuilder().build(
      messages: messages,
      transcript: transcript,
      isBusy: isBusy,
      hasOlderMessages: false,
    ),
    isBusy: isBusy,
    retryErrorMessage: retryErrorMessage,
    hasStreamingText: streamingText.isNotEmpty,
  );
}

void main() {
  group("TranscriptActivityBuilder", () {
    test("works since the running turn's prompt was sent", () {
      final activity = _activity(
        messages: [
          _prompt(id: "u1", at: 1000),
          _agent(
            id: "a1",
            parts: [const MessagePart.text(id: "t", sessionID: "s", messageID: "a1", text: "Done.")],
          ),
          _prompt(id: "u2", at: 5000),
        ],
        isBusy: true,
      );

      expect(activity, isA<TranscriptActivityWorking>().having((a) => a.sinceMs, "sinceMs", 5000));
    });

    test("works without a time when the prompt carries none", () {
      final activity = _activity(messages: [_prompt(id: "u1", at: null)], isBusy: true);

      expect(activity, isA<TranscriptActivityWorking>().having((a) => a.sinceMs, "sinceMs", isNull));
    });

    test("works without a time in a headless segment", () {
      final activity = _activity(
        messages: [
          _agent(
            id: "a1",
            parts: [_tool(status: ToolStatus.completed)],
          ),
        ],
        isBusy: true,
      );

      expect(activity, isA<TranscriptActivityWorking>().having((a) => a.sinceMs, "sinceMs", isNull));
    });

    test("is idle when the session is not busy", () {
      expect(_activity(messages: [_prompt(id: "u1", at: 1000)], isBusy: false), isA<TranscriptActivityIdle>());
    });

    test("is idle while a step is live, text streams or the retry row shows", () {
      final prompt = _prompt(id: "u1", at: 1000);
      expect(
        _activity(
          messages: [
            prompt,
            _agent(
              id: "a1",
              parts: [_tool(status: ToolStatus.running)],
            ),
          ],
          isBusy: true,
        ),
        isA<TranscriptActivityIdle>(),
      );
      expect(
        _activity(messages: [prompt], isBusy: true, streamingText: const {"t": "Hel"}),
        isA<TranscriptActivityIdle>(),
      );
      expect(
        _activity(messages: [prompt], isBusy: true, retryErrorMessage: "Overloaded"),
        isA<TranscriptActivityIdle>(),
      );
    });
  });
}
