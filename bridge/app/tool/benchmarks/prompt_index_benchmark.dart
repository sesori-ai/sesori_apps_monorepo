import "dart:convert";
import "dart:io";

import "package:drift/native.dart";
import "package:path/path.dart" as path;
import "package:sesori_bridge/src/api/archived_session_storage.dart";
import "package:sesori_bridge/src/api/attachment_spill_storage.dart";
import "package:sesori_bridge/src/api/database/history/chat_history_database.dart";
import "package:sesori_bridge/src/repositories/chat_history_repository.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Times the prompt index over a synthetic session the size of the largest
/// measured one: 9,790 messages and 836 prompts, in a file-backed database.
/// The plan's budget is about 300 ms.
/// Run from bridge/app: dart run tool/benchmarks/prompt_index_benchmark.dart
Future<void> main() async {
  const messageCount = 9790;
  const promptCount = 836;
  const sessionId = "ses_benchmark";
  final directory = Directory.systemTemp.createTempSync("sesori_prompt_index_benchmark");
  final database = ChatHistoryDatabase(NativeDatabase(File(path.join(directory.path, "history.db"))));
  try {
    final repository = ChatHistoryRepository(
      chatHistoryDao: database.chatHistoryDao,
      attachmentSpillStorage: AttachmentSpillStorage(directoryPath: path.join(directory.path, "attachments")),
      archivedSessionStorage: ArchivedSessionStorage(directoryPath: path.join(directory.path, "archive")),
    );
    final promptIndexes = {for (var prompt = 0; prompt < promptCount; prompt++) prompt * messageCount ~/ promptCount};
    final messages = [
      for (var index = 0; index < messageCount; index++)
        promptIndexes.contains(index) ? _prompt(index: index) : _reply(index: index),
    ];
    await repository.replaceSessionMessages(
      sessionId: sessionId,
      storageScope: AttachmentStorageScope(pluginId: "benchmark", backendSessionId: sessionId),
      messages: messages,
      lastImportedAt: null,
      watermark: 1,
      backendActivityAt: 1,
      syncedAt: 1,
    );
    final jsonBytes = messages.fold(0, (sum, message) => sum + utf8.encode(jsonEncode(message.toJson())).length);
    stdout.writeln("Synthetic session: $messageCount messages, ${(jsonBytes / 1e6).toStringAsFixed(1)} MB of JSON.");

    final timings = <int>[];
    var entries = 0;
    for (var run = 0; run < 11; run++) {
      final stopwatch = Stopwatch()..start();
      entries = (await repository.getPromptIndex(sessionId: sessionId)).length;
      timings.add(stopwatch.elapsedMilliseconds);
    }
    // The first run warms the JIT and the page cache.
    final measured = timings.skip(1).toList()..sort();
    stdout.writeln(
      "Index of $entries prompts over ${measured.length} runs: "
      "median ${measured[measured.length ~/ 2]} ms, max ${measured.last} ms (first run ${timings.first} ms).",
    );
  } finally {
    await database.close();
    directory.deleteSync(recursive: true);
  }
}

/// A prompt of the measured median length.
MessageWithParts _prompt({required int index}) => MessageWithParts(
  info: Message.user(
    id: "u$index",
    sessionID: "ses_benchmark",
    agent: null,
    time: MessageTime(created: index, completed: null),
    promptId: null,
  ),
  parts: [
    MessagePart.text(
      id: "u$index-text",
      sessionID: "ses_benchmark",
      messageID: "u$index",
      text: "Fix the build. " * 29,
    ),
  ],
);

/// An agent reply with a finished shell step and some text.
MessageWithParts _reply({required int index}) => MessageWithParts(
  info: Message.assistant(
    id: "a$index",
    sessionID: "ses_benchmark",
    agent: "build",
    modelID: "model",
    providerID: "provider",
    sender: MessageSender.agent,
    time: MessageTime(created: index, completed: index),
  ),
  parts: [
    MessagePart.tool(
      id: "a$index-tool",
      sessionID: "ses_benchmark",
      messageID: "a$index",
      tool: "bash",
      state: ToolState(
        status: ToolStatus.completed,
        title: "dart test",
        shellCommand: "dart test",
        output: "00:01 +12: All tests passed!\n" * 16,
        error: null,
      ),
    ),
    MessagePart.text(id: "a$index-text", sessionID: "ses_benchmark", messageID: "a$index", text: "Done. " * 140),
  ],
);
