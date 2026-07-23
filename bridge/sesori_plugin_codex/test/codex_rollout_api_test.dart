import "dart:async";
import "dart:convert";
import "dart:io";

import "package:codex_plugin/codex_plugin.dart";
import "package:codex_plugin/src/api/models/codex_rollout_dto.dart";
import "package:codex_plugin/src/repositories/codex_catalog_repository.dart";
import "package:codex_plugin/src/repositories/codex_message_repository.dart";
import "package:codex_plugin/src/repositories/models/codex_session_record.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "support/codex_plugin_test_factory.dart";

void main() {
  group("Codex rollout layers", () {
    late Directory codexHome;
    late CodexRolloutApi rolloutApi;
    late CodexCatalogRepository catalogRepository;
    late CodexMessageRepository messageRepository;

    setUp(() {
      codexHome = Directory.systemTemp.createTempSync("codex-home-");
      rolloutApi = CodexRolloutApi(
        environment: {"CODEX_HOME": codexHome.path},
      );
      catalogRepository = CodexCatalogRepository(rolloutApi: rolloutApi);
      messageRepository = CodexMessageRepository(rolloutApi: rolloutApi);
    });

    tearDown(() {
      try {
        codexHome.deleteSync(recursive: true);
      } catch (_) {
        // Best-effort cleanup.
      }
    });

    test("readIndex returns empty when session_index.jsonl is missing", () {
      expect(rolloutApi.readSessionIndex(), isEmpty);
    });

    test("readIndex decodes JSON lines and skips malformed JSON", () {
      final index = File(p.join(codexHome.path, "session_index.jsonl"))
        ..writeAsStringSync(
          [
            jsonEncode({
              "id": "019a0000-1111-2222-3333-aaaaaaaaaaaa",
              "thread_name": "First thread",
              "updated_at": "2026-04-17T10:00:00Z",
            }),
            "not-json-at-all",
            jsonEncode({
              "id": "019a0000-1111-2222-3333-bbbbbbbbbbbb",
              "thread_name": "Second thread",
              "updated_at": "2026-04-17T11:30:00Z",
            }),
            jsonEncode({"thread_name": "missing-id"}),
            "",
          ].join("\n"),
        );

      final entries = rolloutApi.readSessionIndex();
      expect(entries, hasLength(3));
      expect(entries[0].id, equals("019a0000-1111-2222-3333-aaaaaaaaaaaa"));
      expect(entries[0].threadName, equals("First thread"));
      expect(entries[0].updatedAt, equals("2026-04-17T10:00:00Z"));
      expect(entries[1].threadName, equals("Second thread"));
      expect(entries[2].id, isNull);
      expect(index.existsSync(), isTrue);
    });

    test("readIndex warns for malformed non-final rows", () {
      File(p.join(codexHome.path, "session_index.jsonl")).writeAsStringSync(
        '${jsonEncode({"id": "valid"})}\nnot-json-secret-index-content\n{"partial"',
      );

      final output = _captureWarnings(rolloutApi.readSessionIndex);

      expect(output, contains("malformed session index record"));
      expect("malformed session index record".allMatches(output), hasLength(1));
      expect(output, isNot(contains("secret-index-content")));
    });

    test("listRolloutFiles walks the sessions tree and extracts UUIDs", () {
      _writeRollout(
        codexHome,
        path: "sessions/2026/04/17/rollout-2026-04-17T10-00-00-019a0000-1111-2222-3333-aaaaaaaaaaaa.jsonl",
        sessionId: "019a0000-1111-2222-3333-aaaaaaaaaaaa",
        cwd: "/repo/app",
      );
      _writeRollout(
        codexHome,
        path: "sessions/2026/04/18/rollout-2026-04-18T08-30-00-019a0000-1111-2222-3333-bbbbbbbbbbbb.jsonl",
        sessionId: "019a0000-1111-2222-3333-bbbbbbbbbbbb",
        cwd: "/repo/web",
      );

      final files = rolloutApi.listRolloutPaths();
      expect(files, hasLength(2));
      expect(
        files.map(p.basename).toSet(),
        containsAll([
          contains("019a0000-1111-2222-3333-aaaaaaaaaaaa"),
          contains("019a0000-1111-2222-3333-bbbbbbbbbbbb"),
        ]),
      );
    });

    test("readMeta returns CWD and timestamp from the session_meta header", () {
      final path = _writeRollout(
        codexHome,
        path: "sessions/2026/04/17/rollout-2026-04-17T10-00-00-019a0000-1111-2222-3333-aaaaaaaaaaaa.jsonl",
        sessionId: "019a0000-1111-2222-3333-aaaaaaaaaaaa",
        cwd: "/repo/app",
        timestamp: "2026-04-17T10:00:00Z",
        cliVersion: "0.121.0",
      );
      final meta = rolloutApi.readHeader(rolloutPath: path).first.payload;
      expect(meta?.id, equals("019a0000-1111-2222-3333-aaaaaaaaaaaa"));
      expect(meta?.cwd, equals("/repo/app"));
      expect(meta?.timestamp, equals("2026-04-17T10:00:00Z"));
      expect(meta?.cliVersion, equals("0.121.0"));
    });

    test("readHeader does not read beyond its bounded scan window", () {
      final path = p.join(codexHome.path, "bounded-header.jsonl");
      final header = jsonEncode({
        "type": "session_meta",
        "payload": {"id": "session-id", "cwd": "/repo/app"},
      });
      File(path).writeAsBytesSync([
        ...utf8.encode("$header\n${List.filled(31, "{}").join("\n")}\n"),
        0xFF,
      ]);

      final lines = rolloutApi.readHeader(rolloutPath: path);

      expect(lines.first.payload?.id, "session-id");
    });

    test("readTranscript warns for malformed non-final rows", () {
      final path = p.join(codexHome.path, "malformed-transcript.jsonl");
      File(path).writeAsStringSync('{}\nnot-json-secret-source-content\n{"partial"');

      final output = _captureWarnings(
        () => rolloutApi.readTranscript(rolloutPath: path),
        level: LogLevel.verbose,
      );

      expect(output, contains("malformed rollout transcript record"));
      expect("malformed rollout transcript record".allMatches(output), hasLength(1));
      expect(output, isNot(contains("secret-source-content")));
    });

    test("current structured rollout records are not reported as malformed", () {
      final path = _writeRollout(
        codexHome,
        path: "sessions/2026/07/22/rollout-current.jsonl",
        sessionId: "019a0000-1111-2222-3333-aaaaaaaaaaaa",
        cwd: "/repo/app",
        cliVersion: "0.144.1",
        extraLines: [
          jsonEncode({
            "type": "response_item",
            "payload": {
              "type": "custom_tool_call_output",
              "call_id": "call-1",
              "output": [
                {"type": "input_text", "text": "command output"},
              ],
            },
          }),
          jsonEncode({
            "type": "response_item",
            "payload": {
              "type": "reasoning",
              "id": "reasoning-1",
              "summary": [
                {"type": "summary_text", "text": "Checking the result"},
              ],
            },
          }),
        ],
      );

      late List<CodexRolloutLineDto> header;
      late List<CodexRolloutLineDto> transcript;
      final output = _captureWarnings(() {
        header = rolloutApi.readHeader(rolloutPath: path);
        transcript = rolloutApi.readTranscript(rolloutPath: path);
      }, level: LogLevel.verbose);

      expect(output, isNot(contains("malformed rollout")));
      expect(header, hasLength(3));
      expect(transcript, hasLength(3));
      expect(
        transcript[1].payload?.type,
        CodexRolloutPayloadType.customToolCallOutput,
      );
      expect(
        transcript[2].payload?.type,
        CodexRolloutPayloadType.reasoning,
      );
    });

    test("turn_context scalar summary is not reported as malformed", () {
      final path = _writeRollout(
        codexHome,
        path: "sessions/2026/07/22/rollout-turn-context-summary.jsonl",
        sessionId: "019a0000-1111-2222-3333-aaaaaaaaaaaa",
        cwd: "/repo/app",
        cliVersion: "0.144.1",
        extraLines: [
          jsonEncode({
            "type": "turn_context",
            "payload": {
              "model": "gpt-5.4",
              "summary": "previous-turn context summary",
            },
          }),
        ],
      );

      late List<CodexRolloutLineDto> transcript;
      final output = _captureWarnings(() {
        transcript = rolloutApi.readTranscript(rolloutPath: path);
      }, level: LogLevel.verbose);

      expect(output, isNot(contains("malformed rollout content list")));
      expect(transcript.last.type, CodexRolloutLineType.turnContext);
      expect(transcript.last.payload?.model, "gpt-5.4");
      expect(transcript.last.payload?.summary, isNull);
    });

    test("response_item scalar summary remains observable as malformed", () {
      final path = _writeRollout(
        codexHome,
        path: "sessions/2026/07/22/rollout-response-summary.jsonl",
        sessionId: "019a0000-1111-2222-3333-aaaaaaaaaaaa",
        cwd: "/repo/app",
        cliVersion: "0.144.1",
        extraLines: [
          jsonEncode({
            "type": "response_item",
            "payload": {
              "type": "reasoning",
              "summary": "schema-drifted response summary",
            },
          }),
        ],
      );

      late List<CodexRolloutLineDto> transcript;
      final output = _captureWarnings(() {
        transcript = rolloutApi.readTranscript(rolloutPath: path);
      }, level: LogLevel.verbose);

      expect(
        "malformed rollout content list".allMatches(output),
        hasLength(1),
      );
      expect(transcript.last.type, CodexRolloutLineType.responseItem);
      expect(transcript.last.payload?.summary, isEmpty);
    });

    test("listSessions joins index + rollout header and sorts by updatedAt", () {
      _writeRollout(
        codexHome,
        path: "sessions/2026/04/17/rollout-2026-04-17T10-00-00-019a0000-1111-2222-3333-aaaaaaaaaaaa.jsonl",
        sessionId: "019a0000-1111-2222-3333-aaaaaaaaaaaa",
        cwd: "/repo/app",
        timestamp: "2026-04-17T10:00:00Z",
      );
      _writeRollout(
        codexHome,
        path: "sessions/2026/04/18/rollout-2026-04-18T08-30-00-019a0000-1111-2222-3333-bbbbbbbbbbbb.jsonl",
        sessionId: "019a0000-1111-2222-3333-bbbbbbbbbbbb",
        cwd: "/repo/app",
        timestamp: "2026-04-18T08:30:00Z",
      );
      File(p.join(codexHome.path, "session_index.jsonl")).writeAsStringSync(
        [
          jsonEncode({
            "id": "019a0000-1111-2222-3333-aaaaaaaaaaaa",
            "thread_name": "Older",
            "updated_at": "2026-04-17T10:05:00Z",
          }),
          jsonEncode({
            "id": "019a0000-1111-2222-3333-bbbbbbbbbbbb",
            "thread_name": "Newer",
            "updated_at": "2026-04-18T09:00:00Z",
          }),
        ].join("\n"),
      );

      final records = catalogRepository.listSessionRecords();
      expect(records, hasLength(2));
      // Sorted newest-first.
      expect(records[0].threadName, equals("Newer"));
      expect(records[1].threadName, equals("Older"));
      expect(records[0].cwd, equals("/repo/app"));
    });

    test("catalog rejects a rollout whose header id mismatches its filename", () {
      _writeRollout(
        codexHome,
        path: "sessions/2026/04/17/rollout-2026-04-17T10-00-00-019a0000-1111-2222-3333-aaaaaaaaaaaa.jsonl",
        sessionId: "019a0000-1111-2222-3333-bbbbbbbbbbbb",
        cwd: "/repo/wrong",
      );

      late final List<CodexSessionRecord> records;
      final output = _captureWarnings(() {
        records = catalogRepository.listSessionRecords();
      });

      expect(records, isEmpty);
      expect(output, contains("rollout session id mismatch"));
    });

    test("catalog keeps leading metadata when a fork contains its parent header", () {
      const childId = "019a0000-1111-2222-3333-aaaaaaaaaaaa";
      const parentId = "019a0000-1111-2222-3333-bbbbbbbbbbbb";
      _writeRollout(
        codexHome,
        path: "sessions/2026/04/17/rollout-2026-04-17T10-00-00-$childId.jsonl",
        sessionId: childId,
        cwd: "/repo/child",
        extraLines: [
          jsonEncode({
            "type": "session_meta",
            "payload": {
              "id": parentId,
              "cwd": "/repo/parent",
              "timestamp": "2026-04-17T09:00:00Z",
            },
          }),
        ],
      );

      late final List<CodexSessionRecord> records;
      final output = _captureWarnings(() {
        records = catalogRepository.listSessionRecords();
      });

      expect(output, isNot(contains("rollout session id mismatch")));
      expect(records, hasLength(1));
      expect(records.single.id, childId);
      expect(records.single.cwd, "/repo/child");
    });

    test("catalog isolate enumeration keeps the main isolate responsive", () async {
      const sessionId = "019a0000-1111-2222-3333-aaaaaaaaaaaa";
      _writeRollout(
        codexHome,
        path: "sessions/2026/04/17/rollout-2026-04-17T10-00-00-$sessionId.jsonl",
        sessionId: sessionId,
        cwd: "/repo/app",
        extraLines: [
          jsonEncode({
            "type": "response_item",
            "payload": {
              "role": "assistant",
              "content": [
                {"type": "output_text", "text": "x" * (8 * 1024 * 1024)},
              ],
            },
          }),
        ],
      );

      var complete = false;
      var heartbeatCount = 0;
      void scheduleHeartbeat() {
        Timer.run(() {
          if (complete) return;
          heartbeatCount += 1;
          scheduleHeartbeat();
        });
      }

      scheduleHeartbeat();
      late final List<CodexSessionRecord> records;
      try {
        records = await catalogRepository.listSessionRecordsInIsolate();
      } finally {
        complete = true;
      }

      expect(records.map((record) => record.id), [sessionId]);
      expect(heartbeatCount, greaterThan(1));
    });

    test("readMessages maps user/assistant text turns into PluginMessages", () {
      final path = _writeRollout(
        codexHome,
        path: "sessions/2026/04/17/rollout-2026-04-17T10-00-00-019a0000-1111-2222-3333-aaaaaaaaaaaa.jsonl",
        sessionId: "019a0000-1111-2222-3333-aaaaaaaaaaaa",
        cwd: "/repo/app",
        extraLines: [
          jsonEncode({
            "type": "response_item",
            "payload": {
              "role": "user",
              "content": [
                {"type": "input_text", "text": "hello, codex"},
              ],
            },
          }),
          jsonEncode({
            "type": "response_item",
            "payload": {
              "role": "assistant",
              "content": [
                {"type": "output_text", "text": "hello back!"},
              ],
            },
          }),
          // Should be skipped: not a response_item.
          jsonEncode({
            "type": "event_msg",
            "payload": {"type": "token_count", "count": 10},
          }),
        ],
      );

      final messages = messageRepository.readMessages(
        rolloutPath: path,
        sessionId: "019a0000-1111-2222-3333-aaaaaaaaaaaa",
      );
      expect(messages, hasLength(2));
      expect(messages[0].info, isA<PluginMessageUser>());
      expect(messages[0].parts.first.text, equals("hello, codex"));
      expect(messages[1].info, isA<PluginMessageAssistant>());
      expect(messages[1].parts.first.text, equals("hello back!"));
      expect(messages[0].info.sessionID, equals("019a0000-1111-2222-3333-aaaaaaaaaaaa"));
    });

    test("readMessages surfaces transcript read failures", () {
      const sessionId = "019a0000-1111-2222-3333-aaaaaaaaaaaa";
      final path = p.join(codexHome.path, "broken-rollout.jsonl");
      File(path).writeAsBytesSync([0xFF]);

      expect(
        () => messageRepository.readMessages(
          rolloutPath: path,
          sessionId: sessionId,
        ),
        throwsA(
          isA<PluginOperationException>()
              .having(
                (error) => error.operation,
                "operation",
                "read Codex session transcript",
              )
              .having(
                (error) => error.message,
                "message",
                "history read for $sessionId failed",
              )
              .having((error) => error.cause, "cause", isA<FileSystemException>()),
        ),
      );
    });

    test("readMessages surfaces tool calls (function_call + output) as tool parts", () {
      final path = _writeRollout(
        codexHome,
        path: "sessions/2026/04/17/rollout-2026-04-17T11-00-00-019a0000-1111-2222-3333-bbbbbbbbbbbb.jsonl",
        sessionId: "019a0000-1111-2222-3333-bbbbbbbbbbbb",
        cwd: "/repo/app",
        extraLines: [
          jsonEncode({
            "type": "response_item",
            "payload": {
              "type": "function_call",
              "name": "exec_command",
              "arguments": jsonEncode({"cmd": "ls -la"}),
              "call_id": "c1",
            },
          }),
          jsonEncode({
            "type": "response_item",
            "payload": {
              "type": "function_call_output",
              "call_id": "c1",
              "output": "total 0\nfoo.dart",
            },
          }),
          jsonEncode({
            "type": "response_item",
            "payload": {
              "type": "web_search_call",
              "status": "completed",
              "action": {"type": "search", "query": "flutter docs"},
            },
          }),
          // A call with no output yet → still rendered, status running.
          jsonEncode({
            "type": "response_item",
            "payload": {
              "type": "function_call",
              "name": "apply_patch",
              "arguments": jsonEncode({"path": "lib/main.dart"}),
              "call_id": "c2",
            },
          }),
        ],
      );

      final messages = messageRepository.readMessages(
        rolloutPath: path,
        sessionId: "019a0000-1111-2222-3333-bbbbbbbbbbbb",
      );

      // exec (completed) + web_search + apply_patch (running); the
      // function_call_output is folded into the exec call, not its own message.
      expect(messages, hasLength(3));

      final exec = messages[0].parts.single;
      expect(exec.type, equals(PluginMessagePartType.tool));
      expect(exec.tool, equals("shell"));
      expect(exec.state?.status, equals(PluginToolStatus.completed));
      expect(exec.state?.title, equals("ls -la"));
      expect(exec.state?.output, contains("foo.dart"));

      final search = messages[1].parts.single;
      expect(search.tool, equals("web_search"));
      expect(search.state?.title, equals("flutter docs"));

      final patch = messages[2].parts.single;
      expect(patch.tool, equals("edit"));
      expect(patch.state?.status, equals(PluginToolStatus.running));
    });

    test("readMessages restores current calls around malformed content items", () {
      final path = _writeRollout(
        codexHome,
        path: "sessions/2026/07/22/rollout-current-messages.jsonl",
        sessionId: "019a0000-1111-2222-3333-bbbbbbbbbbbb",
        cwd: "/repo/app",
        cliVersion: "0.144.1",
        extraLines: [
          jsonEncode({
            "type": "turn_context",
            "payload": {"model": "gpt-5.4"},
          }),
          jsonEncode({
            "timestamp": "2026-07-22T10:00:01Z",
            "type": "response_item",
            "payload": {
              "type": "reasoning",
              "id": "reasoning-1",
              "summary": [
                {"type": "summary_text", "text": "Inspecting "},
                42,
                {"type": "summary_text", "text": "the workspace"},
              ],
            },
          }),
          jsonEncode({
            "timestamp": "2026-07-22T10:00:02Z",
            "type": "response_item",
            "payload": {
              "type": "custom_tool_call",
              "id": "tool-1",
              "status": "completed",
              "call_id": "call-1",
              "name": "exec",
              "input": 'const r = await tools.exec_command({cmd:"ls -la"}); text(r.output);',
            },
          }),
          jsonEncode({
            "timestamp": "2026-07-22T10:00:03Z",
            "type": "response_item",
            "payload": {
              "type": "custom_tool_call_output",
              "call_id": "call-1",
              "output": [
                {"type": "input_text", "text": "total 0\n"},
                "schema-drifted item",
                {"type": "input_text", "text": "foo.dart"},
              ],
            },
          }),
          jsonEncode({
            "timestamp": "2026-07-22T10:00:04Z",
            "type": "response_item",
            "payload": {
              "type": "message",
              "id": "message-1",
              "role": "assistant",
              "content": [
                {"type": "output_text", "text": "Done"},
                false,
              ],
            },
          }),
        ],
      );

      late List<PluginMessageWithParts> messages;
      final output = _captureWarnings(() {
        messages = messageRepository.readMessages(
          rolloutPath: path,
          sessionId: "019a0000-1111-2222-3333-bbbbbbbbbbbb",
        );
      }, level: LogLevel.verbose);

      expect(output, contains("skipping malformed rollout content item"));
      expect(output, isNot(contains("malformed rollout transcript record")));
      expect(messages, hasLength(3));

      final reasoning = messages[0].parts.single;
      expect(reasoning.type, PluginMessagePartType.reasoning);
      expect(reasoning.text, "Inspecting the workspace");

      final tool = messages[1].parts.single;
      expect(tool.type, PluginMessagePartType.tool);
      expect(tool.tool, "shell");
      expect(tool.state?.status, PluginToolStatus.completed);
      expect(tool.state?.title, "ls -la");
      expect(tool.state?.output, contains("foo.dart"));

      final assistant = messages[2];
      expect(assistant.parts.single.text, "Done");
      expect((assistant.info as PluginMessageAssistant).modelID, "gpt-5.4");
    });

    test("readMessages clips tool output by complete Unicode code points", () {
      final emoji = String.fromCharCode(0x1F600);
      final path = _writeRollout(
        codexHome,
        path: "sessions/2026/04/17/rollout-2026-04-17T11-00-00-019a0000-1111-2222-3333-cccccccccccc.jsonl",
        sessionId: "019a0000-1111-2222-3333-cccccccccccc",
        cwd: "/repo/app",
        extraLines: [
          jsonEncode({
            "type": "response_item",
            "payload": {
              "type": "function_call",
              "name": "exec_command",
              "call_id": "c1",
            },
          }),
          jsonEncode({
            "type": "response_item",
            "payload": {
              "type": "function_call_output",
              "call_id": "c1",
              "output": "${"x" * 499}${emoji}tail",
            },
          }),
        ],
      );

      final output = messageRepository
          .readMessages(
            rolloutPath: path,
            sessionId: "019a0000-1111-2222-3333-cccccccccccc",
          )
          .single
          .parts
          .single
          .state
          ?.output;

      expect(output?.runes, hasLength(maxToolOutputLength));
      expect(output, endsWith(emoji));
    });
  });

  group("CodexPlugin Phase 3 wiring", () {
    late Directory codexHome;

    setUp(() {
      codexHome = Directory.systemTemp.createTempSync("codex-home-");
    });

    tearDown(() {
      try {
        codexHome.deleteSync(recursive: true);
      } catch (_) {
        // Best-effort cleanup.
      }
    });

    test("bridge-derived: getProjects is empty; listAllSessions maps each rollout to its real cwd", () async {
      _writeRollout(
        codexHome,
        path: "sessions/2026/04/17/rollout-2026-04-17T10-00-00-019a0000-1111-2222-3333-aaaaaaaaaaaa.jsonl",
        sessionId: "019a0000-1111-2222-3333-aaaaaaaaaaaa",
        cwd: "/work/sample-app",
        timestamp: "2026-04-17T10:00:00Z",
      );
      _writeRollout(
        codexHome,
        path: "sessions/2026/04/18/rollout-2026-04-18T08-30-00-019a0000-1111-2222-3333-bbbbbbbbbbbb.jsonl",
        sessionId: "019a0000-1111-2222-3333-bbbbbbbbbbbb",
        cwd: "/other/project",
        timestamp: "2026-04-18T08:30:00Z",
      );

      const serverUrl = "ws://127.0.0.1:0";
      final plugin = createInjectedCodexPlugin(
        serverUrl: serverUrl,
        environment: {"CODEX_HOME": codexHome.path},
        projectCwd: "/work/sample-app",
        clientFactory: () => CodexAppServerClient(serverUrl: serverUrl),
        keepaliveInterval: const Duration(seconds: 30),
      );

      // Each session carries its own rollout cwd (never the launch CWD), so the
      // bridge groups it under the right project.
      final byId = {
        for (final session in await plugin.listAllSessions(knownDirectories: const {})) session.id: session,
      };
      expect(byId["019a0000-1111-2222-3333-aaaaaaaaaaaa"]?.directory, "/work/sample-app");
      expect(byId["019a0000-1111-2222-3333-bbbbbbbbbbbb"]?.directory, "/other/project");
      expect(byId["019a0000-1111-2222-3333-bbbbbbbbbbbb"]?.projectID, "/other/project");
      await plugin.dispose();
    });

    test("getSessions filters rollouts by CWD == projectId", () async {
      _writeRollout(
        codexHome,
        path: "sessions/2026/04/17/rollout-2026-04-17T10-00-00-019a0000-1111-2222-3333-aaaaaaaaaaaa.jsonl",
        sessionId: "019a0000-1111-2222-3333-aaaaaaaaaaaa",
        cwd: "/work/sample-app",
        timestamp: "2026-04-17T10:00:00Z",
      );
      _writeRollout(
        codexHome,
        path: "sessions/2026/04/18/rollout-2026-04-18T08-30-00-019a0000-1111-2222-3333-bbbbbbbbbbbb.jsonl",
        sessionId: "019a0000-1111-2222-3333-bbbbbbbbbbbb",
        cwd: "/other/project",
        timestamp: "2026-04-18T08:30:00Z",
      );

      const serverUrl = "ws://127.0.0.1:0";
      final plugin = createInjectedCodexPlugin(
        serverUrl: serverUrl,
        environment: {"CODEX_HOME": codexHome.path},
        projectCwd: "/work/sample-app",
        clientFactory: () => CodexAppServerClient(serverUrl: serverUrl),
        keepaliveInterval: const Duration(seconds: 30),
      );

      final sessions = await plugin.getSessions("/work/sample-app");
      expect(sessions, hasLength(1));
      expect(sessions.single.id, equals("019a0000-1111-2222-3333-aaaaaaaaaaaa"));
      expect(sessions.single.directory, equals("/work/sample-app"));

      // Filtering by a different CWD returns empty.
      final none = await plugin.getSessions("/somewhere/else");
      expect(none, isEmpty);
      await plugin.dispose();
    });

    test("getSessionMessages reads the rollout for the session", () async {
      _writeRollout(
        codexHome,
        path: "sessions/2026/04/17/rollout-2026-04-17T10-00-00-019a0000-1111-2222-3333-aaaaaaaaaaaa.jsonl",
        sessionId: "019a0000-1111-2222-3333-aaaaaaaaaaaa",
        cwd: "/work/sample-app",
        extraLines: [
          jsonEncode({
            "type": "response_item",
            "payload": {
              "role": "user",
              "content": [
                {"type": "input_text", "text": "ping"},
              ],
            },
          }),
          jsonEncode({
            "type": "response_item",
            "payload": {
              "role": "assistant",
              "content": [
                {"type": "output_text", "text": "pong"},
              ],
            },
          }),
        ],
      );

      const serverUrl = "ws://127.0.0.1:0";
      final plugin = createInjectedCodexPlugin(
        serverUrl: serverUrl,
        environment: {"CODEX_HOME": codexHome.path},
        projectCwd: "/work/sample-app",
        clientFactory: () => CodexAppServerClient(serverUrl: serverUrl),
        keepaliveInterval: const Duration(seconds: 30),
      );

      final messages = await plugin.getSessionMessages(
        "019a0000-1111-2222-3333-aaaaaaaaaaaa",
      );
      expect(messages, hasLength(2));
      expect(messages[0].parts.first.text, equals("ping"));
      expect(messages[1].parts.first.text, equals("pong"));
      await plugin.dispose();
    });

    test("catalog repository extracts the model from turn_context", () {
      final api = CodexRolloutApi(
        environment: {"CODEX_HOME": codexHome.path},
      );
      final path = _writeRollout(
        codexHome,
        path: "sessions/2026/04/17/rollout-2026-04-17T10-00-00-019a0000-1111-2222-3333-cccccccccccc.jsonl",
        sessionId: "019a0000-1111-2222-3333-cccccccccccc",
        cwd: "/work/sample-app",
        extraLines: [
          jsonEncode({
            "type": "turn_context",
            "payload": {"model": "gpt-5.2-codex"},
          }),
        ],
      );

      final record = CodexCatalogRepository(
        rolloutApi: api,
      ).listSessionRecords().single;
      expect(record.rolloutPath, path);
      expect(record.modelProvider, equals("openai"));
      expect(record.model, equals("gpt-5.2-codex"));
    });

    test("readMessages stamps assistant model from the active turn_context", () {
      final repository = CodexMessageRepository(
        rolloutApi: CodexRolloutApi(
          environment: {"CODEX_HOME": codexHome.path},
        ),
      );
      final path = _writeRollout(
        codexHome,
        path: "sessions/2026/04/17/rollout-2026-04-17T10-00-00-019a0000-1111-2222-3333-dddddddddddd.jsonl",
        sessionId: "019a0000-1111-2222-3333-dddddddddddd",
        cwd: "/work/sample-app",
        extraLines: [
          jsonEncode({
            "type": "turn_context",
            "payload": {"model": "gpt-5.2-codex"},
          }),
          jsonEncode({
            "type": "response_item",
            "payload": {
              "role": "assistant",
              "content": [
                {"type": "output_text", "text": "first"},
              ],
            },
          }),
          // Model switches mid-session — later assistant messages reflect it.
          jsonEncode({
            "type": "turn_context",
            "payload": {"model": "gpt-5.4-codex"},
          }),
          jsonEncode({
            "type": "response_item",
            "payload": {
              "role": "assistant",
              "content": [
                {"type": "output_text", "text": "second"},
              ],
            },
          }),
        ],
      );

      final messages = repository.readMessages(
        rolloutPath: path,
        sessionId: "019a0000-1111-2222-3333-dddddddddddd",
      );
      expect(messages, hasLength(2));
      final first = messages[0].info as PluginMessageAssistant;
      final second = messages[1].info as PluginMessageAssistant;
      expect(first.agent, equals("codex"));
      expect(first.providerID, equals("openai"));
      expect(first.modelID, equals("gpt-5.2-codex"));
      expect(second.modelID, equals("gpt-5.4-codex"));
    });

    test("readMessages falls back to config model when no turn_context", () {
      final repository = CodexMessageRepository(
        rolloutApi: CodexRolloutApi(
          environment: {"CODEX_HOME": codexHome.path},
        ),
      );
      final path = _writeRollout(
        codexHome,
        path: "sessions/2026/04/17/rollout-2026-04-17T10-00-00-019a0000-1111-2222-3333-eeeeeeeeeeee.jsonl",
        sessionId: "019a0000-1111-2222-3333-eeeeeeeeeeee",
        cwd: "/work/sample-app",
        extraLines: [
          jsonEncode({
            "type": "response_item",
            "payload": {
              "role": "assistant",
              "content": [
                {"type": "output_text", "text": "hi"},
              ],
            },
          }),
        ],
      );

      final messages = repository.readMessages(
        rolloutPath: path,
        sessionId: "019a0000-1111-2222-3333-eeeeeeeeeeee",
        config: const CodexConfigDefaults(
          model: "gpt-5.5",
          modelProvider: "openai",
        ),
      );
      final assistant = messages.single.info as PluginMessageAssistant;
      expect(assistant.modelID, equals("gpt-5.5"));
      expect(assistant.providerID, equals("openai"));
    });
  });
}

