import "package:sesori_bridge/src/repositories/mappers/session_transcript_markdown_builder.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  const builder = SessionTranscriptMarkdownBuilder();
  // 2026-11-15 10:00:00 UTC.
  const created = 1794736800000;

  String build({required List<MessageWithParts> messages, String? title = "Fix the login bug"}) => builder.build(
    session: _session(title: title),
    harnessName: "Claude Code",
    // A local time, so the test shows it is written in UTC.
    exportedAt: DateTime.fromMillisecondsSinceEpoch(created + 2 * 3600 * 1000),
    messages: messages,
  );

  /// The rendered body of one assistant message holding [parts].
  String renderParts({required List<MessagePart> parts}) {
    final markdown = build(messages: [_assistant(parts: parts)]);
    return markdown.substring(markdown.indexOf("\n\n", markdown.indexOf("## 1.")) + 2).trimRight();
  }

  test("renders the header and numbered messages for a whole conversation", () {
    final markdown = build(
      messages: [
        _user(text: "Why does login fail?"),
        _assistant(
          parts: [
            const MessagePart.reasoning(id: "r", sessionID: "ses_1", messageID: "m", text: "secret thoughts"),
            _text(text: "Checking the handler."),
            _tool(
              tool: "bash",
              state: const ToolState(
                status: ToolStatus.completed,
                title: "Run tests",
                shellCommand: "dart test",
                output: "All tests passed!",
                error: null,
              ),
            ),
          ],
        ),
        const MessageWithParts(
          info: Message.error(
            id: "m3",
            sessionID: "ses_1",
            agent: "build",
            modelID: "claude-opus",
            providerID: "anthropic",
            errorName: "APIError",
            errorMessage: "Rate limited",
            time: MessageTime(created: created + 120000, completed: null),
          ),
          parts: [],
        ),
      ],
    );

    expect(markdown, '''
# Fix the login bug

- Harness: Claude Code
- Directory: /repo
- Created: 2026-11-15 10:00:00 UTC
- Exported: 2026-11-15 12:00:00 UTC
- Messages: 3

## 1. User · 2026-11-15 10:00:00 UTC

Why does login fail?

## 2. Assistant (agent: build, model: anthropic/claude-opus) · 2026-11-15 10:01:00 UTC

Checking the handler.

**Tool** `bash` (completed): `dart test`

```
All tests passed!
```

## 3. Error (agent: build, model: anthropic/claude-opus) · 2026-11-15 10:02:00 UTC

**APIError**

```
Rate limited
```
''');
  });

  test("an empty transcript has the header and says it has no messages", () {
    expect(build(messages: const [], title: null), '''
# Untitled session

- Harness: Claude Code
- Directory: /repo
- Created: 2026-11-15 10:00:00 UTC
- Exported: 2026-11-15 12:00:00 UTC
- Messages: 0

_No messages._
''');
  });

  test("an untimed session and message leave their times out", () {
    final markdown = builder.build(
      session: _session(title: "t").copyWith(time: null),
      harnessName: "Codex",
      exportedAt: DateTime.utc(2026, 11, 15),
      messages: [
        const MessageWithParts(
          info: Message.user(
            id: "m",
            sessionID: "ses_1",
            agent: null,
            time: null,
            promptId: null,
            invocation: null,
            handoff: null,
          ),
          parts: [],
        ),
      ],
    );

    expect(markdown, isNot(contains("Created:")));
    expect(markdown, contains("## 1. User\n"));
  });

  test("automation messages are labelled System, and Sesori's own Sesori", () {
    MessageWithParts automated({required String id, required MessageSender sender}) => MessageWithParts(
      info: Message.assistant(
        id: id,
        sessionID: "ses_1",
        agent: null,
        modelID: null,
        providerID: null,
        sender: sender,
        time: null,
      ),
      parts: const [],
    );

    final markdown = build(
      messages: [
        automated(id: "m1", sender: MessageSender.system),
        automated(id: "m2", sender: MessageSender.sesori),
      ],
    );

    expect(markdown, contains("## 1. System\n"));
    expect(markdown, contains("## 2. Sesori\n"));
  });

  test("text is kept verbatim and blank text is left out", () {
    expect(
      renderParts(
        parts: [
          _text(text: "  # Heading\n\n- item `code`  "),
          _text(text: "  \n"),
        ],
      ),
      "  # Heading\n\n- item `code`",
    );
  });

  group("tools", () {
    test("show the title when there is no shell command, then the error and the output", () {
      expect(
        renderParts(
          parts: [
            _tool(
              tool: "edit",
              state: const ToolState(
                status: ToolStatus.error,
                title: "lib/a.dart",
                shellCommand: null,
                output: "partial",
                error: "File not found",
              ),
            ),
          ],
        ),
        "**Tool** `edit` (error): `lib/a.dart`\n\nError:\n```\nFile not found\n```\n\n```\npartial\n```",
      );
    });

    test("without a title or command show the tool and status only", () {
      expect(
        renderParts(
          parts: [
            _tool(
              tool: "read",
              state: const ToolState(
                status: ToolStatus.running,
                title: null,
                shellCommand: " ",
                output: null,
                error: null,
              ),
            ),
          ],
        ),
        "**Tool** `read` (running)",
      );
    });

    test("summaries show their line and attachments", () {
      expect(
        renderParts(
          parts: [
            _tool(
              tool: "screenshot",
              state: const ToolState.summary(
                status: ToolStatus.completed,
                title: "Capture",
                shellCommand: null,
                attachments: [MessageAttachment.metadata(mime: "image/png", filename: "shot.png")],
              ),
            ),
          ],
        ),
        "**Tool** `screenshot` (completed): `Capture`\n\n[Attached file: shot.png (image/png)]",
      );
    });

    test("a multi-line command with backticks stays on one line and its output keeps its fences", () {
      expect(
        renderParts(
          parts: [
            _tool(
              tool: "bash",
              state: const ToolState(
                status: ToolStatus.completed,
                title: null,
                shellCommand: "echo `date`\n  && ls",
                output: "```dart\nmain() {}\n```",
                error: null,
              ),
            ),
          ],
        ),
        "**Tool** `bash` (completed): ``echo `date` && ls``\n\n````\n```dart\nmain() {}\n```\n````",
      );
    });

    test("output longer than the cap is cut with a note of what was left out", () {
      final output = "a" * (SessionTranscriptMarkdownBuilder.maxToolTextLength + 10);

      final rendered = renderParts(
        parts: [
          _tool(
            tool: "bash",
            state: ToolState(
              status: ToolStatus.completed,
              title: null,
              shellCommand: "yes",
              output: output,
              error: null,
            ),
          ),
        ],
      );

      expect(
        rendered,
        "**Tool** `bash` (completed): `yes`\n\n"
        "```\n${"a" * SessionTranscriptMarkdownBuilder.maxToolTextLength}\n```\n"
        "[truncated: 10 characters]",
      );
    });

    test("the cap counts characters, so emoji are kept whole and counted once", () {
      const cap = SessionTranscriptMarkdownBuilder.maxToolTextLength;
      String renderOutput({required String output}) => renderParts(
        parts: [
          _tool(
            tool: "bash",
            state: ToolState(
              status: ToolStatus.completed,
              title: null,
              shellCommand: null,
              output: output,
              error: null,
            ),
          ),
        ],
      );

      // Over the cap in code units, but not in characters.
      final fits = "😀" * cap;
      expect(renderOutput(output: fits), endsWith("```\n$fits\n```"));

      // The emoji's two code units straddle the cap in code units.
      expect(
        renderOutput(output: "${"a" * (cap - 1)}😀😀b"),
        endsWith("```\n${"a" * (cap - 1)}😀\n```\n[truncated: 2 characters]"),
      );
    });
  });

  test("files show their name and type without their bytes", () {
    expect(
      renderParts(
        parts: [
          _file(
            attachment: const MessageAttachment.inlineImage(mime: "image/png", base64: "AAAA", filename: "a.png"),
          ),
          _file(
            attachment: const MessageAttachment.remoteUrl(
              mime: "application/pdf",
              url: "https://example.com/a.pdf",
              filename: null,
            ),
          ),
          _file(
            attachment: const MessageAttachment.storedImage(
              attachmentId: "att",
              bridgeId: "bridge",
              mime: "image/jpeg",
              filename: "b.jpg",
              byteLength: 10,
            ),
          ),
          _file(attachment: const MessageAttachment.unknown()),
        ],
      ),
      "[Attached file: a.png (image/png)]\n\n"
      "[Attached file: unnamed (application/pdf)]\n\n"
      "[Attached file: b.jpg (image/jpeg)]\n\n"
      "[Attached file]",
    );
  });

  test("sub-agents show their description, or their agent when it has none", () {
    MessagePart subtask({required String description}) => MessagePart.subtask(
      id: "s",
      sessionID: "ses_1",
      messageID: "m",
      prompt: "the whole prompt",
      description: description,
      agent: "explore",
      taskState: null,
      childSessionID: "ses_child",
    );

    expect(
      renderParts(
        parts: [
          subtask(description: "Find the handler"),
          subtask(description: ""),
        ],
      ),
      "[Sub-agent: Find the handler]\n\n[Sub-agent: explore]",
    );
  });

  test("finished compactions are marked; running and failed ones are left out", () {
    MessagePart compaction({required CompactionState state}) =>
        MessagePart.compaction(id: "c", sessionID: "ses_1", messageID: "m", state: state);

    expect(
      renderParts(
        parts: [
          compaction(state: const CompactionState.completed(summary: "s", freedTokens: 10, trigger: null)),
          compaction(state: const CompactionState.running(summary: null)),
          compaction(state: const CompactionState.failed(reason: null)),
        ],
      ),
      "[Context compacted]",
    );
  });

  test("reasoning, step markers, snapshots, patches, agent switches and retries are left out", () {
    final markdown = build(
      messages: [
        _assistant(
          parts: const [
            MessagePart.reasoning(id: "1", sessionID: "ses_1", messageID: "m", text: "thinking"),
            MessagePart.stepStart(id: "2", sessionID: "ses_1", messageID: "m"),
            MessagePart.stepFinish(id: "3", sessionID: "ses_1", messageID: "m"),
            MessagePart.snapshot(id: "4", sessionID: "ses_1", messageID: "m"),
            MessagePart.patch(id: "5", sessionID: "ses_1", messageID: "m"),
            MessagePart.agent(id: "6", sessionID: "ses_1", messageID: "m", agentName: "plan"),
            MessagePart.retry(id: "7", sessionID: "ses_1", messageID: "m", attempt: 2, retryError: "overloaded"),
          ],
        ),
      ],
    );

    expect(markdown, endsWith("· 2026-11-15 10:01:00 UTC\n"));
  });
}

