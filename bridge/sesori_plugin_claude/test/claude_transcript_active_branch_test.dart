import "dart:convert";
import "dart:io";

import "package:claude_plugin/claude_plugin.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

/// Transcripts recorded live on Claude Code 2.1.322 against a scratch config
/// directory, then scrubbed down to the fields the bridge reads.
const _linear = "11111111-1111-4111-8111-111111111111";
const _terminalRewind = "33333333-3333-4333-8333-333333333333";
const _parallelTools = "55555555-5555-4555-8555-555555555555";
const _rewindToStart = "66666666-6666-4666-8666-666666666666";
const _compacted = "77777777-7777-4777-8777-777777777777";

const _alpha = "user: Reply with just the word: alpha";
const _beta = "user: Reply with just the word: beta";
const _gamma = "user: Reply with just the list of words I asked you to reply with so far, then: gamma";

void main() {
  late Directory temp;
  late ClaudeTranscriptCatalogRepository transcripts;
  const history = ClaudeHistoryMapper(content: ClaudeContentMapper());

  setUp(() {
    temp = Directory.systemTemp.createTempSync("claude-active-branch-");
    transcripts = ClaudeTranscriptCatalogRepository(
      transcriptApi: ClaudeTranscriptApi(environment: {"CLAUDE_CONFIG_DIR": temp.path}),
    );
  });
  tearDown(() => temp.deleteSync(recursive: true));

  File install({required String fixture, required String sessionId}) {
    final project = Directory(p.join(temp.path, "projects", "-work-fixture-project"))..createSync(recursive: true);
    return File("test/fixtures/transcripts/$fixture.jsonl").copySync(p.join(project.path, "$sessionId.jsonl"));
  }

  Future<List<String>> transcript({required String sessionId}) async {
    final messages = history.map(
      sessionId: sessionId,
      agentId: null,
      records: await transcripts.readTranscriptRecordsInIsolate(sessionId: sessionId),
      residentTaskToolUseIds: const {},
      catalogModelId: null,
      commands: const [],
    );
    return [for (final message in messages) _describe(message)];
  }

  test("a linear transcript keeps every record", () async {
    final file = install(fixture: "linear", sessionId: _linear);

    final records = await transcripts.readTranscriptRecordsInIsolate(sessionId: _linear);

    expect(
      records,
      hasLength(ClaudeTranscriptApi(environment: const {}).readTranscript(transcriptPath: file.path).length),
    );
    expect(await transcript(sessionId: _linear), [
      "user: Reply with just the word: one",
      "assistant: one",
      "user: Reply with just the word: two",
      "assistant: two",
    ]);
  });

  test("a terminal rewind shows only the branch the conversation continued on", () async {
    install(fixture: "terminal_rewind", sessionId: _terminalRewind);

    expect(await transcript(sessionId: _terminalRewind), [
      _alpha,
      "assistant: alpha",
      _gamma,
      "assistant: alpha gamma",
    ]);
  });

  test("a rewind to before the first message drops the whole first branch, title included", () async {
    install(fixture: "terminal_rewind_first_message", sessionId: _rewindToStart);

    expect(await transcript(sessionId: _rewindToStart), [_gamma, "assistant: gamma"]);
    final session = await transcripts.findSessionById(sessionId: _rewindToStart);
    expect(session?.title, _gamma.substring("user: ".length));
  });

  test("a session resumed at an earlier record continues from it", () async {
    install(fixture: "resumed_at_earlier_record", sessionId: _linear);

    expect(await transcript(sessionId: _linear), [
      "user: Reply with just the word: one",
      "assistant: one",
      "user: Reply with just the list of words I asked you to reply with so far, then: three",
      "assistant: one three",
    ]);
  });

  test("parallel tool calls keep both calls, though their results hang off different records", () async {
    install(fixture: "parallel_tool_calls", sessionId: _parallelTools);

    final messages = await transcript(sessionId: _parallelTools);

    expect(messages, hasLength(3));
    expect(messages[1], "assistant: tool Bash completed, tool Bash completed");
    expect(messages[2], "assistant: done");
  });

  test("a compacted transcript keeps the turns before the compaction", () async {
    install(fixture: "compacted", sessionId: _compacted);

    final messages = await transcript(sessionId: _compacted);

    expect(messages.first, "user: Reply with just the word: red");
    expect(messages[1], "assistant: red");
    expect(messages.sublist(messages.length - 2), ["user: Reply with just the word: blue", "assistant: blue"]);
  });

  test("a rewind to just before a compaction drops the compaction and what followed it", () async {
    final file = install(fixture: "compacted", sessionId: _compacted);
    final beforeCompaction = file
        .readAsLinesSync()
        .map((line) => jsonDecode(line) as Map<String, Object?>)
        .firstWhere((record) => record["subtype"] == "compact_boundary")["logicalParentUuid"];
    file.writeAsStringSync(
      "${jsonEncode({"type": "last-prompt", "leafUuid": beforeCompaction, "sessionId": _compacted})}\n",
      mode: FileMode.append,
    );

    final messages = await transcript(sessionId: _compacted);

    expect(messages.last, "assistant: red");
    expect(messages, isNot(contains("user: Reply with just the word: blue")));
  });

  group("leaf", () {
    test("is the newest record without a last-prompt record", () async {
      final file = install(fixture: "terminal_rewind", sessionId: _terminalRewind);
      final lines = file.readAsLinesSync().where((line) => !line.contains('"type":"last-prompt"'));
      file.writeAsStringSync("${lines.join("\n")}\n");

      expect(await transcript(sessionId: _terminalRewind), [
        _alpha,
        "assistant: alpha",
        _gamma,
        "assistant: alpha gamma",
      ]);
    });

    test("is the record a later last-prompt names", () async {
      final file = install(fixture: "terminal_rewind", sessionId: _terminalRewind);
      final betaTurnEnd = file
          .readAsLinesSync()
          .map((line) => jsonDecode(line) as Map<String, Object?>)
          .where((record) => record["subtype"] == "turn_duration")
          .elementAt(1)["uuid"];
      file.writeAsStringSync(
        "${jsonEncode({"type": "last-prompt", "leafUuid": betaTurnEnd, "sessionId": _terminalRewind})}\n",
        mode: FileMode.append,
      );

      expect(await transcript(sessionId: _terminalRewind), [_alpha, "assistant: alpha", _beta, "assistant: beta"]);
    });
  });
}

/// One line per message: its role and its text, or its tools' states.
String _describe(PluginMessageWithParts message) {
  final role = switch (message.info) {
    PluginMessageUser() => "user",
    PluginMessageAssistant() => "assistant",
    PluginMessageError() => "error",
  };
  final parts = [
    for (final part in message.parts)
      if (part case PluginMessagePartText(:final text))
        text.trim()
      else if (part case PluginMessagePartTool(:final tool, :final state))
        "tool $tool ${state.status.name}",
  ];
  return "$role: ${parts.join(", ")}";
}