String _captureWarnings(
  void Function() action, {
  LogLevel level = LogLevel.warning,
}) {
  final previousLevel = Log.level;
  final stderr = _BufferingStdout();
  try {
    Log.level = level;
    IOOverrides.runZoned(action, stderr: () => stderr);
  } finally {
    Log.level = previousLevel;
  }
  return stderr.text;
}

class _BufferingStdout implements Stdout {
  final StringBuffer _buffer = StringBuffer();

  String get text => _buffer.toString();

  @override
  void writeln([Object? object = ""]) => _buffer.writeln(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

String _writeRollout(
  Directory codexHome, {
  required String path,
  required String sessionId,
  required String cwd,
  String timestamp = "2026-04-17T10:00:00Z",
  String cliVersion = "0.121.0",
  List<String> extraLines = const [],
}) {
  final full = p.join(codexHome.path, path);
  Directory(p.dirname(full)).createSync(recursive: true);
  final lines = <String>[
    jsonEncode({
      "timestamp": timestamp,
      "type": "session_meta",
      "payload": {
        "id": sessionId,
        "timestamp": timestamp,
        "cwd": cwd,
        "cli_version": cliVersion,
        "model_provider": "openai",
      },
    }),
    ...extraLines,
  ];
  File(full).writeAsStringSync("${lines.join("\n")}\n");
  return full;
}
