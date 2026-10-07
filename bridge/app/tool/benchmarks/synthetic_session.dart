import "dart:convert";
import "dart:io";

import "package:path/path.dart" as path;
import "package:sesori_bridge/src/api/archived_session_storage.dart";
import "package:sesori_bridge/src/api/attachment_spill_storage.dart";
import "package:sesori_bridge/src/api/database/history/chat_history_database.dart";
import "package:sesori_bridge/src/repositories/chat_history_repository.dart";
import "package:sesori_shared/sesori_shared.dart";

const syntheticSessionId = "ses_benchmark";
const syntheticStorageScope = AttachmentStorageScope(pluginId: "benchmark", backendSessionId: syntheticSessionId);

/// A stored session the size of the largest measured one, in a database
/// opened as the bridge opens it. [close] deletes it.
typedef SyntheticSession = ({ChatHistoryRepository repository, Future<void> Function() close});

/// Stores a synthetic session of 9,790 messages and 836 prompts.
Future<SyntheticSession> openSyntheticSession() async {
  const messageCount = 9790;
  const promptCount = 836;
  final directory = Directory.systemTemp.createTempSync("sesori_history_benchmark");
  // The production opener: a background isolate in WAL mode.
  final database = ChatHistoryDatabase.create(dataDirectory: directory.path);
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
    sessionId: syntheticSessionId,
    storageScope: syntheticStorageScope,
    messages: messages,
    lastImportedAt: null,
    watermark: 1,
    backendActivityAt: 1,
    syncedAt: 1,
  );
  final jsonBytes = messages.fold(0, (sum, message) => sum + utf8.encode(jsonEncode(message.toJson())).length);
  stdout.writeln("Synthetic session: $messageCount messages, ${(jsonBytes / 1e6).toStringAsFixed(1)} MB of JSON.");
  return (
    repository: repository,
    close: () async {
      await database.close();
      directory.deleteSync(recursive: true);
    },
  );
}

/// Runs [operation] 11 times and prints the median and max of the last ten,
/// since the first run warms the JIT and the page cache.
Future<void> timeRuns({required String label, required Future<void> Function() operation}) async {
  final timings = <int>[];
  for (var run = 0; run < 11; run++) {
    final stopwatch = Stopwatch()..start();
    await operation();
    timings.add(stopwatch.elapsedMilliseconds);
  }
  final measured = timings.skip(1).toList()..sort();
  stdout.writeln(
    "$label over ${measured.length} runs: "
    "median ${measured[measured.length ~/ 2]} ms, max ${measured.last} ms (first run ${timings.first} ms).",
  );
}

/// A prompt of the measured median length.
MessageWithParts _prompt({required int index}) => MessageWithParts(
  info: Message.user(
    id: "u$index",
    sessionID: syntheticSessionId,
    agent: null,
    time: MessageTime(created: index, completed: null),
    promptId: null,
  ),
  parts: [
    MessagePart.text(
      id: "u$index-text",
      sessionID: syntheticSessionId,
      messageID: "u$index",
      text: "Fix the build. " * 29,
    ),
  ],
);

/// An agent reply with a finished shell step and some text.
MessageWithParts _reply({required int index}) => MessageWithParts(
  info: Message.assistant(
    id: "a$index",
    sessionID: syntheticSessionId,
    agent: "build",
    modelID: "model",
    providerID: "provider",
    sender: MessageSender.agent,
    time: MessageTime(created: index, completed: index),
  ),
  parts: [
    MessagePart.tool(
      id: "a$index-tool",
      sessionID: syntheticSessionId,
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
    MessagePart.text(id: "a$index-text", sessionID: syntheticSessionId, messageID: "a$index", text: "Done. " * 140),
  ],
);
