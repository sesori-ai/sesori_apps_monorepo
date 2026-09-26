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

MessageWithParts _agent({required String id, required List<MessagePart> parts, int? at}) => MessageWithParts(
  info: Message.assistant(
    id: id,
    sessionID: "s",
    agent: null,
    modelID: null,
    providerID: null,
    sender: MessageSender.agent,
    time: at == null ? null : MessageTime(created: at, completed: null),
  ),
  parts: parts,
);

MessagePart _subAgent({required String id, required String childId}) => MessagePart.subtask(
  id: id,
  sessionID: "s",
  messageID: "a",
  taskState: null,
  childSessionID: childId,
);

Session _child({required String id, required int? createdAt}) => Session(
  approvalOverride: null,
  id: id,
  projectID: "p",
  directory: "/d",
  parentID: "s",
  title: null,
  time: createdAt == null ? null : SessionTime(created: createdAt, updated: createdAt, archived: null),
  pullRequest: null,
  promptDefaults: null,
  branchName: null,
  lastUserActivityAt: null,
  autoContinuation: null,
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
  List<Session> children = const [],
  Map<String, SessionStatus> childStatuses = const {},
}) {
  final transcript = const TranscriptBuilder().build(
    messages: messages,
    streamingText: streamingText,
    children: children,
    childStatuses: childStatuses,
  );
  return const TranscriptActivityBuilder().build(
    transcript: transcript,
    turns: const TranscriptTurnBuilder().build(
      messages: messages,
      transcript: transcript,
      isBusy: isBusy,
      hasOlderMessages: false,
    ),
    messages: messages,
    isBusy: isBusy,
    retryErrorMessage: retryErrorMessage,
    hasStreamingText: streamingText.isNotEmpty,
    children: children,
    childStatuses: childStatuses,
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

    group("sub-agents", () {
      final prompt = _prompt(id: "u1", at: 1000);
      final spawned = _agent(
        id: "a1",
        at: 2000,
        parts: [
          _subAgent(id: "sa1", childId: "c1"),
          _subAgent(id: "sa2", childId: "c2"),
        ],
      );
      final children = [_child(id: "c1", createdAt: 3000), _child(id: "c2", createdAt: 4000)];
      const bothRunning = {"c1": SessionStatus.busy(), "c2": SessionStatus.retry(attempt: 1, message: "", next: 0)};

      test("show while only sub-agents run, counted from their step's message", () {
        final activity = _activity(
          messages: [prompt, spawned],
          isBusy: true,
          children: children,
          childStatuses: bothRunning,
        );

        expect(
          activity,
          isA<TranscriptActivitySubAgents>()
              .having((a) => a.count, "count", 2)
              .having((a) => a.sinceMs, "sinceMs", 2000),
        );
      });

      test("fall back to the earliest running child's own start", () {
        // No sub-agent step links either child, so each child's creation counts.
        final activity = _activity(
          messages: [prompt],
          isBusy: true,
          children: children,
          childStatuses: const {"c1": SessionStatus.idle(), "c2": SessionStatus.busy()},
        );

        expect(
          activity,
          isA<TranscriptActivitySubAgents>()
              .having((a) => a.count, "count", 1)
              .having((a) => a.sinceMs, "sinceMs", 4000),
        );
      });

      test("show without a time when no start is known", () {
        final activity = _activity(
          messages: [prompt],
          isBusy: true,
          children: [_child(id: "c1", createdAt: null)],
          childStatuses: const {"c1": SessionStatus.busy()},
        );

        expect(activity, isA<TranscriptActivitySubAgents>().having((a) => a.sinceMs, "sinceMs", isNull));
      });

      test("give way to the main agent's own work", () {
        final ownStep = _agent(
          id: "a2",
          parts: [_tool(status: ToolStatus.running)],
        );
        expect(
          _activity(messages: [prompt, spawned, ownStep], isBusy: true, children: children, childStatuses: bothRunning),
          isA<TranscriptActivityIdle>(),
        );
        expect(
          _activity(
            messages: [prompt, spawned],
            isBusy: true,
            streamingText: const {"t": "Hel"},
            children: children,
            childStatuses: bothRunning,
          ),
          isA<TranscriptActivityIdle>(),
        );
        expect(
          _activity(
            messages: [prompt, spawned],
            isBusy: true,
            retryErrorMessage: "Overloaded",
            children: children,
            childStatuses: bothRunning,
          ),
          isA<TranscriptActivityIdle>(),
        );
      });

      test("hide when the session is not busy", () {
        expect(
          _activity(messages: [prompt, spawned], isBusy: false, children: children, childStatuses: bothRunning),
          isA<TranscriptActivityIdle>(),
        );
      });

      test("leave Working when no sub-agent runs", () {
        expect(
          _activity(
            messages: [prompt, spawned],
            isBusy: true,
            children: children,
            childStatuses: const {"c1": SessionStatus.idle(), "c2": SessionStatus.idle()},
          ),
          isA<TranscriptActivityWorking>(),
        );
      });
    });
  });

  test("runningChildren keeps busy and retrying children", () {
    expect(
      runningChildren(
        children: [
          _child(id: "busy", createdAt: null),
          _child(id: "retry", createdAt: null),
          _child(id: "idle", createdAt: null),
          _child(id: "unknown", createdAt: null),
        ],
        childStatuses: const {
          "busy": SessionStatus.busy(),
          "retry": SessionStatus.retry(attempt: 1, message: "", next: 0),
          "idle": SessionStatus.idle(),
        },
      ).map((child) => child.id),
      ["busy", "retry"],
    );
  });
}
