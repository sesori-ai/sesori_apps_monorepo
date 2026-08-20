import "dart:async";
import "dart:convert";
import "dart:io";

import "package:codex_plugin/codex_plugin.dart";
import "package:codex_plugin/src/api/models/codex_rollout_dto.dart";
import "package:codex_plugin/src/models/codex_replay_tool_disposition.dart";
import "package:codex_plugin/src/repositories/codex_catalog_repository.dart";
import "package:codex_plugin/src/repositories/codex_message_repository.dart";
import "package:codex_plugin/src/repositories/mappers/codex_image_attachment_mapper.dart";
import "package:codex_plugin/src/repositories/mappers/codex_user_content_mapper.dart";
import "package:codex_plugin/src/repositories/models/codex_session_record.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "support/codex_plugin_test_factory.dart";

void main() {
  group("Codex rollout layers", () {
    const userContentMapper = CodexUserContentMapper();
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
      messageRepository = CodexMessageRepository(
        rolloutApi: rolloutApi,
        rolloutToolMapper: const CodexRolloutToolMapper(
          imageAttachmentMapper: CodexImageAttachmentMapper(),
        ),
        userContentMapper: userContentMapper,
      );
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

    test("desktop state tolerantly extracts only non-empty projectless thread ids", () async {
      File(p.join(codexHome.path, ".codex-global-state.json")).writeAsStringSync(
        jsonEncode({
          "future-field": {"nested": true},
          "projectless-thread-ids": [
            " projectless-one ",
            42,
            null,
            "",
            {"future": "shape"},
            "projectless-two",
            "projectless-one",
          ],
        }),
      );

      expect(
        (await rolloutApi.readDesktopState()).projectlessThreadIds,
        {"projectless-one", "projectless-two"},
      );
    });

    test("desktop state treats a missing or future-shaped projectless field as empty", () async {
      expect((await rolloutApi.readDesktopState()).projectlessThreadIds, isEmpty);
      final state = File(p.join(codexHome.path, ".codex-global-state.json"));
      for (final contents in [
        jsonEncode({"future-field": true}),
        jsonEncode({
          "projectless-thread-ids": {"future": "shape"},
        }),
      ]) {
        state.writeAsStringSync(contents);
        expect((await rolloutApi.readDesktopState()).projectlessThreadIds, isEmpty);
      }
    });

    test("desktop state read failures retain a privacy-safe cause", () async {
      File(p.join(codexHome.path, ".codex-global-state.json")).writeAsStringSync(
        '{"projectless-thread-ids":["private-thread-id"',
      );

      await expectLater(
        rolloutApi.readDesktopState(),
        throwsA(
          isA<CodexDesktopStateReadException>()
              .having((error) => error.cause, "cause", isA<FormatException>())
              .having(
                (error) => error.toString(),
                "presentation",
                isNot(contains("private-thread-id")),
              ),
        ),
      );
    });

    test("resolves the generated Codex chats directory from the user home", () {
      final userHome = p.join(codexHome.path, "user-home");
      final api = CodexRolloutApi(
        environment: {
          "CODEX_HOME": codexHome.path,
          "HOME": userHome,
          "USERPROFILE": userHome,
        },
      );

      expect(
        api.documentsCodexDirectory,
        p.join(userHome, "Documents", "Codex"),
      );
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
      final line = rolloutApi.readHeader(rolloutPath: path).first;
      expect(line, isA<CodexRolloutSessionMetadataLineDto>());
      final meta = _sessionMetadataPayload(line: line);
      expect(meta.id, equals("019a0000-1111-2222-3333-aaaaaaaaaaaa"));
      expect(meta.cwd, equals("/repo/app"));
      expect(meta.timestamp, equals("2026-04-17T10:00:00Z"));
      expect(meta.cliVersion, equals("0.121.0"));
    });

    test("rollout records decode to closed outer variants", () {
      final lines = [
        CodexRolloutLineDto.fromJson({
          "type": "session_meta",
          "payload": {"id": "session-id"},
        }),
        CodexRolloutLineDto.fromJson({
          "type": "turn_context",
          "payload": {"model": "gpt-5.4"},
        }),
        CodexRolloutLineDto.fromJson({
          "type": "response_item",
          "payload": {
            "type": "message",
            "role": "assistant",
            "content": <Object?>[],
          },
        }),
        CodexRolloutLineDto.fromJson({
          "type": "compacted",
          "payload": {"replacement_history": <Object?>[]},
        }),
        CodexRolloutLineDto.fromJson({
          "type": "future_line",
          "payload": "ignored unknown payload",
        }),
      ];

      expect(lines[0], isA<CodexRolloutSessionMetadataLineDto>());
      expect(lines[1], isA<CodexRolloutTurnContextLineDto>());
      expect(lines[2], isA<CodexRolloutResponseItemLineDto>());
      expect(lines[3], isA<CodexRolloutCompactedLineDto>());
      expect(lines[4], isA<CodexRolloutUnknownLineDto>());
      expect(_sessionMetadataPayload(line: lines[0]).id, "session-id");
      expect(_turnContextPayload(line: lines[1]).model, "gpt-5.4");
      expect(_responseItemPayload(line: lines[2]), isA<CodexRolloutMessageDto>());
    });

    test("response items decode to closed inner variants", () {
      CodexRolloutResponseItemDto decode(Map<String, Object?> payload) {
        return _responseItemPayload(
          line: CodexRolloutLineDto.fromJson({
            "type": "response_item",
            "payload": payload,
          }),
        );
      }

      final items = [
        decode({"type": "message", "role": "assistant", "content": <Object?>[]}),
        decode({"type": "reasoning", "summary": <Object?>[]}),
        decode({"type": "function_call", "call_id": "c1", "name": "exec", "arguments": "{}"}),
        decode({"type": "function_call_output", "call_id": "c1", "output": "done"}),
        decode({"type": "custom_tool_call", "call_id": "c2", "name": "exec", "input": "code"}),
        decode({"type": "custom_tool_call_output", "call_id": "c2", "output": <Object?>[]}),
        decode({"type": "web_search_call", "action": null}),
        decode({"type": "future_item", "secret": "ignored"}),
        decode({
          "type": "image_generation_call",
          "id": "image-1",
          "status": "completed",
          "result": "AA==",
        }),
        decode({
          "type": "image_generation_call",
          "status": "future_status",
          "result": "AA==",
        }),
      ];

      expect(items[0], isA<CodexRolloutMessageDto>());
      expect(items[1], isA<CodexRolloutReasoningDto>());
      expect(items[2], isA<CodexRolloutFunctionCallDto>());
      expect(items[3], isA<CodexRolloutFunctionCallOutputDto>());
      expect(items[4], isA<CodexRolloutCustomToolCallDto>());
      expect(items[5], isA<CodexRolloutCustomToolCallOutputDto>());
      expect(items[6], isA<CodexRolloutWebSearchCallDto>());
      expect(items[7], isA<CodexRolloutUnknownResponseItemDto>());
      final image = items[8] as CodexRolloutImageGenerationDto;
      expect(image.id, "image-1");
      expect(image.status, CodexRolloutImageGenerationStatus.completed);
      expect(image.result, "AA==");
      expect(
        (items[9] as CodexRolloutImageGenerationDto).status,
        CodexRolloutImageGenerationStatus.unknown,
      );
    });

    test("image-generation completion events decode to a typed variant", () {
      final line = CodexRolloutLineDto.fromJson({
        "type": "event_msg",
        "payload": {
          "type": "image_generation_end",
          "call_id": "image-1",
          "status": "completed",
          "revised_prompt": "private prompt",
          "result": "AA==",
          "saved_path": "/private/generated/final.png",
        },
      });

      final event = (line as CodexRolloutEventMessageLineDto).payload;
      expect(
        event,
        isA<CodexRolloutImageGenerationEndEventDto>()
            .having((value) => value.callId, "callId", "image-1")
            .having(
              (value) => value.status,
              "status",
              CodexRolloutImageGenerationStatus.completed,
            )
            .having(
              (value) => value.savedPath,
              "savedPath",
              "/private/generated/final.png",
            ),
      );
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

      expect(
        _sessionMetadataPayload(line: lines.first).id,
        "session-id",
      );
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
      expect(output, contains("recordIndex=2"));
      expect(output, contains("schema=unparseable-json"));
      expect(output, contains("error=FormatException(offset=0)"));
      expect(output, isNot(contains("secret-source-content")));
    });

    test("readTranscript describes malformed record schema without values", () {
      final path = p.join(codexHome.path, "schema-drifted-transcript.jsonl");
      final malformed = jsonEncode({
        "type": "response_item",
        "payload": {
          "type": "function_call",
          "name": "secret-tool-name",
          "call_id": 42,
          "arguments": {
            "type": "secret-token",
            "ghp_secretCredential": "secret-credential",
            "query": "secret-query",
            "cell_id": "secret-cell-id",
          },
          "internal_chat_message_metadata_passthrough": {
            "turn_id": "secret-turn-id",
          },
          "action": "secret-source-content",
        },
      });
      File(path).writeAsStringSync('{}\n$malformed\n{}\n');

      final output = _captureWarnings(
        () => rolloutApi.readTranscript(rolloutPath: path),
        level: LogLevel.verbose,
      );

      expect(output, contains("recordIndex=2"));
      expect(
        output,
        contains(
          'schema={type:enum("response_item"),payload:{'
          'type:enum("function_call"),name:String,call_id:int,arguments:{type:String,'
          '<redacted-key>:String,query:String,cell_id:String},'
          'internal_chat_message_metadata_passthrough:{turn_id:String},'
          "action:String}}",
        ),
      );
      expect(output, contains("error=type 'int'"));
      expect(output, isNot(contains("secret-tool-name")));
      expect(output, isNot(contains("secret-token")));
      expect(output, isNot(contains("secret-credential")));
      expect(output, isNot(contains("secret-query")));
      expect(output, isNot(contains("secret-cell-id")));
      expect(output, isNot(contains("secret-turn-id")));
      expect(output, isNot(contains("secret-source-content")));
    });

    test("readTranscript names durable image schema fields without values", () {
      final path = p.join(codexHome.path, "malformed-image-transcript.jsonl");
      File(path).writeAsStringSync(
        '${jsonEncode({
          "type": "event_msg",
          "payload": {
            "type": "image_generation_end",
            "call_id": "secret-image-id",
            "status": "completed",
            "result": 42,
            "revised_prompt": "secret revised prompt",
            "saved_path": "/secret/generated.png",
          },
        })}\n{}\n',
      );

      final output = _captureWarnings(
        () => rolloutApi.readTranscript(rolloutPath: path),
        level: LogLevel.verbose,
      );

      expect(output, contains('status:enum("completed")'));
      expect(output, contains("result:int"));
      expect(output, contains("revised_prompt:String"));
      expect(output, contains("saved_path:String"));
      expect(output, isNot(contains("secret-image-id")));
      expect(output, isNot(contains("secret revised prompt")));
      expect(output, isNot(contains("/secret/generated.png")));
    });

    test("readTranscript bounds malformed record schema output", () {
      Object? wideValue(int depth) {
        if (depth == 0) return "value";
        return {
          for (var index = 0; index < 16; index++) "field$index": wideValue(depth - 1),
        };
      }

      final path = p.join(codexHome.path, "wide-malformed-transcript.jsonl");
      File(path).writeAsStringSync(
        '${jsonEncode({
          "type": "response_item",
          "payload": "invalid-payload",
          "wide": wideValue(3),
        })}\n{}\n',
      );

      final output = _captureWarnings(
        () => rolloutApi.readTranscript(rolloutPath: path),
        level: LogLevel.verbose,
      );

      expect(output, contains("malformed rollout transcript record"));
      expect(output, contains("schema="));
      expect(output.length, lessThanOrEqualTo(2500));
    });

    test("readTranscriptChunk retains a partial trailing record until newline", () {
      final path = p.join(codexHome.path, "live-tail.jsonl");
      final first = jsonEncode({
        "type": "response_item",
        "payload": {
          "type": "function_call",
          "name": "wait",
          "call_id": "call-1",
          "arguments": "{}",
        },
      });
      final second = jsonEncode({
        "type": "response_item",
        "payload": {
          "type": "function_call_output",
          "call_id": "call-1",
          "output": "done",
        },
      });
      final split = second.length ~/ 2;
      File(path).writeAsStringSync("$first\n${second.substring(0, split)}");

      final initial = rolloutApi.readTranscriptChunk(
        rolloutPath: path,
        offset: 0,
        trailingBytes: const [],
      );

      expect(initial.lines, hasLength(1));
      expect(
        _responseItemCallId(line: initial.lines.single),
        "call-1",
      );
      expect(initial.trailingBytes, isNotEmpty);

      File(path).writeAsStringSync(
        "${second.substring(split)}\n",
        mode: FileMode.append,
      );
      final completed = rolloutApi.readTranscriptChunk(
        rolloutPath: path,
        offset: initial.nextOffset,
        trailingBytes: initial.trailingBytes,
      );

      expect(completed.lines, hasLength(1));
      expect(_responseItemPayload(line: completed.lines.single), isA<CodexRolloutFunctionCallOutputDto>());
      expect(completed.trailingBytes, isEmpty);
    });

    test("rolloutTailPosition seeds an existing partial final record", () {
      final path = p.join(codexHome.path, "live-tail-start.jsonl");
      final ignored = jsonEncode({
        "type": "response_item",
        "payload": {
          "type": "function_call",
          "name": "wait",
          "call_id": "old-call",
          "arguments": "{}",
        },
      });
      final current = jsonEncode({
        "type": "response_item",
        "payload": {
          "type": "function_call_output",
          "call_id": "current-call",
          "output": "done",
        },
      });
      final split = current.length ~/ 2;
      File(path).writeAsStringSync(
        "$ignored\n${current.substring(0, split)}",
      );

      final position = rolloutApi.rolloutTailPosition(
        rolloutPath: path,
      );

      expect(position.offset, File(path).lengthSync());
      expect(
        utf8.decode(position.trailingBytes),
        current.substring(0, split),
      );

      File(path).writeAsStringSync(
        "${current.substring(split)}\n",
        mode: FileMode.append,
      );
      final completed = rolloutApi.readTranscriptChunk(
        rolloutPath: path,
        offset: position.offset,
        trailingBytes: position.trailingBytes,
      );

      expect(completed.lines, hasLength(1));
      expect(
        _responseItemCallId(line: completed.lines.single),
        "current-call",
      );
      expect(completed.trailingBytes, isEmpty);
    });

    test("current structured rollout records are not reported as malformed", () {
      final path = _writeRollout(
        codexHome,
        path: "sessions/2026/07/22/rollout-current.jsonl",
        sessionId: "019a0000-1111-2222-3333-aaaaaaaaaaaa",
        cwd: "/repo/app",
        cliVersion: "0.147.0",
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
          jsonEncode({
            "type": "event_msg",
            "payload": {
              "type": "turn_aborted",
              "reason": "interrupted",
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
      expect(header, hasLength(4));
      expect(transcript, hasLength(4));
      expect(transcript[1], isA<CodexRolloutResponseItemLineDto>());
      expect(_responseItemPayload(line: transcript[1]), isA<CodexRolloutCustomToolCallOutputDto>());
      expect(transcript[2], isA<CodexRolloutResponseItemLineDto>());
      expect(_responseItemPayload(line: transcript[2]), isA<CodexRolloutReasoningDto>());
      expect(
        (transcript[3] as CodexRolloutEventMessageLineDto).payload,
        isA<CodexRolloutTurnAbortedEventDto>().having(
          (event) => event.turnId,
          "turnId",
          isNull,
        ),
      );
    });

    test("rollout content decodes closed text, image, and unknown variants", () {
      final content = const CodexRolloutContentListConverter().fromJson([
        {"type": "input_text", "text": "input"},
        {"type": "output_text", "text": "output"},
        {"type": "summary_text", "text": "summary"},
        {
          "type": "input_image",
          "image_url": "data:image/png;base64,AA==",
          "detail": "high",
        },
        {"type": "future_content", "payload": "not-rendered"},
      ]);

      expect(content, hasLength(5));
      expect(content[0], isA<CodexRolloutInputTextDto>());
      expect((content[0] as CodexRolloutInputTextDto).text, "input");
      expect(content[1], isA<CodexRolloutOutputTextDto>());
      expect((content[1] as CodexRolloutOutputTextDto).text, "output");
      expect(content[2], isA<CodexRolloutSummaryTextDto>());
      expect((content[2] as CodexRolloutSummaryTextDto).text, "summary");
      expect(content[3], isA<CodexRolloutInputImageDto>());
      expect(
        (content[3] as CodexRolloutInputImageDto).imageUrl,
        "data:image/png;base64,AA==",
      );
      expect(content[4], isA<CodexRolloutUnknownContentDto>());
      expect(const CodexRolloutContentListConverter().toJson(content), [
        {"type": "input_text", "text": "input"},
        {"type": "output_text", "text": "output"},
        {"type": "summary_text", "text": "summary"},
        {
          "type": "input_image",
          "image_url": "data:image/png;base64,AA==",
        },
        {"type": "future_content"},
      ]);
    });

    test("rollout content skips malformed known variants without exposing values", () {
      late List<CodexRolloutContentDto> content;
      final output = _captureWarnings(() {
        content = const CodexRolloutContentListConverter().fromJson([
          {"type": "output_text", "text": "kept"},
          {"type": "input_image", "image_url": 42},
          {"type": "future_content", "secret": "not-logged"},
        ]);
      }, level: LogLevel.verbose);

      expect(content, hasLength(2));
      expect(content.first, isA<CodexRolloutOutputTextDto>());
      expect(content.last, isA<CodexRolloutUnknownContentDto>());
      expect(output, contains("skipping malformed rollout content item"));
      expect(output, isNot(contains("not-logged")));
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
      expect(transcript.last, isA<CodexRolloutTurnContextLineDto>());
      expect(
        _turnContextPayload(line: transcript.last).model,
        "gpt-5.4",
      );
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
      expect(transcript.last, isA<CodexRolloutResponseItemLineDto>());
      expect(
        _reasoningSummary(line: transcript.last),
        isEmpty,
      );
    });

    test("object-form tool search arguments do not invalidate the record", () {
      final path = _writeRollout(
        codexHome,
        path: "sessions/2026/07/23/rollout-tool-search-call.jsonl",
        sessionId: "019a0000-1111-2222-3333-aaaaaaaaaaaa",
        cwd: "/repo/app",
        cliVersion: "0.145.0",
        extraLines: [
          jsonEncode({
            "type": "response_item",
            "payload": {
              "type": "tool_search_call",
              "id": "tool-search-1",
              "call_id": "call-1",
              "arguments": {"query": "available tools"},
            },
          }),
        ],
      );

      late List<CodexRolloutLineDto> transcript;
      final output = _captureWarnings(() {
        transcript = rolloutApi.readTranscript(rolloutPath: path);
      }, level: LogLevel.verbose);

      expect(output, isNot(contains("malformed rollout transcript record")));
      expect(transcript.last, isA<CodexRolloutResponseItemLineDto>());
      expect(_responseItemPayload(line: transcript.last), isA<CodexRolloutUnknownResponseItemDto>());
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
              "type": "message",
              "id": "user-1",
              "role": "user",
              "content": [
                {
                  "type": "input_text",
                  "text": '<image name=[Image #1] path="/private/prompt.png">',
                },
                {"type": "input_text", "text": "hello, "},
                {"type": "input_text", "text": "codex"},
                {
                  "type": "input_image",
                  "image_url": "data:image/png;base64,AA==",
                },
              ],
            },
          }),
          jsonEncode({
            "type": "event_msg",
            "payload": {
              "type": "user_message",
              "message": "hello, codex",
            },
          }),
          jsonEncode({
            "type": "response_item",
            "payload": {
              "type": "message",
              "id": "assistant-1",
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
        replayToolDisposition: CodexReplayToolDisposition.terminalize,
        structuredToolStatusByCallId: const {},
      );
      expect(messages, hasLength(2));
      expect(messages[0].info, isA<PluginMessageUser>());
      expect(messages[0].parts.first.text, equals("hello, codex"));
      expect(messages[0].parts.first.text, isNot(contains("/private/prompt.png")));
      expect(messages[0].parts, hasLength(2));
      expect(messages[0].parts.first.attachment, isNull);
      expect(messages[0].parts.last.type, PluginMessagePartType.file);
      final promptImage = messages[0].parts.last.attachment! as PluginMessageAttachmentInlineImage;
      expect(promptImage.mime, "image/png");
      expect(promptImage.base64, "AA==");
      expect(messages[1].info, isA<PluginMessageAssistant>());
      expect(messages[1].parts.first.text, equals("hello back!"));
      expect(messages[0].info.sessionID, equals("019a0000-1111-2222-3333-aaaaaaaaaaaa"));
      expect(messages[0].info.id, "user-1");
      expect(messages[0].parts.first.id, "user-1-text");
      expect(messages[0].parts.last.id, "user-1-file-1");
      expect(messages[1].info.id, "assistant-1");
      expect(messages[1].parts.single.id, "assistant-1-text");
    });

    test("readMessages hides bridge context while preserving authored text and images", () {
      const worktreeContext = """
[SYSTEM CONTEXT \u2014 IMPORTANT]
A dedicated git worktree and branch have been created for this session:
- Branch: feature
- Worktree path: /repo/.worktrees/feature
- Based on: main

IMPORTANT: Perform all work for this task in this dedicated worktree. You may use the initial branch above, or switch branches or create additional branches here as needed. Do NOT create another worktree or working directory — even if other instructions suggest it.

---
""";
      final path = _writeRollout(
        codexHome,
        path: "sessions/2026/08/15/rollout-worktree-context.jsonl",
        sessionId: "019a0000-1111-2222-3333-aaaaaaaaaaab",
        cwd: "/repo/app/.worktrees/gray-wolf",
        extraLines: [
          jsonEncode({
            "type": "response_item",
            "payload": {
              "type": "message",
              "id": "attachment-only",
              "role": "user",
              "content": [
                {"type": "input_text", "text": worktreeContext},
                {"type": "input_image", "image_url": "data:image/png;base64,AA=="},
              ],
            },
          }),
          jsonEncode({
            "type": "event_msg",
            "payload": {
              "type": "user_message",
              "message": worktreeContext,
            },
          }),
          jsonEncode({
            "type": "response_item",
            "payload": {
              "type": "message",
              "id": "mixed-prompt",
              "role": "user",
              "content": [
                {"type": "input_text", "text": worktreeContext},
                {"type": "input_text", "text": "visible prompt"},
                {"type": "input_image", "image_url": "data:image/png;base64,AQ=="},
              ],
            },
          }),
          jsonEncode({
            "type": "event_msg",
            "payload": {
              "type": "user_message",
              "message": "$worktreeContext\nvisible prompt",
            },
          }),
        ],
      );

      final messages = messageRepository.readMessages(
        rolloutPath: path,
        sessionId: "019a0000-1111-2222-3333-aaaaaaaaaaab",
        replayToolDisposition: CodexReplayToolDisposition.terminalize,
        structuredToolStatusByCallId: const {},
      );

      expect(messages.map((message) => message.info.id), ["attachment-only", "mixed-prompt"]);
      expect(messages.first.parts, hasLength(1));
      expect(messages.first.parts.single.type, PluginMessagePartType.file);
      expect(messages.first.parts.single.attachment, isA<PluginMessageAttachmentInlineImage>());
      expect(messages.last.parts, hasLength(2));
      expect(messages.last.parts.first.text, "visible prompt");
      expect(messages.last.parts.first.text, isNot(contains("SYSTEM CONTEXT")));
      final image = messages.last.parts.last.attachment! as PluginMessageAttachmentInlineImage;
      expect(image.base64, "AQ==");
    });

    test("readMessages hides bridge context inside a command invocation", () {
      const invocation = r"""
$review [SYSTEM CONTEXT — IMPORTANT]
A dedicated git worktree and branch have been created for this session:
- Branch: feature
- Worktree path: /repo/.worktrees/feature
- Based on: main

IMPORTANT: Perform all work for this task in this dedicated worktree. You may use the initial branch above, or switch branches or create additional branches here as needed. Do NOT create another worktree or working directory — even if other instructions suggest it.

---

authored arguments
""";
      final path = _writeRollout(
        codexHome,
        path: "sessions/2026/08/20/rollout-command-context.jsonl",
        sessionId: "019a0000-1111-2222-3333-aaaaaaaaaaad",
        cwd: "/repo/.worktrees/feature",
        extraLines: [
          jsonEncode({
            "type": "response_item",
            "payload": {
              "type": "message",
              "id": "command-context",
              "role": "user",
              "content": [
                {"type": "input_text", "text": invocation},
              ],
            },
          }),
          jsonEncode({
            "type": "event_msg",
            "payload": {"type": "user_message", "message": invocation},
          }),
        ],
      );

      final messages = messageRepository.readMessages(
        rolloutPath: path,
        sessionId: "019a0000-1111-2222-3333-aaaaaaaaaaad",
        replayToolDisposition: CodexReplayToolDisposition.terminalize,
        structuredToolStatusByCallId: const {},
      );

      expect(messages.single.parts.single.text, r"$review authored arguments" "\n");
    });

    test("readMessages skips a pending bridge-context-only user message", () {
      const worktreeContext = """
[SYSTEM CONTEXT — IMPORTANT]
A dedicated git worktree and branch have been created for this session:
- Branch: feature
- Worktree path: /repo/.worktrees/feature
- Based on: main

IMPORTANT: Perform all work for this task in this dedicated worktree. You may use the initial branch above, or switch branches or create additional branches here as needed. Do NOT create another worktree or working directory — even if other instructions suggest it.

---
""";
      final path = _writeRollout(
        codexHome,
        path: "sessions/2026/08/20/rollout-context-only.jsonl",
        sessionId: "019a0000-1111-2222-3333-aaaaaaaaaaac",
        cwd: "/repo/.worktrees/feature",
        extraLines: [
          jsonEncode({
            "type": "response_item",
            "payload": {
              "type": "message",
              "id": "context-only",
              "role": "user",
              "content": [
                {"type": "input_text", "text": worktreeContext},
              ],
            },
          }),
          jsonEncode({
            "type": "event_msg",
            "payload": {"type": "user_message", "message": worktreeContext},
          }),
        ],
      );

      final messages = messageRepository.readMessages(
        rolloutPath: path,
        sessionId: "019a0000-1111-2222-3333-aaaaaaaaaaac",
        replayToolDisposition: CodexReplayToolDisposition.terminalize,
        structuredToolStatusByCallId: const {},
      );

      expect(messages, isEmpty);
    });

    test("readMessages preserves a terminal Codex failure as an error message", () {
      const sessionId = "019a0000-1111-2222-3333-eeeeeeeeeeee";
      final path = _writeRollout(
        codexHome,
        path: "sessions/2026/08/19/rollout-terminal-error.jsonl",
        sessionId: sessionId,
        cwd: "/repo/app",
        extraLines: [
          jsonEncode({
            "type": "turn_context",
            "payload": {"model": "gpt-5.6"},
          }),
          jsonEncode({
            "timestamp": "2026-08-19T18:06:15.079Z",
            "type": "event_msg",
            "payload": {
              "type": "task_complete",
              "turn_id": "turn-quota",
              "error": {
                "message": "You've hit your usage limit.",
                "codex_error_info": "usage_limit_exceeded",
              },
            },
          }),
        ],
      );

      final messages = messageRepository.readMessages(
        rolloutPath: path,
        sessionId: sessionId,
        replayToolDisposition: CodexReplayToolDisposition.terminalize,
        structuredToolStatusByCallId: const {},
      );

      expect(messages, hasLength(1));
      final error = messages.single.info as PluginMessageError;
      expect(error.id, "turn-quota");
      expect(error.modelID, "gpt-5.6");
      expect(error.providerID, "openai");
      expect(error.errorName, "CodexError");
      expect(error.errorMessage, "You've hit your usage limit.");
      expect(messages.single.parts, isEmpty);
    });

    test("readMessages excludes only generated Codex user context envelopes", () {
      final path = _writeRollout(
        codexHome,
        path: "sessions/2026/08/03/rollout-generated-context.jsonl",
        sessionId: "019a0000-1111-2222-3333-ccccccccccc1",
        cwd: "/repo/app",
        extraLines: [
          jsonEncode({
            "type": "response_item",
            "payload": {
              "type": "message",
              "id": "generated-bootstrap",
              "role": "user",
              "content": [
                {
                  "type": "input_text",
                  "text": "<recommended_plugins>\ninternal list\n</recommended_plugins>",
                },
                {
                  "type": "input_text",
                  "text": "<environment_context>\n  <cwd>/repo/app</cwd>\n</environment_context>",
                },
              ],
            },
          }),
          jsonEncode({
            "type": "response_item",
            "payload": {
              "type": "message",
              "id": "actual-user",
              "role": "user",
              "content": [
                {
                  "type": "input_text",
                  "text": "Explain the <environment_context> tag",
                },
              ],
            },
          }),
          jsonEncode({
            "type": "response_item",
            "payload": {
              "type": "message",
              "id": "actual-wrapper-user",
              "role": "user",
              "content": [
                {
                  "type": "input_text",
                  "text": "<environment_context>user-authored text</environment_context>",
                },
              ],
            },
          }),
          jsonEncode({
            "type": "event_msg",
            "payload": {
              "type": "user_message",
              "message": "<environment_context>user-authored text</environment_context>",
            },
          }),
          jsonEncode({
            "type": "response_item",
            "payload": {
              "type": "message",
              "id": "mixed-context-user",
              "role": "user",
              "content": [
                {
                  "type": "input_text",
                  "text": "<recommended_plugins>internal list</recommended_plugins>",
                },
                {"type": "input_text", "text": "Visible mixed prompt"},
                {
                  "type": "input_text",
                  "text": "<environment_context>internal cwd</environment_context>",
                },
              ],
            },
          }),
          jsonEncode({
            "type": "event_msg",
            "payload": {
              "type": "user_message",
              "message": "Visible mixed prompt",
            },
          }),
          jsonEncode({
            "type": "response_item",
            "payload": {
              "type": "message",
              "id": "generated-abort",
              "role": "user",
              "content": [
                {
                  "type": "input_text",
                  "text": "<turn_aborted>\nThe turn was interrupted.\n</turn_aborted>",
                },
              ],
            },
          }),
          jsonEncode({
            "type": "response_item",
            "payload": {
              "type": "message",
              "id": "assistant-1",
              "role": "assistant",
              "content": [
                {"type": "output_text", "text": "Visible answer"},
              ],
            },
          }),
        ],
      );

      final messages = messageRepository.readMessages(
        rolloutPath: path,
        sessionId: "019a0000-1111-2222-3333-ccccccccccc1",
        replayToolDisposition: CodexReplayToolDisposition.terminalize,
        structuredToolStatusByCallId: const {},
      );

      expect(messages.map((message) => message.info.id), [
        "actual-user",
        "actual-wrapper-user",
        "mixed-context-user",
        "assistant-1",
      ]);
      expect(messages.first.parts.single.text, "Explain the <environment_context> tag");
      expect(
        messages[1].parts.single.text,
        "<environment_context>user-authored text</environment_context>",
      );
      expect(messages[2].parts.single.text, "Visible mixed prompt");
      expect(messages.last.parts.single.text, "Visible answer");
    });

    test("readMessages excludes only complete generated repository instructions", () {
      const generatedWithPath =
          "# AGENTS.md instructions for /sanitized/project\n\n"
          "<INSTRUCTIONS>\nrepository marker\n</INSTRUCTIONS>";
      const generatedWithoutPath =
          "# AGENTS.md instructions\n\n"
          "<INSTRUCTIONS>\nrepository marker\n</INSTRUCTIONS>";
      const generatedCompact =
          "# AGENTS.md instructions\n\n"
          "<INSTRUCTIONS>repository marker</INSTRUCTIONS>";
      String userMessageLine({required String id, required String text}) => jsonEncode({
        "type": "response_item",
        "payload": {
          "type": "message",
          "id": id,
          "role": "user",
          "content": [
            {"type": "input_text", "text": text},
          ],
        },
      });
      final path = _writeRollout(
        codexHome,
        path: "sessions/2026/08/04/rollout-generated-repository-instructions.jsonl",
        sessionId: "019a0000-1111-2222-3333-ccccccccccc2",
        cwd: "/repo/app",
        extraLines: [
          userMessageLine(id: "generated-with-path", text: generatedWithPath),
          userMessageLine(id: "generated-without-path", text: generatedWithoutPath),
          userMessageLine(id: "generated-compact", text: generatedCompact),
          userMessageLine(id: "generated-with-outer-whitespace", text: "  $generatedWithPath\n"),
          userMessageLine(id: "authored-exact-envelope", text: generatedWithPath),
          jsonEncode({
            "type": "event_msg",
            "payload": {
              "type": "user_message",
              "message": generatedWithPath,
            },
          }),
          userMessageLine(
            id: "near-match-case",
            text: "# agents.md instructions\n\n<INSTRUCTIONS>\nmarker\n</INSTRUCTIONS>",
          ),
          userMessageLine(
            id: "incomplete-envelope",
            text: "# AGENTS.md instructions\n\n<INSTRUCTIONS>\nmarker",
          ),
          userMessageLine(
            id: "mixed-envelope",
            text: "$generatedWithoutPath\nVisible authored text",
          ),
        ],
      );

      final messages = messageRepository.readMessages(
        rolloutPath: path,
        sessionId: "019a0000-1111-2222-3333-ccccccccccc2",
        replayToolDisposition: CodexReplayToolDisposition.terminalize,
        structuredToolStatusByCallId: const {},
      );

      expect(messages.map((message) => message.info.id), [
        "authored-exact-envelope",
        "near-match-case",
        "incomplete-envelope",
        "mixed-envelope",
      ]);
      expect(messages.first.parts.single.text, generatedWithPath);
    });

    test("readMessages preserves compacted rollout records as completed tools", () {
      final path = _writeRollout(
        codexHome,
        path: "sessions/2026/07/23/rollout-compacted.jsonl",
        sessionId: "019a0000-1111-2222-3333-cccccccccccc",
        cwd: "/repo/app",
        extraLines: [
          jsonEncode({
            "timestamp": "2026-07-23T14:48:17.959Z",
            "type": "compacted",
            "payload": {
              "message": "",
              "replacement_history": [
                {
                  "type": "compaction",
                  "id": "cmp-secret",
                  "encrypted_content": "not-rendered",
                },
              ],
            },
          }),
        ],
      );

      final messages = messageRepository.readMessages(
        rolloutPath: path,
        sessionId: "019a0000-1111-2222-3333-cccccccccccc",
        replayToolDisposition: CodexReplayToolDisposition.terminalize,
        structuredToolStatusByCallId: const {},
      );

      expect(messages, hasLength(1));
      expect(messages.single.info, isA<PluginMessageAssistant>());
      expect(messages.single.info.id, "codex-compaction-1");
      expect(messages.single.info.time?.created, 1784818097959);
      final part = messages.single.parts.single;
      expect(part.tool, "compact");
      expect(part.state?.title, "Context compacted");
      expect(part.state?.status, PluginToolStatus.completed);
      expect(part.state?.output, isNull);
    });

    test("readMessages restores image generations with stable persisted and fallback ids", () {
      final path = _writeRollout(
        codexHome,
        path: "sessions/2026/07/31/rollout-image-history.jsonl",
        sessionId: "019a0000-1111-2222-3333-iiiiiiiiiiii",
        cwd: "/repo/app",
        extraLines: [
          jsonEncode({
            "timestamp": "2026-07-31T10:00:01Z",
            "type": "response_item",
            "payload": {
              "type": "image_generation_call",
              "id": "image-1",
              "status": "completed",
              "revised_prompt": "private prompt",
              "result": "AA==",
            },
          }),
          jsonEncode({
            "timestamp": "2026-07-31T10:00:02Z",
            "type": "response_item",
            "payload": {
              "type": "image_generation_call",
              "status": "completed",
              "result": "AA==",
            },
          }),
        ],
      );

      final firstRead = messageRepository.readMessages(
        rolloutPath: path,
        sessionId: "019a0000-1111-2222-3333-iiiiiiiiiiii",
        replayToolDisposition: CodexReplayToolDisposition.terminalize,
        structuredToolStatusByCallId: const {},
      );
      final secondRead = messageRepository.readMessages(
        rolloutPath: path,
        sessionId: "019a0000-1111-2222-3333-iiiiiiiiiiii",
        replayToolDisposition: CodexReplayToolDisposition.terminalize,
        structuredToolStatusByCallId: const {},
      );

      expect(firstRead.map((message) => message.info.id), ["image-1", "m-2"]);
      expect(secondRead.map((message) => message.info.id), ["image-1", "m-2"]);
      for (final message in firstRead) {
        final part = message.parts.single;
        expect(part.id, "${message.info.id}-tool");
        expect(part.messageID, message.info.id);
        expect(part.tool, "image_generation");
        expect(part.state?.status, PluginToolStatus.completed);
        final attachment = part.state!.attachments.single as PluginMessageAttachmentInlineImage;
        expect(attachment.mime, "image/png");
        expect(attachment.base64, "AA==");
        expect(attachment.filename, isNull);
        expect(part.toString(), isNot(contains("private prompt")));
      }
    });

    test("idle replay settles interrupted stable and legacy image generations", () {
      final path = _writeRollout(
        codexHome,
        path: "sessions/2026/08/04/rollout-interrupted-images.jsonl",
        sessionId: "019a0000-1111-2222-3333-iiiiiiiiii99",
        cwd: "/repo/app",
        extraLines: [
          jsonEncode({
            "type": "response_item",
            "payload": {
              "type": "image_generation_call",
              "id": "image-running",
              "status": "in_progress",
              "result": "AA==",
            },
          }),
          jsonEncode({
            "type": "event_msg",
            "payload": {
              "type": "user_message",
              "message": "retry",
            },
          }),
          jsonEncode({
            "type": "response_item",
            "payload": {
              "type": "image_generation_call",
              "status": "in_progress",
              "result": "AQ==",
            },
          }),
        ],
      );

      final busyMessages = messageRepository.readMessages(
        rolloutPath: path,
        sessionId: "019a0000-1111-2222-3333-iiiiiiiiii99",
        replayToolDisposition: CodexReplayToolDisposition.preserveRunning,
        structuredToolStatusByCallId: const {},
      );
      final idleMessages = messageRepository.readMessages(
        rolloutPath: path,
        sessionId: "019a0000-1111-2222-3333-iiiiiiiiii99",
        replayToolDisposition: CodexReplayToolDisposition.terminalize,
        structuredToolStatusByCallId: const {},
      );

      expect(
        busyMessages
            .where((message) => message.parts.single.type == PluginMessagePartType.tool)
            .map((message) => message.parts.single.state?.status),
        everyElement(PluginToolStatus.running),
      );
      expect(
        idleMessages
            .where((message) => message.parts.single.type == PluginMessagePartType.tool)
            .map((message) => message.parts.single.state?.status),
        everyElement(PluginToolStatus.error),
      );
    });

    test("readMessages prefers durable image events over duplicate response items", () {
      final path = _writeRollout(
        codexHome,
        path: "sessions/2026/08/03/rollout-durable-image-history.jsonl",
        sessionId: "019a0000-1111-2222-3333-iiiiiiiiiii2",
        cwd: "/repo/app",
        extraLines: [
          jsonEncode({
            "type": "response_item",
            "payload": {
              "type": "image_generation_call",
              "id": "image-1",
              "status": "completed",
              "result": "AQ==",
            },
          }),
          jsonEncode({
            "type": "event_msg",
            "payload": {
              "type": "image_generation_end",
              "call_id": " image-1 ",
              "status": "completed",
              "revised_prompt": "private prompt",
              "result": "AA==",
              "saved_path": "/private/generated/final.png",
            },
          }),
        ],
      );

      final messages = messageRepository.readMessages(
        rolloutPath: path,
        sessionId: "019a0000-1111-2222-3333-iiiiiiiiiii2",
        replayToolDisposition: CodexReplayToolDisposition.terminalize,
        structuredToolStatusByCallId: const {},
      );

      expect(messages, hasLength(1));
      expect(messages.single.info.id, "image-1");
      final part = messages.single.parts.single;
      expect(part.tool, "image_generation");
      expect(part.state?.status, PluginToolStatus.completed);
      final attachment = part.state!.attachments.single as PluginMessageAttachmentInlineImage;
      expect(attachment.base64, "AA==");
      expect(attachment.filename, "final.png");
    });

    test("readMessages correlates id-less image records by durable result", () {
      final path = _writeRollout(
        codexHome,
        path: "sessions/2026/08/03/rollout-idless-durable-image.jsonl",
        sessionId: "019a0000-1111-2222-3333-iiiiiiiiiii3",
        cwd: "/repo/app",
        extraLines: [
          jsonEncode({
            "type": "response_item",
            "payload": {
              "type": "image_generation_call",
              "status": "completed",
              "result": "AA==",
            },
          }),
          jsonEncode({
            "type": "event_msg",
            "payload": {
              "type": "image_generation_end",
              "call_id": "image-durable",
              "status": "completed",
              "revised_prompt": null,
              "result": "AA==",
              "saved_path": "/private/generated/final.png",
            },
          }),
        ],
      );

      final messages = messageRepository.readMessages(
        rolloutPath: path,
        sessionId: "019a0000-1111-2222-3333-iiiiiiiiiii3",
        replayToolDisposition: CodexReplayToolDisposition.terminalize,
        structuredToolStatusByCallId: const {},
      );

      expect(messages, hasLength(1));
      expect(messages.single.info.id, "image-durable");
    });

    test("blank durable image ids do not shift legacy message ids", () {
      final path = _writeRollout(
        codexHome,
        path: "sessions/2026/08/03/rollout-blank-durable-image.jsonl",
        sessionId: "019a0000-1111-2222-3333-iiiiiiiiiii4",
        cwd: "/repo/app",
        extraLines: [
          jsonEncode({
            "type": "event_msg",
            "payload": {
              "type": "image_generation_end",
              "call_id": "   ",
              "status": "completed",
              "revised_prompt": null,
              "result": "AQ==",
              "saved_path": null,
            },
          }),
          jsonEncode({
            "type": "response_item",
            "payload": {
              "type": "image_generation_call",
              "status": "completed",
              "result": "AA==",
            },
          }),
        ],
      );

      final messages = messageRepository.readMessages(
        rolloutPath: path,
        sessionId: "019a0000-1111-2222-3333-iiiiiiiiiii4",
        replayToolDisposition: CodexReplayToolDisposition.terminalize,
        structuredToolStatusByCallId: const {},
      );

      expect(messages.single.info.id, "m-1");
    });

    test("readMessages surfaces transcript read failures", () {
      const sessionId = "019a0000-1111-2222-3333-aaaaaaaaaaaa";
      final path = p.join(codexHome.path, "broken-rollout.jsonl");
      File(path).writeAsBytesSync([0xFF]);

      expect(
        () => messageRepository.readMessages(
          rolloutPath: path,
          sessionId: sessionId,
          replayToolDisposition: CodexReplayToolDisposition.terminalize,
          structuredToolStatusByCallId: const {},
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
        replayToolDisposition: CodexReplayToolDisposition.terminalize,
        structuredToolStatusByCallId: const {
          "c2": PluginToolStatus.error,
        },
      );

      // exec (completed) + web_search + apply_patch (running); the
      // function_call_output is folded into the exec call, not its own message.
      expect(messages, hasLength(3));

      final exec = messages[0].parts.single;
      expect(messages[0].info.id, "c1");
      expect(exec.id, "c1-tool");
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
      expect(patch.state?.status, equals(PluginToolStatus.error));
    });

    test("readMessages closes calls from terminal or idle evidence", () {
      Map<String, Object?> call({
        required String callId,
        required String command,
        required String? turnId,
        required String name,
      }) => {
        "type": "response_item",
        "payload": {
          "type": "function_call",
          "call_id": callId,
          "name": name,
          "arguments": name == "wait" ? command : jsonEncode({"cmd": command}),
          if (turnId != null)
            "internal_chat_message_metadata_passthrough": {
              "turn_id": turnId,
            },
        },
      };

      Map<String, Object?> output({
        required String callId,
        required String text,
      }) => {
        "type": "response_item",
        "payload": {
          "type": "function_call_output",
          "call_id": callId,
          "output": text,
        },
      };

      final path = _writeRollout(
        codexHome,
        path: "sessions/2026/08/03/rollout-tool-lifecycle.jsonl",
        sessionId: "019a0000-1111-2222-3333-ccccccccccc2",
        cwd: "/repo/app",
        extraLines: [
          jsonEncode(
            call(
              callId: "call-shell",
              command: "sleep 30",
              turnId: "turn-wait",
              name: "exec_command",
            ),
          ),
          jsonEncode(
            output(
              callId: "call-shell",
              text: "Script running with cell ID 7\nOutput:\nearly output\n",
            ),
          ),
          jsonEncode(
            call(
              callId: "call-wait",
              command: '{"cell_id":"7"}',
              turnId: "turn-wait",
              name: "wait",
            ),
          ),
          jsonEncode(
            output(
              callId: "call-wait",
              text: "Script running with cell ID 8\nOutput:\nmiddle output\n",
            ),
          ),
          jsonEncode(
            call(
              callId: "call-wait-final",
              command: '{"cell_id":"8"}',
              turnId: "turn-wait",
              name: "wait",
            ),
          ),
          jsonEncode(
            output(
              callId: "call-wait-final",
              text: "aborted by user after 1.0s",
            ),
          ),
          jsonEncode(
            call(
              callId: "call-completed",
              command: "pwd",
              turnId: "turn-completed",
              name: "exec_command",
            ),
          ),
          jsonEncode(
            output(
              callId: "call-completed",
              text: "Script running with cell ID 9\nOutput:\n",
            ),
          ),
          jsonEncode({
            "type": "event_msg",
            "payload": {
              "type": "task_complete",
              "turn_id": "turn-completed",
            },
          }),
          jsonEncode(
            call(
              callId: "call-aborted",
              command: "sleep 60",
              turnId: "turn-aborted",
              name: "exec_command",
            ),
          ),
          jsonEncode(
            output(
              callId: "call-aborted",
              text: "Script running with cell ID 10\nOutput:\n",
            ),
          ),
          jsonEncode({
            "type": "event_msg",
            "payload": {
              "type": "turn_aborted",
              "turn_id": "turn-aborted",
            },
          }),
          jsonEncode(
            call(
              callId: "call-legacy-completed",
              command: "sleep 70",
              turnId: null,
              name: "exec_command",
            ),
          ),
          jsonEncode(
            output(
              callId: "call-legacy-completed",
              text: "Script running with cell ID 11\nOutput:\n",
            ),
          ),
          jsonEncode({
            "type": "event_msg",
            "payload": {
              "type": "task_complete",
              "turn_id": "turn-legacy-completed",
            },
          }),
          jsonEncode(
            call(
              callId: "call-legacy-aborted",
              command: "sleep 80",
              turnId: null,
              name: "exec_command",
            ),
          ),
          jsonEncode(
            output(
              callId: "call-legacy-aborted",
              text: "Script running with cell ID 12\nOutput:\n",
            ),
          ),
          jsonEncode({
            "type": "event_msg",
            "payload": {
              "type": "turn_aborted",
              "turn_id": "turn-legacy-aborted",
            },
          }),
          jsonEncode(
            call(
              callId: "call-interrupted-legacy",
              command: "sleep 90",
              turnId: null,
              name: "exec_command",
            ),
          ),
          jsonEncode({
            "type": "response_item",
            "payload": {
              "type": "message",
              "id": "user-next",
              "role": "user",
              "content": [
                {"type": "input_text", "text": "continue"},
              ],
            },
          }),
          jsonEncode({
            "type": "event_msg",
            "payload": {
              "type": "user_message",
              "message": "continue",
            },
          }),
          jsonEncode(
            call(
              callId: "call-active",
              command: "sleep 120",
              turnId: null,
              name: "exec_command",
            ),
          ),
        ],
      );

      final messages = messageRepository.readMessages(
        rolloutPath: path,
        sessionId: "019a0000-1111-2222-3333-ccccccccccc2",
        replayToolDisposition: CodexReplayToolDisposition.preserveRunning,
        structuredToolStatusByCallId: const {},
      );
      final idleMessages = messageRepository.readMessages(
        rolloutPath: path,
        sessionId: "019a0000-1111-2222-3333-ccccccccccc2",
        replayToolDisposition: CodexReplayToolDisposition.terminalize,
        structuredToolStatusByCallId: const {},
      );

      expect(messages.map((message) => message.info.id), [
        "call-shell",
        "call-completed",
        "call-aborted",
        "call-legacy-completed",
        "call-legacy-aborted",
        "call-interrupted-legacy",
        "user-next",
        "call-active",
      ]);
      final tools = {
        for (final message in messages)
          if (message.parts.single.type == PluginMessagePartType.tool) message.info.id: message.parts.single,
      };
      expect(tools["call-shell"]?.state?.status, PluginToolStatus.error);
      expect(tools["call-shell"]?.state?.output, contains("early output"));
      expect(tools["call-shell"]?.state?.output, contains("middle output"));
      expect(tools["call-shell"]?.state?.output, contains("aborted by user after 1.0s"));
      expect(tools["call-completed"]?.state?.status, PluginToolStatus.completed);
      expect(tools["call-aborted"]?.state?.status, PluginToolStatus.error);
      expect(tools["call-legacy-completed"]?.state?.status, PluginToolStatus.completed);
      expect(tools["call-legacy-aborted"]?.state?.status, PluginToolStatus.error);
      expect(tools["call-interrupted-legacy"]?.state?.status, PluginToolStatus.error);
      expect(tools["call-active"]?.state?.status, PluginToolStatus.running);
      final idleActiveCall = idleMessages.singleWhere(
        (message) => message.info.id == "call-active",
      );
      expect(idleActiveCall.parts.single.state?.status, PluginToolStatus.error);
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
                {
                  "type": "input_image",
                  "image_url": "data:image/png;base64,AA==",
                },
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
          replayToolDisposition: CodexReplayToolDisposition.terminalize,
          structuredToolStatusByCallId: const {},
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
      final attachment = tool.state!.attachments.single as PluginMessageAttachmentInlineImage;
      expect(attachment.mime, "image/png");
      expect(attachment.base64, "AA==");

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
              "arguments": "{}",
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
            replayToolDisposition: CodexReplayToolDisposition.terminalize,
            structuredToolStatusByCallId: const {},
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
              "type": "message",
              "role": "user",
              "content": [
                {"type": "input_text", "text": "ping"},
              ],
            },
          }),
          jsonEncode({
            "type": "response_item",
            "payload": {
              "type": "message",
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

    test("getSessionMessages preserves running tools when activity is unknown", () async {
      const sessionId = "019a0000-1111-2222-3333-aaaaaaaaaa99";
      _writeRollout(
        codexHome,
        path: "sessions/2026/04/17/rollout-2026-04-17T10-00-00-019a0000-1111-2222-3333-aaaaaaaaaa99.jsonl",
        sessionId: sessionId,
        cwd: "/work/sample-app",
        extraLines: [
          jsonEncode({
            "type": "response_item",
            "payload": {
              "type": "function_call",
              "call_id": "call-running",
              "name": "exec_command",
              "arguments": '{"cmd":"sleep 30"}',
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

      final messages = await plugin.getSessionMessages(sessionId);

      expect(messages.single.parts.single.state?.status, PluginToolStatus.running);
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
        rolloutToolMapper: const CodexRolloutToolMapper(
          imageAttachmentMapper: CodexImageAttachmentMapper(),
        ),
        userContentMapper: const CodexUserContentMapper(),
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
              "type": "message",
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
              "type": "message",
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
        replayToolDisposition: CodexReplayToolDisposition.terminalize,
        structuredToolStatusByCallId: const {},
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
        rolloutToolMapper: const CodexRolloutToolMapper(
          imageAttachmentMapper: CodexImageAttachmentMapper(),
        ),
        userContentMapper: const CodexUserContentMapper(),
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
              "type": "message",
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
        replayToolDisposition: CodexReplayToolDisposition.terminalize,
        structuredToolStatusByCallId: const {},
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

CodexRolloutSessionMetadataPayloadDto _sessionMetadataPayload({
  required CodexRolloutLineDto line,
}) {
  return switch (line) {
    CodexRolloutSessionMetadataLineDto(:final payload) => payload,
    _ => throw StateError("Expected session metadata rollout line"),
  };
}

CodexRolloutTurnContextPayloadDto _turnContextPayload({
  required CodexRolloutLineDto line,
}) {
  return switch (line) {
    CodexRolloutTurnContextLineDto(:final payload) => payload,
    _ => throw StateError("Expected turn context rollout line"),
  };
}

CodexRolloutResponseItemDto _responseItemPayload({
  required CodexRolloutLineDto line,
}) {
  return switch (line) {
    CodexRolloutResponseItemLineDto(:final payload) => payload,
    _ => throw StateError("Expected response item rollout line"),
  };
}

String _responseItemCallId({required CodexRolloutLineDto line}) {
  return switch (_responseItemPayload(line: line)) {
    CodexRolloutFunctionCallDto(:final callId) ||
    CodexRolloutFunctionCallOutputDto(:final callId) ||
    CodexRolloutCustomToolCallDto(:final callId) ||
    CodexRolloutCustomToolCallOutputDto(:final callId) => callId,
    _ => throw StateError("Expected tool response item"),
  };
}

List<CodexRolloutContentDto> _reasoningSummary({required CodexRolloutLineDto line}) {
  return switch (_responseItemPayload(line: line)) {
    CodexRolloutReasoningDto(:final summary) => summary,
    _ => throw StateError("Expected reasoning response item"),
  };
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

class _BufferingStdout() implements Stdout {
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
