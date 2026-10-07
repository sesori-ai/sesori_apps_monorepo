import "dart:io";

import "synthetic_session.dart";

/// Times the prompt index over a synthetic session the size of the largest
/// measured one: 9,790 messages and 836 prompts, in a database opened as the
/// bridge opens it.
/// The plan's budget is about 300 ms.
/// Run from bridge/app: dart run tool/benchmarks/prompt_index_benchmark.dart
Future<void> main() async {
  final session = await openSyntheticSession();
  try {
    var entries = 0;
    await timeRuns(
      label: "Index",
      operation: () async {
        entries = (await session.repository.getPromptIndex(sessionId: syntheticSessionId)).length;
      },
    );
    stdout.writeln("The index lists $entries prompts.");
  } finally {
    await session.close();
  }
}
