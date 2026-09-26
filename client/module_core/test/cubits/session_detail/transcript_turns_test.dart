import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

MessageWithParts _prompt({required String id, int? at}) => MessageWithParts(
  info: Message.user(
    id: id,
    sessionID: "s",
    agent: null,
    time: at == null ? null : MessageTime(created: at, completed: null),
    promptId: null,
  ),
  parts: [MessagePart.text(id: "$id-text", sessionID: "s", messageID: id, text: "Fix the build")],
);

/// A user message the list hides: no text and no known file.
MessageWithParts _hiddenUser({required String id}) => MessageWithParts(
  info: Message.user(id: id, sessionID: "s", agent: null, time: null, promptId: null),
  parts: const [],
);

MessageWithParts _agent({
  required String id,
  required List<MessagePart> parts,
  MessageSender sender = MessageSender.agent,
  MessageTime? time,
}) => MessageWithParts(
  info: Message.assistant(
    id: id,
    sessionID: "s",
    agent: null,
    modelID: null,
    providerID: null,
    sender: sender,
    time: time,
  ),
  parts: parts,
);

MessageWithParts _automation({required String id, required List<MessagePart> parts}) =>
    _agent(id: id, parts: parts, sender: MessageSender.system);

MessageWithParts _error({required String id, String text = "Rate limited"}) => MessageWithParts(
  info: Message.error(
    id: id,
    sessionID: "s",
    agent: null,
    modelID: null,
    providerID: null,
    errorName: "E",
    errorMessage: text,
    time: null,
  ),
  parts: const [],
);

MessagePart _text({String text = "Done."}) => MessagePart.text(id: "text", sessionID: "s", messageID: "m", text: text);
MessagePart _thought() => const MessagePart.reasoning(id: "thought", sessionID: "s", messageID: "m", text: "Hmm");
MessagePart _stepStart() => const MessagePart.stepStart(id: "start", sessionID: "s", messageID: "m");
MessagePart _file() => const MessagePart.file(
  id: "file",
  sessionID: "s",
  messageID: "m",
  attachment: MessageAttachment.metadata(mime: "image/png", filename: null),
);
MessagePart _tool({ToolStatus status = ToolStatus.completed}) => MessagePart.tool(
  id: "tool",
  sessionID: "s",
  messageID: "m",
  tool: "read",
  state: _state(status: status),
);
MessagePart _subAgent({required ToolStatus? status}) => MessagePart.subtask(
  id: "sub",
  sessionID: "s",
  messageID: "m",
  taskState: status == null ? null : _state(status: status),
  childSessionID: null,
);
ToolState _state({required ToolStatus status}) =>
    ToolState(status: status, title: null, shellCommand: null, output: null, error: null);

TranscriptTurns _turns({
  required List<MessageWithParts> messages,
  bool isBusy = false,
  bool hasOlderMessages = false,
}) => const TranscriptTurnBuilder().build(
  messages: messages,
  transcript: const TranscriptBuilder().build(
    messages: messages,
    streamingText: const {},
    children: const [],
    childStatuses: const {},
  ),
  isBusy: isBusy,
  hasOlderMessages: hasOlderMessages,
);

String _kind({required TranscriptTurn turn}) => switch (turn) {
  TranscriptPromptTurn() => "prompt",
  TranscriptPartialTurn() => "partial",
  TranscriptPreamble() => "preamble",
};

/// `prompt(u1,a1)`, `partial(a1)` or `preamble(x1)` per turn, oldest first.
List<String> _shape({required TranscriptTurns turns}) => [
  for (final turn in turns.turns) "${_kind(turn: turn)}(${turn.messageIds.join(",")})",
];

List<String> _outcomes({required TranscriptTurns turns}) => [
  for (final turn in turns.turns)
    switch (turn.summary.outcome) {
      TranscriptTurnRunning() => "running",
      TranscriptTurnFailed(:final errorLine) => "failed: $errorLine",
      TranscriptTurnDone(:final answerLine) => "done: $answerLine",
    },
];

/// Each turn by kind, message positions, summary and duration, so builds over
/// the same messages under other ids compare equal.
List<String> _byPosition({required List<MessageWithParts> messages}) {
  final positionById = {for (final (index, message) in messages.indexed) message.info.id: index};
  final turns = _turns(messages: messages, isBusy: true);
  final outcomes = _outcomes(turns: turns);
  return [
    for (final (index, turn) in turns.turns.indexed)
      [
        "${_kind(turn: turn)}${[for (final id in turn.messageIds) positionById[id]]}",
        "${turn.summary.steps}/${turn.summary.failedSteps}",
        outcomes[index],
        if (turn is TranscriptPromptTurn) "${turn.duration}" else "-",
      ].join(" "),
  ];
}

