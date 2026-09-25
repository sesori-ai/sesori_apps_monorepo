import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

const _builder = TranscriptBuilder();

MessageWithParts _assistant(
  String id,
  List<MessagePart> parts, {
  MessageSender sender = MessageSender.agent,
}) => MessageWithParts(
  info: Message.assistant(
    id: id,
    sessionID: "s",
    agent: null,
    modelID: null,
    providerID: null,
    sender: sender,
    time: null,
  ),
  parts: parts,
);

MessageWithParts _user(String id) => MessageWithParts(
  info: Message.user(id: id, sessionID: "s", agent: null, time: null, promptId: null),
  parts: [MessagePart.text(id: "$id-text", sessionID: "s", messageID: id, text: "hi")],
);

MessageWithParts _error(String id) => MessageWithParts(
  info: Message.error(
    id: id,
    sessionID: "s",
    agent: null,
    modelID: null,
    providerID: null,
    errorName: "E",
    errorMessage: "boom",
    time: null,
  ),
  parts: const [],
);

MessagePart _text(String id, {String text = "words"}) =>
    MessagePart.text(id: id, sessionID: "s", messageID: "m", text: text);

MessagePart _tool(String id, {ToolStatus status = ToolStatus.completed}) => MessagePart.tool(
  id: id,
  sessionID: "s",
  messageID: "m",
  tool: "read",
  state: ToolState(status: status, title: null, shellCommand: null, output: null, error: null),
);

MessagePart _thought(String id, {String text = "hmm"}) =>
    MessagePart.reasoning(id: id, sessionID: "s", messageID: "m", text: text);

MessagePart _subtask(String id, {ToolState? taskState, String? childSessionID, String description = "Explore"}) =>
    MessagePart.subtask(
      id: id,
      sessionID: "s",
      messageID: "m",
      description: description,
      taskState: taskState,
      childSessionID: childSessionID,
    );

MessagePart _stepStart(String id) => MessagePart.stepStart(id: id, sessionID: "s", messageID: "m");
MessagePart _stepFinish(String id) => MessagePart.stepFinish(id: id, sessionID: "s", messageID: "m");
MessagePart _patch(String id) => MessagePart.patch(id: id, sessionID: "s", messageID: "m");
MessagePart _file(String id) => MessagePart.file(
  id: id,
  sessionID: "s",
  messageID: "m",
  attachment: const MessageAttachment.metadata(mime: "image/png", filename: null),
);

Session _child(String id, {String? title}) => Session(
  id: id,
  projectID: "p",
  directory: "/d",
  parentID: "s",
  title: title,
  time: null,
  pullRequest: null,
  promptDefaults: null,
  branchName: null,
  lastUserActivityAt: null,
  autoContinuation: null,
);

ToolState _taskState(ToolStatus status) =>
    ToolState(status: status, title: null, shellCommand: null, output: null, error: null);

Transcript _build(
  List<MessageWithParts> messages, {
  Map<String, String> streamingText = const {},
  List<Session> children = const [],
  Map<String, SessionStatus> childStatuses = const {},
}) => _builder.build(
  messages: messages,
  streamingText: streamingText,
  children: children,
  childStatuses: childStatuses,
);

/// A compact picture of one row: `text[a,b]` for a parts block and
/// `group(id: steps)` for a group.
List<String> _shape(Transcript transcript, String messageId) => [
  for (final block in transcript.blocksFor(messageId: messageId))
    switch (block) {
      TranscriptPartsBlock(:final parts) => "parts[${parts.map((part) => part.id).join(",")}]",
      TranscriptGroupBlock(:final id, :final steps) => "group($id: ${steps.map((step) => step.id).join(",")})",
    },
];

TranscriptGroupBlock _onlyGroup(Transcript transcript, String messageId) =>
    transcript.blocksFor(messageId: messageId).whereType<TranscriptGroupBlock>().single;

