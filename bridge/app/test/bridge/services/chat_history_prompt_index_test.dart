import "dart:convert";
import "dart:io";

import "package:sesori_bridge/src/api/models/archived_session_file_dto.dart";
import "package:sesori_bridge/src/repositories/models/stored_session.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_chat_history.dart";

const _sessionId = "ses_a";

Message _user({required String id, required int? created}) => Message.user(
  id: id,
  sessionID: _sessionId,
  agent: null,
  time: created == null ? null : MessageTime(created: created, completed: null),
  promptId: null,
);

Message _agent({required String id}) => Message.assistant(
  id: id,
  sessionID: _sessionId,
  agent: null,
  modelID: null,
  providerID: null,
  sender: MessageSender.agent,
  time: null,
);

MessagePart _text({required String messageId, required String text}) =>
    MessagePart.text(id: "$messageId-text", sessionID: _sessionId, messageID: messageId, text: text);

/// A prompt, a follow-up sent while a tool ran, a hidden user message, an
/// answer, then a prompt holding only an image the store spills to a file.
Future<void> _captureTranscript({required TestChatHistory history}) async {
  final service = history.service;
  await service.captureMessage(
    sessionId: _sessionId,
    message: _user(id: "u1", created: 10),
  );
  await service.capturePart(
    sessionId: _sessionId,
    part: _text(messageId: "u1", text: "  Fix the build"),
  );
  await service.captureMessage(
    sessionId: _sessionId,
    message: _agent(id: "a1"),
  );
  await service.capturePart(
    sessionId: _sessionId,
    part: const MessagePart.tool(
      id: "a1-tool",
      sessionID: _sessionId,
      messageID: "a1",
      tool: "bash",
      state: ToolState(status: ToolStatus.running, title: null, shellCommand: null, output: null, error: null),
    ),
  );
  await service.captureMessage(
    sessionId: _sessionId,
    message: _user(id: "u2", created: null),
  );
  await service.capturePart(
    sessionId: _sessionId,
    part: _text(messageId: "u2", text: "and the tests"),
  );
  await service.captureMessage(
    sessionId: _sessionId,
    message: _user(id: "hidden", created: 30),
  );
  await service.captureMessage(
    sessionId: _sessionId,
    message: _agent(id: "a2"),
  );
  await service.capturePart(
    sessionId: _sessionId,
    part: _text(messageId: "a2", text: "Done."),
  );
  await service.captureMessage(
    sessionId: _sessionId,
    message: _user(id: "u3", created: 50),
  );
  await service.capturePart(
    sessionId: _sessionId,
    part: MessagePart.file(
      id: "u3-image",
      sessionID: _sessionId,
      messageID: "u3",
      attachment: MessageAttachment.inlineImage(
        mime: "image/png",
        base64: base64Encode(List<int>.filled(16, 7)),
        filename: "shot.png",
      ),
    ),
  );
}

/// Deletes the session's spill files, which the image-only prompt filled, so
/// the index must list that prompt from its stored metadata alone.
void _deleteSpillFiles({required TestChatHistory history}) => Directory(
  history.spillStorage.scopeDirectoryPath(scope: testAttachmentStorageScope(sessionId: _sessionId)),
).deleteSync(recursive: true);

/// The entries without their seqs, which only need to be ascending.
List<Object> _shape({required List<SessionPromptIndexEntry> entries}) => [
  for (final entry in entries)
    switch (entry) {
      SessionPromptIndexOpener(:final messageId, :final number, :final createdAt, :final preview) => (
        "opener",
        messageId,
        number,
        createdAt,
        preview,
      ),
      SessionPromptIndexFollowUp(
        :final messageId,
        :final number,
        :final createdAt,
        :final preview,
        :final openerMessageId,
      ) =>
        ("followUp", messageId, number, createdAt, preview, openerMessageId),
    },
];

const _expected = [
  ("opener", "u1", 1, 10, "Fix the build"),
  ("followUp", "u2", 2, null, "and the tests", "u1"),
  // The hidden user message takes number 3 and gets no entry.
  ("opener", "u3", 4, 50, "shot.png"),
];

void main() {
  test("the store lists every prompt with its kind, number and preview", () async {
    final history = createTestChatHistory();
    await _captureTranscript(history: history);
    _deleteSpillFiles(history: history);

    final entries = await history.service.getPromptIndex(sessionId: _sessionId);

    expect(_shape(entries: entries), _expected);
    final seqs = [for (final entry in entries) entry.seq];
    expect(seqs, orderedEquals([...seqs]..sort()));
  });

  test("an archived session lists its prompts from the audit file", () async {
    final history = createTestChatHistory(storedSessionArchivedAt: 300);
    await _captureTranscript(history: history);
    final stored = await history.service.getPromptIndex(sessionId: _sessionId);
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
    _deleteSpillFiles(history: history);

    final archived = await history.service.getPromptIndex(sessionId: _sessionId);

    expect(_shape(entries: archived), _expected);
    expect(archived, stored, reason: "the audit file keeps the store's seqs");
  });

  test("a session with no stored history lists no prompts", () async {
    final history = createTestChatHistory();

    expect(await history.service.getPromptIndex(sessionId: "unknown"), isEmpty);
  });
}