Session _session({required String? title}) => Session(
  id: "ses_1",
  projectID: "/repo",
  directory: "/repo",
  parentID: null,
  title: title,
  time: const SessionTime(created: 1794736800000, updated: 1794736800000, archived: null),
  promptDefaults: null,
  branchName: null,
  lastUserActivityAt: null,
  autoContinuation: null,
  approvalOverride: null,
  pinOrder: null,
  scheduledTask: null,
  interruption: null,
  forkedFrom: null,
);

MessageWithParts _user({required String text}) => MessageWithParts(
  info: const Message.user(
    id: "m1",
    sessionID: "ses_1",
    agent: "build",
    time: MessageTime(created: 1794736800000, completed: null),
    promptId: null,
    invocation: null,
    handoff: null,
  ),
  parts: [_text(text: text)],
);

MessageWithParts _assistant({required List<MessagePart> parts}) => MessageWithParts(
  info: const Message.assistant(
    id: "m2",
    sessionID: "ses_1",
    agent: "build",
    modelID: "claude-opus",
    providerID: "anthropic",
    time: MessageTime(created: 1794736860000, completed: 1794736870000),
  ),
  parts: parts,
);

MessagePart _text({required String text}) => MessagePart.text(id: "t", sessionID: "ses_1", messageID: "m", text: text);

MessagePart _tool({required String tool, required ToolState state}) =>
    MessagePart.tool(id: "tool", sessionID: "ses_1", messageID: "m", tool: tool, state: state);

MessagePart _file({required MessageAttachment attachment}) =>
    MessagePart.file(id: "f", sessionID: "ses_1", messageID: "m", attachment: attachment);
