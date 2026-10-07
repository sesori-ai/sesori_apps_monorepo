import "package:sesori_bridge/src/api/models/archived_session_file_dto.dart";
import "package:sesori_bridge/src/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/repositories/models/tool_output_lookup.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_chat_history.dart";

const _sessionId = "ses_a";

const _finishedShell = MessagePart.tool(
  id: "shell",
  sessionID: _sessionId,
  messageID: "a1",
  tool: "bash",
  state: ToolState(status: ToolStatus.completed, title: null, shellCommand: "ls", output: "a.txt", error: "warn"),
);

const _runningShell = MessagePart.tool(
  id: "running",
  sessionID: _sessionId,
  messageID: "a1",
  tool: "bash",
  state: ToolState(status: ToolStatus.running, title: null, shellCommand: "make", output: "partial", error: null),
);

const _summary = MessagePart.tool(
  id: "shell",
  sessionID: _sessionId,
  messageID: "a1",
  tool: "bash",
  state: ToolState.summary(status: ToolStatus.completed, title: null, shellCommand: "ls", attachments: []),
);

Future<void> _captureTranscript({required TestChatHistory history}) async {
  final service = history.service;
  await service.captureMessage(
    sessionId: _sessionId,
    message: const Message.assistant(
      id: "a1",
      sessionID: _sessionId,
      agent: null,
      modelID: null,
      providerID: null,
      sender: MessageSender.agent,
      time: null,
    ),
  );
  for (final part in const [
    _finishedShell,
    _runningShell,
    MessagePart.text(id: "text", sessionID: _sessionId, messageID: "a1", text: "Done."),
  ]) {
    await service.capturePart(sessionId: _sessionId, part: part);
  }
}

Future<List<MessagePart>> _pageParts({
  required TestChatHistory history,
  required ToolOutputDelivery toolOutputDelivery,
}) async {
  final page = await history.service.getSessionMessages(
    sessionId: _sessionId,
    limit: 50,
    toolOutputDelivery: toolOutputDelivery,
    storedOnly: true,
  );
  return page.messages.single.parts;
}

Future<ToolOutputLookup> _lookup({required TestChatHistory history, required String partId}) =>
    history.service.getToolOutput(sessionId: _sessionId, messageId: "a1", partId: partId);

Future<void> _archive({required TestChatHistory history}) async {
  await history.repository.exportSession(
    session: const StoredSession(
      id: _sessionId,
      backendSessionId: _sessionId,
      pluginId: "opencode",
      projectId: "project-1",
      parentSessionId: null,
      directory: "/tmp/project-1",
      worktreePath: null,
      branchName: null,
      isDedicated: false,
      archivedAt: 300,
      baseBranch: null,
      baseCommit: null,
    ),
    title: null,
    createdAt: 1,
    updatedAt: 2,
    archivedAt: 300,
    completeness: ArchivedSessionCompleteness.complete,
  );
  await history.service.purgeSessionHistory(sessionId: _sessionId);
}

Matcher _found({required String? output, required String? error}) => isA<ToolOutputFound>()
    .having((found) => found.output, "output", output)
    .having((found) => found.error, "error", error);

void main() {
  test("a page that asks for onExpand summarizes finished tools only", () async {
    final history = createTestChatHistory();
    await _captureTranscript(history: history);

    final parts = await _pageParts(history: history, toolOutputDelivery: ToolOutputDelivery.onExpand);

    expect(parts.take(2), [_summary, _runningShell]);
  });

  test("a page that asks for inline output keeps full tools", () async {
    final history = createTestChatHistory();
    await _captureTranscript(history: history);

    final parts = await _pageParts(history: history, toolOutputDelivery: ToolOutputDelivery.inline);

    expect(parts.take(2), [_finishedShell, _runningShell]);
  });

  test("the store answers a summarized tool's output and error", () async {
    final history = createTestChatHistory();
    await _captureTranscript(history: history);

    expect(await _lookup(history: history, partId: "shell"), _found(output: "a.txt", error: "warn"));
  });

  test("a missing part, a non-tool part and an unknown session are missing", () async {
    final history = createTestChatHistory();
    await _captureTranscript(history: history);

    expect(await _lookup(history: history, partId: "gone"), isA<ToolOutputMissing>());
    expect(await _lookup(history: history, partId: "text"), isA<ToolOutputMissing>());
    expect(
      await history.service.getToolOutput(sessionId: "unknown", messageId: "a1", partId: "shell"),
      isA<ToolOutputMissing>(),
    );
  });

  test("an archived session summarizes and answers from its audit file", () async {
    final history = createTestChatHistory(storedSessionArchivedAt: 300);
    await _captureTranscript(history: history);
    await _archive(history: history);

    final parts = await _pageParts(
      history: history,
      toolOutputDelivery: ToolOutputDelivery.onExpand,
    );

    expect(parts.first, _summary);
    expect(await _lookup(history: history, partId: "shell"), _found(output: "a.txt", error: "warn"));
    expect(await _lookup(history: history, partId: "text"), isA<ToolOutputMissing>());
  });
}
