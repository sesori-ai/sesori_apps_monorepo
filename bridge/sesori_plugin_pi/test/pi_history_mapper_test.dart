import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:pi_plugin/src/api/models/pi_session_history_dto.dart";
import "package:pi_plugin/src/models/pi_assistant_stop_reason.dart";
import "package:pi_plugin/src/repositories/mappers/pi_history_mapper.dart";
import "package:pi_plugin/src/repositories/mappers/pi_message_identity_builder.dart";
import "package:pi_plugin/src/repositories/mappers/pi_persisted_user_text_codec.dart";
import "package:pi_plugin/src/trackers/pi_message_identity_tracker.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show maxTranscriptImageCandidates, maxTranscriptImageCollectionBytes;
import "package:test/test.dart";

void main() {
  const sessionId = "session";
  final mapper = _HydratedHistoryMapper(
    mapper: PiHistoryMapper(pluginId: "pi"),
    identities: PiMessageIdentityTracker(pluginId: "pi"),
  );

  group("PiPersistedUserTextCodec", () {
    test("cold-decodes only exact UTF-8 length-framed authored suffixes", () {
      const encoder = PiPersistedUserTextCodec();
      final persisted = encoder.encode(
        executionText: "private🙂 context\nauthoredé",
        userVisibleText: "authoredé",
      );

      expect(PiPersistedUserTextCodec.marker.codeUnits, everyElement(lessThan(128)));
      expect(
        const PiPersistedUserTextCodec().decodeVisibleText(persistedText: persisted),
        "authoredé",
      );
      expect(
        const PiPersistedUserTextCodec().decodeVisibleText(persistedText: "ordinary external Pi text"),
        "ordinary external Pi text",
      );
      expect(
        const PiPersistedUserTextCodec().decodeVisibleText(
          persistedText: "${PiPersistedUserTextCodec.marker}ordinary authored text",
        ),
        "${PiPersistedUserTextCodec.marker}ordinary authored text",
      );
      expect(
        const PiPersistedUserTextCodec().decodeVisibleText(
          persistedText: "${PiPersistedUserTextCodec.marker}1:99:forged",
        ),
        isEmpty,
      );
      expect(
        () => encoder.encode(executionText: "context", userVisibleText: "not a suffix"),
        throwsArgumentError,
      );
    });

    test("null and empty authored text suppress execution context", () {
      const codec = PiPersistedUserTextCodec();

      expect(
        codec.decodeVisibleText(
          persistedText: codec.encode(executionText: "private context", userVisibleText: null),
        ),
        isEmpty,
      );
      expect(
        codec.decodeVisibleText(
          persistedText: codec.encode(executionText: "private context", userVisibleText: ""),
        ),
        isEmpty,
      );
    });
  });

  group("PiMessageIdentityBuilder", () {
    test("shares timestamp and live-parity sentinels with deterministic ordinals", () {
      final first = PiMessageIdentityBuilder(pluginId: "pi", sessionId: sessionId);
      final second = PiMessageIdentityBuilder(pluginId: "pi", sessionId: sessionId);

      final firstIds = [
        first.next(role: PiMessageIdentityRole.user, timestamp: null),
        first.next(role: PiMessageIdentityRole.user, timestamp: null),
        first.nextCompaction(),
        first.nextTopLevelCustomMessage(),
      ];
      final secondIds = [
        second.next(role: PiMessageIdentityRole.user, timestamp: null),
        second.next(role: PiMessageIdentityRole.user, timestamp: null),
        second.nextCompaction(),
        second.nextTopLevelCustomMessage(),
      ];

      expect(firstIds, secondIds);
      expect(firstIds, [
        "pi:session:user:${PiMessageIdentityBuilder.missingTimestampSentinel}:1",
        "pi:session:user:${PiMessageIdentityBuilder.missingTimestampSentinel}:2",
        "pi:session:compaction:${PiMessageIdentityBuilder.compactionTimestampSentinel}:1",
        "pi:session:custom:${PiMessageIdentityBuilder.customMessageTimestampSentinel}:1",
      ]);
    });
  });

  group("PiHistoryMapper", () {
    test("maps active branch with equal-timestamp IDs independent of entry IDs", () {
      final first = mapper.map(
        sessionId: sessionId,
        entries: [
          _message(id: "root", parentId: null, message: _user("first", timestamp: 10)),
          _message(id: "abandoned", parentId: "root", message: _assistantText("abandoned", timestamp: 20)),
          _message(id: "second", parentId: "root", message: _user("second", timestamp: 10)),
          _message(id: "leaf", parentId: "second", message: _assistantText("active", timestamp: 20)),
        ],
        leafId: "leaf",
      );
      final second = mapper.map(
        sessionId: sessionId,
        entries: [
          _message(id: "changed-root", parentId: null, message: _user("first", timestamp: 10)),
          _message(id: "changed-second", parentId: "changed-root", message: _user("second", timestamp: 10)),
          _message(
            id: "changed-leaf",
            parentId: "changed-second",
            message: _assistantText("active", timestamp: 20),
          ),
        ],
        leafId: "changed-leaf",
      );

      expect(_texts(first), ["first", "second", "active"]);
      expect(first.map((message) => message.info.id), second.map((message) => message.info.id));
      expect(first[0].info.id, "pi:session:user:10:1");
      expect(first[1].info.id, "pi:session:user:10:2");
    });

    test("falls back only from a missing non-null leaf and bounds cycles", () async {
      final fallback = mapper.map(
        sessionId: sessionId,
        entries: [
          _message(id: "root", parentId: null, message: _user("root", timestamp: 1)),
          _message(id: "last", parentId: "root", message: _assistantText("last", timestamp: 2)),
        ],
        leafId: "missing",
      );
      final cyclic = mapper.map(
        sessionId: sessionId,
        entries: [
          _message(id: "cycle-a", parentId: "cycle-b", message: _user("a", timestamp: 1)),
          _message(id: "cycle-b", parentId: "cycle-a", message: _assistantText("b", timestamp: 2)),
        ],
        leafId: "cycle-b",
      );

      expect(_texts(fallback), ["root", "last"]);
      expect(_texts(cyclic), ["a", "b"]);
      expect(
        mapper.map(
          sessionId: sessionId,
          entries: [_message(id: "entry", parentId: null, message: _user("text", timestamp: 1))],
          leafId: null,
        ),
        isEmpty,
      );
    });

    test("retains pre-compaction history and maps sentinel card without summaries", () {
      const privateSummary = "private summary";
      final messages = mapper.map(
        sessionId: sessionId,
        entries: [
          _message(id: "user", parentId: null, message: _user("before", timestamp: 1)),
          PiSessionEntryDto.compaction(
            id: "compact",
            parentId: "user",
            timestamp: DateTime.fromMillisecondsSinceEpoch(2),
          ),
          _message(
            id: "summary",
            parentId: "compact",
            message: PiAgentMessageDto.fromJson({
              "role": "compactionSummary",
              "summary": privateSummary,
              "tokensBefore": 100,
              "timestamp": 3,
            }),
          ),
          _message(
            id: "branch-summary",
            parentId: "summary",
            message: PiAgentMessageDto.fromJson({
              "role": "branchSummary",
              "summary": privateSummary,
              "fromId": "user",
              "timestamp": 4,
            }),
          ),
        ],
        leafId: "branch-summary",
      );

      expect(messages, hasLength(2));
      expect(_texts(messages), ["before"]);
      expect(
        messages.last.info.id,
        "pi:session:compaction:${PiMessageIdentityBuilder.compactionTimestampSentinel}:1",
      );
      expect(messages.last.info.time, isNull);
      final compact = messages.last.parts.single;
      expect(compact.tool, "compact");
      expect(compact.state?.status, PluginToolStatus.completed);
      expect(compact.state?.title, "Context compacted");
      expect(compact.state?.output, isNull);
      expect(messages.toString(), isNot(contains(privateSummary)));
    });

    test("logs assistant failure locally and maps it privately", () async {
      const privateError = "secret provider payload";
      late List<PluginMessageWithParts> messages;
      final warnings = await _captureWarnings(() async {
        messages = mapper.map(
          sessionId: sessionId,
          entries: [
            _message(
              id: "failed",
              parentId: null,
              message: PiAgentMessageDto.fromJson({
                "role": "assistant",
                "content": [
                  {"type": "text", "text": "answer"},
                  {"type": "thinking", "thinking": "private reasoning", "redacted": true},
                  {"type": "thinking", "thinking": "visible reasoning", "redacted": false},
                  {"type": "toolCall", "id": "completed", "name": "read"},
                  {"type": "toolCall", "id": "unfinished", "name": "write"},
                ],
                "provider": "provider",
                "model": "model",
                "stopReason": "error",
                "errorMessage": privateError,
                "timestamp": 1,
              }),
            ),
            _message(
              id: "result",
              parentId: "failed",
              message: const PiAgentMessageDto.toolResult(
                toolCallId: "completed",
                toolName: "read",
                content: [PiContentDto.text(text: "result")],
                isError: false,
                timestamp: 2,
              ),
            ),
            _message(
              id: "aborted",
              parentId: "result",
              message: const PiAgentMessageDto.assistant(
                content: [PiContentDto.toolCall(id: "aborted-tool", name: "bash")],
                provider: null,
                model: null,
                stopReason: PiAssistantStopReason.aborted,
                errorMessage: null,
                timestamp: 3,
              ),
            ),
          ],
          leafId: "aborted",
        );
      });

      expect(messages, hasLength(2));
      expect(messages.first.info, isA<PluginMessageError>());
      expect(_reasoning(messages), ["visible reasoning"]);
      final completed = messages.first.parts.singleWhere((part) => part.id == "completed");
      final unfinished = messages.first.parts.singleWhere((part) => part.id == "unfinished");
      final aborted = messages.last.parts.single;
      expect(completed.state?.status, PluginToolStatus.completed);
      expect(completed.state?.output, "result");
      expect(unfinished.state?.status, PluginToolStatus.error);
      expect(unfinished.state?.error, "Pi tool call did not complete.");
      expect(aborted.state?.status, PluginToolStatus.error);
      expect(aborted.state?.error, "Pi tool call did not complete.");
      expect(messages.toString(), isNot(contains(privateError)));
      expect(messages.toString(), isNot(contains("private reasoning")));
      expect(warnings, contains(privateError));
    });

    test("enforces image candidate count", () {
      final content = [
        for (var index = 0; index < maxTranscriptImageCandidates + 1; index++)
          const PiContentDto.image(data: "YQ", mimeType: " IMAGE/PNG; charset=x "),
      ];
      final messages = mapper.map(
        sessionId: sessionId,
        entries: [
          _message(
            id: "user",
            parentId: null,
            message: PiAgentMessageDto.user(content: content, timestamp: 1),
          ),
        ],
        leafId: "user",
      );

      final attachments = messages.single.parts.map((part) => part.attachment).nonNulls.toList();
      expect(attachments, hasLength(maxTranscriptImageCandidates));
      expect(attachments, everyElement(isA<PluginMessageAttachmentInlineImage>()));
      expect((attachments.first as PluginMessageAttachmentInlineImage).mime, "image/png");
      expect((attachments.first as PluginMessageAttachmentInlineImage).base64, "YQ==");
    });

    test("enforces decoded aggregate image budget", () {
      final messages = mapper.map(
        sessionId: sessionId,
        entries: [
          _message(
            id: "user",
            parentId: null,
            message: PiAgentMessageDto.user(
              content: [for (var index = 0; index < 3; index++) _aggregateImage()],
              timestamp: 1,
            ),
          ),
        ],
        leafId: "user",
      );

      final attachments = messages.single.parts.map((part) => part.attachment).nonNulls.toList();
      expect(attachments.whereType<PluginMessageAttachmentInlineImage>(), hasLength(2));
      expect(attachments.whereType<PluginMessageAttachmentMetadata>(), hasLength(1));
    });

    test("resets aggregate image budget for user and each tool-result collection", () {
      final images = [_aggregateImage(), _aggregateImage()];
      final messages = mapper.map(
        sessionId: sessionId,
        entries: [
          _message(
            id: "user",
            parentId: null,
            message: PiAgentMessageDto.user(content: images, timestamp: 1),
          ),
          _message(
            id: "assistant",
            parentId: "user",
            message: const PiAgentMessageDto.assistant(
              content: [
                PiContentDto.toolCall(id: "tool-1", name: "read"),
                PiContentDto.toolCall(id: "tool-2", name: "write"),
              ],
              provider: null,
              model: null,
              stopReason: PiAssistantStopReason.stop,
              errorMessage: null,
              timestamp: 2,
            ),
          ),
          _message(
            id: "result-1",
            parentId: "assistant",
            message: PiAgentMessageDto.toolResult(
              toolCallId: "tool-1",
              toolName: "read",
              content: images,
              isError: false,
              timestamp: 3,
            ),
          ),
          _message(
            id: "result-2",
            parentId: "result-1",
            message: PiAgentMessageDto.toolResult(
              toolCallId: "tool-2",
              toolName: "write",
              content: images,
              isError: false,
              timestamp: 4,
            ),
          ),
        ],
        leafId: "result-2",
      );

      expect(
        messages.first.parts.map((part) => part.attachment).nonNulls,
        everyElement(isA<PluginMessageAttachmentInlineImage>()),
      );
      final tools = messages.last.parts.where((part) => part.type == PluginMessagePartType.tool);
      expect(tools, hasLength(2));
      for (final tool in tools) {
        expect(tool.state?.attachments, hasLength(2));
        expect(tool.state?.attachments, everyElement(isA<PluginMessageAttachmentInlineImage>()));
      }
    });

    test("cold-decodes hidden context and preserves unmarked external user text", () {
      const codec = PiPersistedUserTextCodec();
      final messages = mapper.map(
        sessionId: sessionId,
        entries: [
          _message(
            id: "wrapped",
            parentId: null,
            message: _user(
              codec.encode(executionText: "hidden context\nauthored", userVisibleText: "authored"),
              timestamp: 1,
            ),
          ),
          _message(
            id: "external",
            parentId: "wrapped",
            message: _user("genuine external text", timestamp: 2),
          ),
          _message(
            id: "suppressed",
            parentId: "external",
            message: _user(
              codec.encode(executionText: "hidden only", userVisibleText: null),
              timestamp: 3,
            ),
          ),
        ],
        leafId: "suppressed",
      );

      expect(_texts(messages), ["authored", "genuine external text"]);
      expect(messages.toString(), isNot(contains("hidden context")));
      expect(messages.toString(), isNot(contains("hidden only")));
    });

    test("uses message timestamp for custom role and sentinel for top-level custom messages", () {
      final messages = mapper.map(
        sessionId: sessionId,
        entries: [
          _message(
            id: "message-custom",
            parentId: null,
            message: const PiAgentMessageDto.custom(
              content: [PiContentDto.text(text: "message custom")],
              display: true,
              timestamp: 7,
            ),
          ),
          PiSessionEntryDto.customMessage(
            id: "top-custom-1",
            parentId: "message-custom",
            timestamp: DateTime.fromMillisecondsSinceEpoch(100),
            content: const [PiContentDto.text(text: "top custom one")],
            display: true,
          ),
          PiSessionEntryDto.customMessage(
            id: "top-custom-2",
            parentId: "top-custom-1",
            timestamp: DateTime.fromMillisecondsSinceEpoch(200),
            content: const [PiContentDto.text(text: "top custom two")],
            display: true,
          ),
        ],
        leafId: "top-custom-2",
      );

      expect(messages.map((message) => message.info.id), [
        "pi:session:custom:7:1",
        "pi:session:custom:${PiMessageIdentityBuilder.customMessageTimestampSentinel}:1",
        "pi:session:custom:${PiMessageIdentityBuilder.customMessageTimestampSentinel}:2",
      ]);
      expect(messages.first.info.time?.created, 7);
      expect(messages[1].info.time, isNull);
      expect(messages[2].info.time, isNull);
    });

    test("truncates bash output by runes and omits persisted output path", () {
      const privatePath = "/private/project/full-output.txt";
      final output = "🙂" * (maxToolOutputLength + 3);
      final bash = PiAgentMessageDto.fromJson({
        "role": "bashExecution",
        "command": "🙂" * (maxToolOutputLength + 10),
        "output": output,
        "exitCode": 0,
        "cancelled": false,
        "truncated": true,
        "fullOutputPath": privatePath,
        "timestamp": 8,
      });
      final messages = mapper.map(
        sessionId: sessionId,
        entries: [_message(id: "bash", parentId: null, message: bash)],
        leafId: "bash",
      );

      expect(messages.single.info.id, "pi:session:bashExecution:8:1");
      final part = messages.single.parts.single;
      expect(part.tool, "bash");
      expect(part.state?.output?.runes.length, maxToolOutputLength);
      expect(part.state?.title?.runes.length, maxToolOutputLength);
      expect(messages.toString(), isNot(contains(privatePath)));
    });

    test("uses null for silent bash output", () {
      const bash = PiAgentMessageDto.bashExecution(
        command: "true",
        output: "",
        exitCode: 0,
        cancelled: false,
        truncated: false,
        timestamp: 9,
      );

      final messages = mapper.map(
        sessionId: sessionId,
        entries: [_message(id: "silent", parentId: null, message: bash)],
        leafId: "silent",
      );

      expect(messages.single.parts.single.state?.output, isNull);
    });

    test("bounds combined tool-result text while preserving later attachments", () {
      const assistant = PiAgentMessageDto.assistant(
        content: [PiContentDto.toolCall(id: "call", name: "tool")],
        provider: "provider",
        model: "model",
        stopReason: PiAssistantStopReason.stop,
        errorMessage: null,
        timestamp: 1,
      );
      final result = PiAgentMessageDto.toolResult(
        toolCallId: "call",
        toolName: "tool",
        content: [
          PiContentDto.text(text: "x" * (maxToolOutputLength * 20)),
          const PiContentDto.image(data: "YQ==", mimeType: "image/png"),
        ],
        isError: false,
        timestamp: 2,
      );

      final messages = mapper.map(
        sessionId: sessionId,
        entries: [
          _message(id: "assistant", parentId: null, message: assistant),
          _message(id: "result", parentId: "assistant", message: result),
        ],
        leafId: "result",
      );

      final state = messages.single.parts.single.state!;
      expect(state.output?.runes.length, maxToolOutputLength);
      expect(state.attachments, hasLength(1));
    });

    test("bounds unknown diagnostics without payload logging", () async {
      const secret = "private-payload";
      final warnings = await _captureWarnings(() async {
        mapper.map(
          sessionId: sessionId,
          entries: [
            _message(
              id: "unknown-role",
              parentId: null,
              message: PiAgentMessageDto.fromJson({"role": "future", "timestamp": 1, "payload": secret}),
            ),
            _message(
              id: "unknown-block",
              parentId: "unknown-role",
              message: PiAgentMessageDto.user(
                content: [
                  PiContentDto.fromJson({"type": "future", "payload": secret}),
                  PiContentDto.fromJson({"type": "future", "payload": secret}),
                ],
                timestamp: 2,
              ),
            ),
            PiSessionEntryDto.custom(
              id: secret,
              parentId: "unknown-block",
              timestamp: DateTime.fromMillisecondsSinceEpoch(3),
            ),
            PiSessionEntryDto.unknown(
              id: "leaf",
              parentId: secret,
              timestamp: DateTime.fromMillisecondsSinceEpoch(4),
            ),
          ],
          leafId: "leaf",
        );
      });

      expect(RegExp("unknown message roles").allMatches(warnings), hasLength(1));
      expect(RegExp("unknown content blocks").allMatches(warnings), hasLength(1));
      expect(RegExp("unknown entry types").allMatches(warnings), hasLength(1));
      expect(warnings, isNot(contains(secret)));
    });

    test("bounds unknown assistant content warnings across the replay", () async {
      final warnings = await _captureWarnings(() async {
        mapper.map(
          sessionId: sessionId,
          entries: [
            for (var index = 0; index < 3; index++)
              _message(
                id: "assistant-$index",
                parentId: index == 0 ? null : "assistant-${index - 1}",
                message: PiAgentMessageDto.assistant(
                  content: [
                    PiContentDto.fromJson({"type": "future"}),
                  ],
                  provider: null,
                  model: null,
                  stopReason: PiAssistantStopReason.stop,
                  errorMessage: null,
                  timestamp: index,
                ),
              ),
          ],
          leafId: "assistant-2",
        );
      });

      expect(RegExp("unknown content blocks").allMatches(warnings), hasLength(1));
    });

    test("returns empty for no visible mapped content", () {
      final messages = mapper.map(
        sessionId: sessionId,
        entries: [
          PiSessionEntryDto.modelChange(
            id: "model",
            parentId: null,
            timestamp: DateTime.fromMillisecondsSinceEpoch(1),
          ),
          _message(
            id: "summary",
            parentId: "model",
            message: const PiAgentMessageDto.branchSummary(timestamp: 2),
          ),
        ],
        leafId: "summary",
      );

      expect(messages, isEmpty);
      expect(mapper.map(sessionId: sessionId, entries: const [], leafId: "missing"), isEmpty);
    });
  });
}

