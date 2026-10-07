import "dart:io";

import "package:sesori_shared/sesori_shared.dart";

import "synthetic_session.dart";

/// Times prompt search over a synthetic session the size of the largest
/// measured one: 9,790 messages and 836 prompts, in a database opened as the
/// bridge opens it. One query matches every prompt and one matches none.
/// Run from bridge/app: dart run tool/benchmarks/prompt_search_benchmark.dart
Future<void> main() async {
  final session = await openSyntheticSession();
  try {
    for (final query in ["build", "no such words"]) {
      final pattern = promptSearchPattern(query: query) ?? (throw StateError("blank query"));
      var matches = 0;
      await timeRuns(
        label: 'Search "$query"',
        operation: () async {
          matches = (await session.repository.searchPrompts(sessionId: syntheticSessionId, pattern: pattern)).length;
        },
      );
      stdout.writeln('"$query" matches $matches prompts.');
      final expected = query == "build" ? 836 : 0;
      if (matches != expected) throw StateError('"$query" matched $matches prompts, expected $expected.');
    }
  } finally {
    await session.close();
  }
}