void main() {
  group("TranscriptTurnBuilder follow-up rule", () {
    test("the first loaded message opens a turn when it is a prompt", () {
      final turns = _turns(
        messages: [
          _prompt(id: "u1"),
          _agent(id: "a1", parts: [_text()]),
        ],
      );

      expect(_shape(turns: turns), ["prompt(u1,a1)"]);
    });

    test("a prompt still waiting for output takes the next messages as follow-ups", () {
      final turns = _turns(
        messages: [
          _prompt(id: "u1"),
          _agent(id: "a1", parts: [_text()]),
          _prompt(id: "u2"),
          _prompt(id: "u3"),
          _agent(id: "a2", parts: [_stepStart()]),
          _prompt(id: "u4"),
        ],
      );

      expect(_shape(turns: turns), ["prompt(u1,a1)", "prompt(u2,u3,a2,u4)"]);
    });

    test("output that ends mid-step keeps the turn open for a follow-up", () {
      final endings = {
        "pending tool": _tool(status: ToolStatus.pending),
        "running tool": _tool(status: ToolStatus.running),
        "completed tool": _tool(),
        "running sub-agent": _subAgent(status: ToolStatus.running),
        "completed sub-agent": _subAgent(status: ToolStatus.completed),
        "sub-agent without a lifecycle": _subAgent(status: null),
      };
      for (final MapEntry(key: ending, value: part) in endings.entries) {
        final turns = _turns(
          messages: [
            _prompt(id: "u1"),
            _agent(id: "a1", parts: [_text(), part]),
            _prompt(id: "u2"),
          ],
        );

        expect(_shape(turns: turns), ["prompt(u1,a1,u2)"], reason: ending);
      }
    });

    test("output that ends in an answer or a stop makes the next message a new prompt", () {
      final endings = {
        "text": _text(),
        "reasoning": _thought(),
        "a file": _file(),
        "a failed tool": _tool(status: ToolStatus.error),
        "a cancelled tool": _tool(status: ToolStatus.cancelled),
        "a tool status this app does not know": _tool(status: ToolStatus.unknown),
        "a failed sub-agent": _subAgent(status: ToolStatus.error),
        "a cancelled sub-agent": _subAgent(status: ToolStatus.cancelled),
      };
      for (final MapEntry(key: ending, value: part) in endings.entries) {
        final turns = _turns(
          messages: [
            _prompt(id: "u1"),
            _agent(id: "a1", parts: [_tool(), part]),
            _prompt(id: "u2"),
          ],
        );

        expect(_shape(turns: turns), ["prompt(u1,a1)", "prompt(u2)"], reason: ending);
      }
      final afterError = _turns(
        messages: [
          _prompt(id: "u1"),
          _agent(id: "a1", parts: [_tool()]),
          _error(id: "e1"),
          _prompt(id: "u2"),
        ],
      );

      expect(_shape(turns: afterError), ["prompt(u1,a1,e1)", "prompt(u2)"], reason: "an error message");
    });

    test("the latest output is the last part that shows any, even in an earlier message", () {
      final turns = _turns(
        messages: [
          _prompt(id: "u1"),
          _agent(
            id: "a1",
            parts: [
              _text(),
              _tool(),
              _text(text: ""),
              _stepStart(),
            ],
          ),
          _agent(id: "a2", parts: [_stepStart()]),
          _prompt(id: "u2"),
        ],
      );

      expect(_shape(turns: turns), ["prompt(u1,a1,a2,u2)"]);
    });

    test("hidden user messages neither join a turn nor open one", () {
      final turns = _turns(
        messages: [
          _hiddenUser(id: "h1"),
          _prompt(id: "u1"),
          _agent(id: "a1", parts: [_text()]),
          _hiddenUser(id: "h2"),
          _agent(id: "a2", parts: [_text()]),
        ],
      );

      expect(_shape(turns: turns), ["prompt(u1,a1,a2)"]);
      expect(turns.turnIndexByMessageId.keys, isNot(contains("h2")));
    });
  });

  group("TranscriptTurnBuilder automation", () {
    test("automation joins the turn it runs in and never opens one", () {
      final turns = _turns(
        messages: [
          _prompt(id: "u1"),
          _agent(id: "a1", parts: [_tool()]),
          _automation(
            id: "x1",
            parts: [_text(text: "Task finished")],
          ),
          _agent(id: "a2", parts: [_text()]),
          _automation(
            id: "x2",
            parts: [_text(text: "A peer says hi")],
          ),
        ],
      );

      expect(_shape(turns: turns), ["prompt(u1,a1,x1,a2,x2)"]);
    });

    test("a user message looks past automation to the agent's latest output", () {
      final afterStep = _turns(
        messages: [
          _prompt(id: "u1"),
          _agent(id: "a1", parts: [_tool()]),
          _automation(id: "x1", parts: [_text()]),
          _prompt(id: "u2"),
        ],
      );
      final afterAnswer = _turns(
        messages: [
          _prompt(id: "u1"),
          _agent(id: "a1", parts: [_text()]),
          _automation(id: "x1", parts: [_tool()]),
          _prompt(id: "u2"),
        ],
      );

      expect(_shape(turns: afterStep), ["prompt(u1,a1,x1,u2)"]);
      expect(_shape(turns: afterAnswer), ["prompt(u1,a1,x1)", "prompt(u2)"]);
    });

    test("automation before the first prompt forms a headless segment", () {
      final messages = [
        _automation(id: "x1", parts: [_text()]),
        _prompt(id: "u1"),
        _agent(id: "a1", parts: [_text()]),
      ];

      expect(_shape(turns: _turns(messages: messages)), ["preamble(x1)", "prompt(u1,a1)"]);
      expect(_shape(turns: _turns(messages: messages, hasOlderMessages: true)), ["partial(x1)", "prompt(u1,a1)"]);
    });
  });

  group("TranscriptTurnBuilder loaded pages", () {
    test("the oldest turn is partial while its prompt is on an unloaded page", () {
      final turns = _turns(
        messages: [
          _agent(id: "a1", parts: [_tool()]),
          _prompt(id: "u2"),
          _agent(id: "a2", parts: [_text()]),
          _prompt(id: "u3"),
        ],
        hasOlderMessages: true,
      );

      expect(_shape(turns: turns), ["partial(a1,u2,a2)", "prompt(u3)"]);
    });

    test("an older page joins the partial turn to its prompt and leaves later turns alone", () {
      final older = [
        _prompt(id: "u1"),
        _agent(id: "a1", parts: [_tool()]),
      ];
      final newer = [
        _agent(id: "a2", parts: [_text()]),
        _prompt(id: "u3"),
        _agent(id: "a3", parts: [_text()]),
      ];

      expect(_shape(turns: _turns(messages: newer, hasOlderMessages: true)), ["partial(a2)", "prompt(u3,a3)"]);
      expect(_shape(turns: _turns(messages: [...older, ...newer])), ["prompt(u1,a1,a2)", "prompt(u3,a3)"]);
    });
  });

  group("TranscriptTurnBuilder summary", () {
    test("counts every grouped step, running ones included, and the failed ones", () {
      final turns = _turns(
        messages: [
          _prompt(id: "u1"),
          _agent(
            id: "a1",
            parts: [
              _thought(),
              _tool(),
              _text(),
              _tool(status: ToolStatus.error),
            ],
          ),
          _automation(id: "x1", parts: [_tool()]),
          _agent(
            id: "a2",
            parts: [_tool(status: ToolStatus.running)],
          ),
        ],
      );
      final summary = turns.turns.single.summary;

      expect((summary.steps, summary.failedSteps), (5, 1));
    });

    test("a turn that ends in text carries that text's first line", () {
      final turns = _turns(
        messages: [
          _prompt(id: "u1"),
          _agent(
            id: "a1",
            parts: [_text(text: "Looking.")],
          ),
          _agent(
            id: "a2",
            parts: [
              _tool(),
              _text(text: "\n  Fixed the build.  \nDetails follow."),
              _text(text: ""),
            ],
          ),
          _automation(
            id: "x1",
            parts: [_text(text: "Task finished")],
          ),
          _prompt(id: "u2"),
          _agent(id: "a3", parts: [_tool()]),
        ],
      );

      expect(_outcomes(turns: turns), ["done: Fixed the build.", "done: null"]);
    });

    test("a finished turn's outcome comes from how it ends, not from earlier narration", () {
      final endings = {
        "a final answer": (
          parts: [
            _text(text: "Checking."),
            _tool(status: ToolStatus.error),
            _text(text: "Fixed it."),
          ],
          outcome: "done: Fixed it.",
        ),
        "narration, then a step": (
          parts: [
            _text(text: "I'll check the logs."),
            _tool(),
          ],
          outcome: "done: null",
        ),
        "a failed last step": (
          parts: [
            _text(text: "Running the tests."),
            _tool(status: ToolStatus.error),
          ],
          outcome: "failed: null",
        ),
        "a failed last sub-agent": (
          parts: [
            _text(),
            _subAgent(status: ToolStatus.error),
          ],
          outcome: "failed: null",
        ),
        "a cancelled last step": (
          parts: [
            _text(),
            _tool(status: ToolStatus.cancelled),
          ],
          outcome: "done: null",
        ),
      };
      for (final MapEntry(key: ending, value: (:parts, :outcome)) in endings.entries) {
        final turns = _turns(
          messages: [
            _prompt(id: "u1"),
            _agent(id: "a1", parts: parts),
          ],
        );

        expect(_outcomes(turns: turns), [outcome], reason: ending);
      }
    });

    test("only the newest turn runs while the session is busy, with its follow-ups", () {
      final messages = [
        _prompt(id: "u1"),
        _agent(id: "a1", parts: [_text()]),
        _prompt(id: "u2"),
        _agent(
          id: "a2",
          parts: [_tool(status: ToolStatus.running)],
        ),
        _prompt(id: "u3"),
      ];
      final busy = _turns(messages: messages, isBusy: true);

      expect(_shape(turns: busy), ["prompt(u1,a1)", "prompt(u2,a2,u3)"]);
      expect(_outcomes(turns: busy), ["done: Done.", "running"]);
      expect(_outcomes(turns: _turns(messages: messages)), ["done: Done.", "done: null"]);
    });

    test("an error message fails the turn with its first line until the agent answers again", () {
      final turns = _turns(
        messages: [
          _prompt(id: "u1"),
          _agent(id: "a1", parts: [_tool()]),
          _error(id: "e1", text: "\nRate limited.\nTry again later."),
          _automation(id: "x1", parts: [_text()]),
          _prompt(id: "u2"),
          _error(id: "e2"),
          _agent(
            id: "a2",
            parts: [_text(text: "Recovered.")],
          ),
        ],
      );

      expect(_outcomes(turns: turns), ["failed: Rate limited.", "done: Recovered."]);
    });

    test("a prompt turn lasts from its prompt to the latest time in it", () {
      final turns = _turns(
        messages: [
          _prompt(id: "u1", at: 1000),
          _agent(id: "a1", parts: [_tool()], time: const MessageTime(created: 2000, completed: 9000)),
          _agent(id: "a2", parts: [_text()], time: const MessageTime(created: 6000, completed: null)),
          _automation(id: "x1", parts: [_text()]),
          _prompt(id: "u2"),
          _agent(id: "a3", parts: [_text()], time: const MessageTime(created: 12000, completed: 13000)),
        ],
      );

      expect(
        [for (final turn in turns.turns.whereType<TranscriptPromptTurn>()) turn.duration],
        [const Duration(seconds: 8), null],
      );
    });
  });

  group("TranscriptTurns", () {
    final messages = [
      _automation(id: "x1", parts: [_text()]),
      _prompt(id: "u1", at: 1000),
      _agent(id: "a1", parts: [_tool()], time: const MessageTime(created: 2000, completed: 3000)),
      _prompt(id: "u2"),
      _agent(id: "a2", parts: [_thought(), _text()]),
      _prompt(id: "u3"),
      _error(id: "e1"),
    ];

    test("maps each rendered message to its turn and finds prompt turns by their opener", () {
      final turns = _turns(messages: messages);

      expect(turns.turnIndexByMessageId, {"x1": 0, "u1": 1, "a1": 1, "u2": 1, "a2": 1, "u3": 2, "e1": 2});
      expect(turns.promptTurnFor(openerMessageId: "u1")?.messageIds, ["u1", "a1", "u2", "a2"]);
      expect(turns.promptTurnFor(openerMessageId: "u2"), isNull, reason: "a follow-up opens no turn");
      expect(turns.promptTurnFor(openerMessageId: "x1"), isNull);
      expect(turns.promptTurnFor(openerMessageId: "missing"), isNull);
    });

    test("the same messages split the same way, whatever their ids", () {
      // A re-import can hand the same messages back under new ids.
      final reimported = [
        for (final (index, message) in messages.indexed)
          message.copyWith(
            info: message.info.copyWith(id: "h$index"),
            parts: [for (final part in message.parts) part.copyWith(id: "h$index-${part.id}", messageID: "h$index")],
          ),
      ];

      expect(_byPosition(messages: messages), [
        "preamble[0] 0/0 done: null -",
        "prompt[1, 2, 3, 4] 2/0 done: Done. 0:00:02.000000",
        "prompt[5, 6] 0/0 running null",
      ]);
      expect(_byPosition(messages: reimported), _byPosition(messages: messages));
    });
  });
}