final class _HydratedHistoryMapper({
  required final PiHistoryMapper mapper,
  required final PiMessageIdentityTracker identities,
}) {
  List<PluginMessageWithParts> map({
    required String sessionId,
    required List<PiSessionEntryDto> entries,
    required String? leafId,
  }) => identities.hydrate(
    sessionId: sessionId,
    map: (identityBuilder) => mapper.map(
      sessionId: sessionId,
      entries: entries,
      leafId: leafId,
      identities: identityBuilder,
    ),
  );
}

final String _aggregateImageData = base64Encode(
  Uint8List(maxTranscriptImageCollectionBytes ~/ 3 + 1),
);

PiImageContentDto _aggregateImage() => PiContentDto.image(
  data: _aggregateImageData,
  mimeType: "image/png",
) as PiImageContentDto;

PiMessageEntryDto _message({
  required String id,
  required String? parentId,
  required PiAgentMessageDto message,
}) {
  return PiSessionEntryDto.message(
    id: id,
    parentId: parentId,
    timestamp: DateTime.fromMillisecondsSinceEpoch(message.timestamp ?? 0),
    message: message,
  ) as PiMessageEntryDto;
}

PiUserMessageDto _user(String text, {required int? timestamp}) {
  return PiAgentMessageDto.user(
    content: [PiContentDto.text(text: text)],
    timestamp: timestamp,
  ) as PiUserMessageDto;
}