void main() {
  group("TranscriptBuilder grouping", () {
    test("consecutive tools, thinking and steps form one group", () {
      final transcript = _build([
        _assistant("m1", [_stepStart("s1"), _thought("r1"), _tool("t1"), _tool("t2"), _stepFinish("f1")]),
      ]);

      expect(_shape(transcript, "m1"), ["group(r1: r1,t1,t2)"]);
    });

    test("a group ends at every piece of text", () {
      final transcript = _build([
        _assistant("m1", [_tool("t1"), _text("x1"), _tool("t2"), _tool("t3"), _text("x2")]),
      ]);

      expect(_shape(transcript, "m1"), ["group(t1: t1)", "parts[x1]", "group(t2: t2,t3)", "parts[x2]"]);
    });

    test("a group spans agent messages and sits in the row it started in", () {
      final transcript = _build([
        _assistant("m1", [_text("x1"), _tool("t1")]),
        _assistant("m2", [_stepStart("s2"), _tool("t2")]),
        _assistant("m3", [_tool("t3"), _text("x3")]),
      ]);

      expect(_shape(transcript, "m1"), ["parts[x1]", "group(t1: t1,t2,t3)"]);
      expect(_shape(transcript, "m2"), isEmpty);
      expect(_shape(transcript, "m3"), ["parts[x3]"]);
    });

    test("user and error messages end a group", () {
      final transcript = _build([
        _assistant("m1", [_tool("t1")]),
        _user("u1"),
        _assistant("m2", [_tool("t2")]),
        _error("e1"),
        _assistant("m3", [_tool("t3")]),
      ]);

      expect(_shape(transcript, "m1"), ["group(t1: t1)"]);
      expect(_shape(transcript, "m2"), ["group(t2: t2)"]);
      expect(_shape(transcript, "m3"), ["group(t3: t3)"]);
      expect(transcript.blocksByMessageId.containsKey("u1"), isFalse);
    });

    test("automation messages group only their own steps", () {
      final transcript = _build([
        _assistant("m1", [_tool("t1")]),
        _assistant("a1", [_tool("t2")], sender: MessageSender.system),
        _assistant("m2", [_tool("t3")]),
      ]);

      expect(_shape(transcript, "m1"), ["group(t1: t1)"]);
      expect(_shape(transcript, "a1"), ["group(t2: t2)"]);
      expect(_shape(transcript, "m2"), ["group(t3: t3)"]);
    });

    test("hidden parts never end a group", () {
      final transcript = _build([
        _assistant("m1", [_tool("t1"), _patch("p1"), _text("empty", text: ""), _thought("r0", text: ""), _tool("t2")]),
      ]);

      expect(_shape(transcript, "m1"), ["group(t1: t1,t2)"]);
    });

    test("hidden parts keep the attachment runs of a parts block apart", () {
      final transcript = _build([
        _assistant("m1", [_file("f1"), _patch("p1"), _file("f2")]),
      ]);

      expect(_shape(transcript, "m1"), ["parts[f1,p1,f2]"]);
    });

    test("files, agent switches and retries end a group like text", () {
      final transcript = _build([
        _assistant("m1", [
          _tool("t1"),
          _file("f1"),
          _tool("t2"),
          const MessagePart.agent(id: "a1", sessionID: "s", messageID: "m", agentName: "plan"),
          _tool("t3"),
          const MessagePart.retry(id: "y1", sessionID: "s", messageID: "m", attempt: 2, retryError: "rate"),
        ]),
      ]);

      expect(_shape(transcript, "m1"), [
        "group(t1: t1)",
        "parts[f1]",
        "group(t2: t2)",
        "parts[a1]",
        "group(t3: t3)",
        "parts[y1]",
      ]);
    });

    test("streaming text ends a group even while it is still empty", () {
      final transcript = _build(
        [
          _assistant("m1", [_tool("t1"), _text("x1", text: ""), _tool("t2")]),
        ],
        streamingText: {"x1": ""},
      );

      expect(_shape(transcript, "m1"), ["group(t1: t1)", "parts[x1]", "group(t2: t2)"]);
    });

    test("a message with no parts has an empty row", () {
      final transcript = _build([_assistant("m1", const [])]);

      expect(transcript.blocksFor(messageId: "m1"), isEmpty);
      expect(transcript.blocksFor(messageId: "missing"), isEmpty);
    });
  });

  group("TranscriptBuilder step status", () {
    test("maps tool states, counting cancelled and unknown as finished", () {
      final transcript = _build([
        _assistant("m1", [
          for (final status in ToolStatus.values) _tool(status.name, status: status),
        ]),
      ]);

      final statuses = {for (final step in _onlyGroup(transcript, "m1").steps) step.id: step.status};
      expect(statuses, {
        "pending": TranscriptStepStatus.running,
        "running": TranscriptStepStatus.running,
        "completed": TranscriptStepStatus.finished,
        "error": TranscriptStepStatus.failed,
        "cancelled": TranscriptStepStatus.finished,
        "unknown": TranscriptStepStatus.finished,
      });
    });

    test("streaming thinking runs and carries the streamed text", () {
      final transcript = _build(
        [
          _assistant("m1", [_thought("r1", text: ""), _thought("r2", text: "done thinking")]),
        ],
        streamingText: {"r1": "latest words"},
      );

      final steps = _onlyGroup(transcript, "m1").steps.cast<TranscriptThinkingStep>();
      expect(
        [for (final step in steps) (step.text, step.status)],
        [
          ("latest words", TranscriptStepStatus.running),
          ("done thinking", TranscriptStepStatus.finished),
        ],
      );
    });

    test("a sub-agent's own lifecycle is authoritative", () {
      final transcript = _build(
        [
          _assistant("m1", [_subtask("k1", taskState: _taskState(ToolStatus.error), childSessionID: "c1")]),
        ],
        children: [_child("c1")],
        childStatuses: {"c1": const SessionStatus.busy()},
      );

      final step = _onlyGroup(transcript, "m1").steps.single as TranscriptSubAgentStep;
      expect(step.status, TranscriptStepStatus.failed);
      expect(step.childSession?.id, "c1");
    });

    test("without a lifecycle a sub-agent follows its child session", () {
      final transcript = _build(
        [
          _assistant("m1", [
            _subtask("k1", childSessionID: "c1"),
            _subtask("k2", childSessionID: "c2"),
            _subtask("k3", childSessionID: "c3"),
            _subtask("k4", childSessionID: "missing"),
          ]),
        ],
        children: [_child("c1"), _child("c2"), _child("c3")],
        childStatuses: {"c1": const SessionStatus.busy(), "c2": const SessionStatus.idle()},
      );

      final statuses = {for (final step in _onlyGroup(transcript, "m1").steps) step.id: step.status};
      expect(statuses, {
        "k1": TranscriptStepStatus.running,
        "k2": TranscriptStepStatus.finished,
        "k3": TranscriptStepStatus.finished,
        "k4": TranscriptStepStatus.finished,
      });
    });

    test("finished and running steps split in order", () {
      final transcript = _build([
        _assistant("m1", [
          _tool("t1"),
          _tool("t2", status: ToolStatus.running),
          _tool("t3", status: ToolStatus.error),
        ]),
      ]);

      final group = _onlyGroup(transcript, "m1");
      expect(group.finishedSteps.map((step) => step.id), ["t1", "t3"]);
      expect(group.runningSteps.map((step) => step.id), ["t2"]);
    });

    test("the live step is the newest running step", () {
      final transcript = _build([
        _assistant("m1", [_tool("t1", status: ToolStatus.running), _text("x1")]),
        _assistant("m2", [_tool("t2", status: ToolStatus.running), _tool("t3")]),
      ]);

      expect(transcript.liveStep?.id, "t2");
      expect(
        _build([
          _assistant("m1", [_tool("t1")]),
        ]).liveStep,
        isNull,
      );
    });
  });

  group("TranscriptBuilder summary", () {
    test("counts finished steps by kind in order of first appearance, plus failures", () {
      final transcript = _build(
        [
          _assistant("m1", [
            _tool("t1"),
            _thought("r1"),
            _tool("t2", status: ToolStatus.error),
            _subtask("k1", taskState: _taskState(ToolStatus.completed), childSessionID: null),
            _thought("r2"),
            _subtask("k2", taskState: _taskState(ToolStatus.completed), childSessionID: null),
          ]),
        ],
      );

      final summary = _onlyGroup(transcript, "m1").summary;
      expect(summary.counts, [
        (kind: TranscriptStepKind.tool, count: 2),
        (kind: TranscriptStepKind.thinking, count: 2),
        (kind: TranscriptStepKind.subAgent, count: 2),
      ]);
      expect(summary.failedCount, 1);
      expect(summary.isEmpty, isFalse);
    });

    test("running steps are not counted until they finish", () {
      final transcript = _build(
        [
          _assistant("m1", [_thought("r1"), _tool("t1", status: ToolStatus.running)]),
        ],
        streamingText: {"r1": "still"},
      );

      final summary = _onlyGroup(transcript, "m1").summary;
      expect(summary.counts, isEmpty);
      expect(summary.failedCount, 0);
      expect(summary.isEmpty, isTrue);
    });
  });

  group("TranscriptBuilder.childSessionFor", () {
    MessagePartSubtask subtask({String? childSessionID, String description = "", String prompt = ""}) =>
        MessagePart.subtask(
          id: "k",
          sessionID: "s",
          messageID: "m",
          description: description,
          prompt: prompt,
          taskState: null,
          childSessionID: childSessionID,
        ) as MessagePartSubtask;

    test("a named child is matched by id only", () {
      final children = [_child("c1", title: "Explore"), _child("c2")];

      expect(
        _builder
            .childSessionFor(
              part: subtask(childSessionID: "c2"),
              children: children,
            )
            ?.id,
        "c2",
      );
      expect(
        _builder.childSessionFor(
          part: subtask(childSessionID: "c9", description: "Explore"),
          children: children,
        ),
        isNull,
      );
    });

    test("an unnamed child falls back to the only child, then to its title", () {
      expect(_builder.childSessionFor(part: subtask(), children: [_child("only")])?.id, "only");
      expect(_builder.childSessionFor(part: subtask(), children: const []), isNull);

      final children = [_child("a", title: "Fix the tests"), _child("b", title: "Explore the repo")];
      expect(
        _builder
            .childSessionFor(
              part: subtask(description: "Explore the repo"),
              children: children,
            )
            ?.id,
        "b",
      );
      expect(
        _builder
            .childSessionFor(
              part: subtask(description: "explore THE repo"),
              children: children,
            )
            ?.id,
        "b",
      );
      expect(
        _builder
            .childSessionFor(
              part: subtask(prompt: "Fix the tests now"),
              children: children,
            )
            ?.id,
        "a",
      );
      expect(_builder.childSessionFor(part: subtask(), children: children), isNull);
      expect(
        _builder.childSessionFor(
          part: subtask(description: "Deploy"),
          children: children,
        ),
        isNull,
      );
    });
  });
}
