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
const _truncated = "99999999-9999-4999-8999-999999999999";

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

  group("rewind point", () {
    // The prompts' uuids and parents in the recorded fixtures.
    const one = "40c0127f-683f-45bd-848d-47bf2dc8e1cd";
    const two = "511f77e8-652e-47db-a1fa-27345ad265f6";
    const three = "2f3824a0-c722-4b54-a5ee-f7127dfd198a";
    const afterOne = "394d3466-c6ea-4f94-850c-a82bb34068df";

    Future<ClaudeRewindPoint> before(String messageId, {required String sessionId}) =>
        transcripts.rewindPointBefore(sessionId: sessionId, messageId: messageId);

    test("is the parent of the edited prompt", () async {
      install(fixture: "linear", sessionId: _linear);

      expect(
        await before(two, sessionId: _linear),
        isA<ClaudeRewindEntry>().having((point) => point.entryUuid, "entry", afterOne),
      );
    });

    test("refuses the first message, which has nothing before it", () async {
      install(fixture: "linear", sessionId: _linear);

      expect(await before(one, sessionId: _linear), _refused(ClaudeRewindRefusal.firstMessage));
    });

    test("refuses a prompt an earlier rewind left behind, and an unknown id", () async {
      install(fixture: "resumed_at_earlier_record", sessionId: _linear);

      expect(await before(two, sessionId: _linear), _refused(ClaudeRewindRefusal.notOnActiveBranch));
      expect(await before(afterOne, sessionId: _linear), _refused(ClaudeRewindRefusal.notOnActiveBranch));
      expect(await before("unknown", sessionId: _linear), _refused(ClaudeRewindRefusal.notOnActiveBranch));
      expect(
        await before(three, sessionId: _linear),
        isA<ClaudeRewindEntry>().having((point) => point.entryUuid, "entry", afterOne),
      );
    });

    test("is found after a compaction, and refused before it or without a transcript or parent", () async {
      final project = Directory(p.join(temp.path, "projects", "-work-fixture-project"))..createSync(recursive: true);
      Map<String, Object?> record(String uuid, String? parent, String type, {Map<String, Object?> extra = const {}}) =>
          {
            "type": type,
            "uuid": uuid,
            "parentUuid": parent,
            "isSidechain": false,
            "sessionId": _compacted,
            if (type == "user" || type == "assistant")
              "message": {
                "role": type,
                "content": [
                  {"type": "text", "text": uuid},
                ],
              },
            ...extra,
          };
      const ids = [
        "00000000-0000-4000-8000-000000000001",
        "00000000-0000-4000-8000-000000000002",
        "00000000-0000-4000-8000-000000000003",
        "00000000-0000-4000-8000-000000000004",
        "00000000-0000-4000-8000-000000000005",
        "00000000-0000-4000-8000-000000000006",
        "00000000-0000-4000-8000-000000000007",
      ];
      final records = [
        record(ids[0], null, "user"),
        record(ids[1], ids[0], "assistant"),
        record(ids[2], ids[1], "user"),
        record(ids[3], ids[2], "assistant"),
        record(ids[4], null, "system", extra: {"subtype": "compact_boundary", "logicalParentUuid": ids[3]}),
        record(ids[5], ids[4], "user", extra: {"isCompactSummary": true}),
        record(ids[6], ids[5], "user"),
      ];
      // A prompt whose parent the file does not hold.
      File(p.join(project.path, "$_truncated.jsonl")).writeAsStringSync(
        "${jsonEncode(record(ids[2], ids[1], "user"))}\n",
      );
      File(p.join(project.path, "$_compacted.jsonl")).writeAsStringSync("${records.map(jsonEncode).join("\n")}\n");

      expect(await before(ids[2], sessionId: _compacted), _refused(ClaudeRewindRefusal.beforeCompaction));
      expect(
        await before(ids[0], sessionId: "88888888-8888-4888-8888-888888888888"),
        _refused(ClaudeRewindRefusal.notOnActiveBranch),
      );
      expect(await before(ids[2], sessionId: _truncated), _refused(ClaudeRewindRefusal.notOnActiveBranch));
      expect(
        await before(ids[6], sessionId: _compacted),
        isA<ClaudeRewindEntry>().having((point) => point.entryUuid, "entry", ids[5]),
      );
    });
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

  group("fork", () {
    const fork = "88888888-8888-4888-8888-888888888888";

    List<Map<String, Object?>> forkRecords() => [
      for (final line in File(p.join(temp.path, "projects", "-work-fixture-project", "$fork.jsonl")).readAsLinesSync())
        jsonDecode(line) as Map<String, Object?>,
    ];

    Future<ClaudeForkResult> forkThrough({required String sessionId, required String messageId}) =>
        transcripts.forkTranscript(sessionId: sessionId, throughMessageId: messageId, forkSessionId: fork);

    test("copies the kept turn, its end record included, under the fork's id and leaves the origin alone", () async {
      final origin = install(fixture: "linear", sessionId: _linear);
      final before = origin.readAsStringSync();

      expect(await forkThrough(sessionId: _linear, messageId: "1794774680780"), isA<ClaudeForkWritten>());

      final records = forkRecords();
      expect(records.last["uuid"], "394d3466-c6ea-4f94-850c-a82bb34068df");
      expect(records.map((record) => record["sessionId"]), everyElement(fork));
      expect(records.map((record) => record["type"]), isNot(contains("last-prompt")));
      expect(origin.readAsStringSync(), before);
      expect(await transcript(sessionId: fork), ["user: Reply with just the word: one", "assistant: one"]);
    });

    test("keeps only the branch the conversation continued on", () async {
      install(fixture: "terminal_rewind", sessionId: _terminalRewind);

      expect(await forkThrough(sessionId: _terminalRewind, messageId: "1794775038258"), isA<ClaudeForkWritten>());

      expect(await transcript(sessionId: fork), [_alpha, "assistant: alpha", _gamma, "assistant: alpha gamma"]);
      expect(forkRecords().last["uuid"], startsWith("746f521e"));
    });

    test("through an earlier turn stops before the next prompt", () async {
      install(fixture: "terminal_rewind", sessionId: _terminalRewind);

      expect(await forkThrough(sessionId: _terminalRewind, messageId: "1794774954690"), isA<ClaudeForkWritten>());

      expect(await transcript(sessionId: fork), [_alpha, "assistant: alpha"]);
      expect(forkRecords().last["uuid"], "718a570d-aa15-40f0-9465-602372ad5fbe");
    });

    test("keeps parallel tool results that hang off sibling records", () async {
      install(fixture: "parallel_tool_calls", sessionId: _parallelTools);

      expect(await forkThrough(sessionId: _parallelTools, messageId: "1794775890337"), isA<ClaudeForkWritten>());

      final messages = await transcript(sessionId: fork);
      expect(messages[1], "assistant: tool Bash completed, tool Bash completed");
      expect(messages.last, "assistant: done");
    });

    test("refuses a message before the latest compaction and allows one after it", () async {
      install(fixture: "compacted", sessionId: _compacted);

      expect(await forkThrough(sessionId: _compacted, messageId: "1794776073924"), _forkRefused(.beforeCompaction));
      expect(File(p.join(temp.path, "projects", "-work-fixture-project", "$fork.jsonl")).existsSync(), isFalse);

      expect(await forkThrough(sessionId: _compacted, messageId: "1794776107383"), isA<ClaudeForkWritten>());
      expect((await transcript(sessionId: fork)).last, "assistant: blue");
    });

    test("refuses a message off the active branch and a missing session", () async {
      install(fixture: "terminal_rewind", sessionId: _terminalRewind);

      expect(
        await forkThrough(sessionId: _terminalRewind, messageId: "1794774978480"),
        _forkRefused(.notOnActiveBranch),
      );
      expect(await forkThrough(sessionId: _terminalRewind, messageId: "unknown"), _forkRefused(.notOnActiveBranch));
      expect(await forkThrough(sessionId: _linear, messageId: "1794774680780"), _forkRefused(.transcriptMissing));
    });

    test("leaves out a later turn the origin is still writing", () async {
      final origin = install(fixture: "linear", sessionId: _linear);
      origin.writeAsStringSync(
        '${jsonEncode({
          "type": "user",
          "uuid": "running-prompt",
          "parentUuid": "d97a6211-bb77-42a4-882b-57b47f7a964a",
          "sessionId": _linear,
          "cwd": "/work/fixture-project",
          "timestamp": "2026-09-01T10:00:00Z",
          "message": {"role": "user", "content": "Reply with just the word: three"},
        })}\n{"type":"assistant","uuid":',
        mode: FileMode.append,
      );

      expect(await forkThrough(sessionId: _linear, messageId: "1794774685645"), isA<ClaudeForkWritten>());

      expect(await transcript(sessionId: fork), [
        "user: Reply with just the word: one",
        "assistant: one",
        "user: Reply with just the word: two",
        "assistant: two",
      ]);
    });

    test("is listed once, keeps the origin's sub-agents with the origin, and deletes only itself", () async {
      final origin = install(fixture: "linear", sessionId: _linear);
      final subagent = File(p.join(p.dirname(origin.path), _linear, "subagents", "agent-a1.jsonl"))
        ..createSync(recursive: true)
        ..writeAsStringSync(
          "${jsonEncode({
            "type": "user",
            "isSidechain": true,
            "agentId": "a1",
            "sessionId": _linear,
            "uuid": "child-user",
            "cwd": "/work/fixture-project",
            "timestamp": "2026-09-01T10:00:01Z",
            "message": {"role": "user", "content": "Reply with hi"},
          })}\n",
        );

      await forkThrough(sessionId: _linear, messageId: "1794774680780");

      final ids = [for (final session in await transcripts.listAllSessions(knownDirectories: const {})) session.id];
      expect(ids.where((id) => id == fork), hasLength(1));
      expect(ids.where((id) => id == "agent-a1"), hasLength(1));
      expect(await transcripts.deleteSession(sessionId: fork), isTrue);
      expect(origin.existsSync(), isTrue);
      expect(subagent.existsSync(), isTrue);
    });
  });
}

Matcher _forkRefused(ClaudeForkRefusal reason) =>
    isA<ClaudeForkUnavailable>().having((result) => result.reason, "reason", reason);

Matcher _refused(ClaudeRewindRefusal reason) =>
    isA<ClaudeRewindUnavailable>().having((point) => point.reason, "reason", reason);

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