PiAssistantMessageDto _assistantText(String text, {required int timestamp}) {
  return PiAgentMessageDto.assistant(
    content: [PiContentDto.text(text: text)],
    provider: null,
    model: null,
    stopReason: PiAssistantStopReason.stop,
    errorMessage: null,
    timestamp: timestamp,
  ) as PiAssistantMessageDto;
}

List<String> _texts(List<PluginMessageWithParts> messages) => [
  for (final message in messages)
    for (final part in message.parts)
      if (part.type == PluginMessagePartType.text) part.text!,
];

List<String> _reasoning(List<PluginMessageWithParts> messages) => [
  for (final message in messages)
    for (final part in message.parts)
      if (part.type == PluginMessagePartType.reasoning) part.text!,
];

Future<String> _captureWarnings(Future<void> Function() action) async {
  final previousLevel = Log.level;
  final stderr = _BufferingStdout();
  try {
    Log.level = LogLevel.warning;
    await IOOverrides.runZoned(action, stderr: () => stderr);
  } finally {
    Log.level = previousLevel;
  }
  return stderr.text;
}

final class _BufferingStdout() implements Stdout {
  final StringBuffer _buffer = StringBuffer();

  String get text => _buffer.toString();

  @override
  void writeln([Object? object = ""]) => _buffer.writeln(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
