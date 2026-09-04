import "dart:collection";
import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:claude_plugin/claude_plugin.dart";
import "package:sesori_plugin_interface/plugin_interface_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show maxTranscriptImageBytes;
import "package:test/test.dart";

void main() {
  group("ClaudeContentMapper", () {
    const mapper = ClaudeContentMapper();

    test("maps text and thinking while keeping the signature opaque", () {
      final mapped = mapper.map(
        content: [
          {"type": "text", "text": "answer"},
          {"type": "thinking", "thinking": "reasoning", "signature": "private-signature"},
        ],
      );

      expect((mapped[0] as ClaudeMappedTextContentBlock).text, "answer");
      expect((mapped[1] as ClaudeMappedThinkingContentBlock).thinking, "reasoning");
      expect(mapped.toString(), isNot(contains("private-signature")));
    });

    test("retains tool identities and arbitrary input for lifecycle tracking", () {
      final mapped =
          mapper
                  .map(
                    content: {
                      "type": "tool_use",
                      "id": "toolu-1",
                      "name": "Write",
                      "input": {"file_path": "/private/source.dart", "content": "secret"},
                    },
                  )
                  .single
              as ClaudeMappedToolUseContentBlock;

      expect(mapped.id, "toolu-1");
      expect(mapped.name, "Write");
      expect(mapped.input, {"file_path": "/private/source.dart", "content": "secret"});
      expect(mapped.toString(), isNot(contains("private/source.dart")));
    });

    test("generated DTO strings do not expose content payloads", () {
      final dto = ClaudeContentBlockDto.fromJson({
        "type": "tool_use",
        "id": "toolu-1",
        "name": "Write",
        "input": {"content": "private-tool-input"},
      });
      final image = ClaudeImageSourceDto.fromJson({
        "type": "base64",
        "media_type": "image/png",
        "data": "private-base64-data",
      });

      expect(dto.toString(), isNot(contains("private-tool-input")));
      expect(image.toString(), isNot(contains("private-base64-data")));
    });

    test("maps successful and failed tool results with nested blocks", () {
      final success =
          mapper
                  .map(
                    content: {
                      "type": "tool_result",
                      "tool_use_id": "toolu-1",
                      "content": [
                        {"type": "text", "text": "one "},
                        {"type": "text", "text": "two"},
                        _image(data: "AA=="),
                      ],
                      "is_error": false,
                    },
                  )
                  .single
              as ClaudeMappedToolResultContentBlock;
      final failure =
          mapper
                  .map(
                    content: {
                      "type": "tool_result",
                      "tool_use_id": "toolu-2",
                      "content": "failed",
                      "is_error": true,
                    },
                  )
                  .single
              as ClaudeMappedToolResultContentBlock;

      expect(success.toolUseId, "toolu-1");
      expect(success.output, "one two");
      expect(success.isError, isFalse);
      expect(success.attachments.single, isA<PluginMessageAttachmentInlineImage>());
      expect(failure.output, "failed");
      expect(failure.isError, isTrue);
    });

    test("bounds tool output to exactly 500 Unicode code points", () {
      final output = List.filled(maxToolOutputLength + 20, "😀").join();
      final mapped =
          mapper
                  .map(
                    content: {
                      "type": "tool_result",
                      "tool_use_id": "toolu-1",
                      "content": output,
                    },
                  )
                  .single
              as ClaudeMappedToolResultContentBlock;

      expect(mapped.output!.runes, hasLength(maxToolOutputLength));
      expect(mapped.output, List.filled(maxToolOutputLength, "😀").join());
    });

    test("maps standard blocks to backend-neutral parts", () {
      final parts = mapper.mapParts(
        sessionId: "session-1",
        messageId: "message-1",
        content: [
          {"type": "text", "text": "answer"},
          {"type": "thinking", "thinking": "reasoning", "signature": null},
          {"type": "tool_use", "id": "toolu-1", "name": "Read", "input": const <String, Object?>{}},
          _image(data: "AA=="),
        ],
      );

      expect(parts.map((part) => part.type), [
        PluginMessagePartType.text,
        PluginMessagePartType.reasoning,
        PluginMessagePartType.tool,
        PluginMessagePartType.file,
      ]);
      expect(parts[0].text, "answer");
      expect(parts[1].text, "reasoning");
      expect(parts[2].id, "toolu-1");
      expect(parts[2].tool, "Read");
      expect(parts[2].state.status, PluginToolStatus.pending);
      expect(parts[3].attachment, isA<PluginMessageAttachmentInlineImage>());
      expect(parts, everyElement(predicate<PluginMessagePart>((part) => part.sessionID == "session-1")));
      expect(parts, everyElement(predicate<PluginMessagePart>((part) => part.messageID == "message-1")));
    });

    test("retains only explicit Bash commands as shell command data", () {
      final parts = mapper.mapParts(
        sessionId: "session-1",
        messageId: "message-1",
        content: [
          {
            "type": "tool_use",
            "id": "toolu-bash",
            "name": "Bash",
            "input": {"command": "git diff --stat", "description": "inspect changes"},
          },
          {
            "type": "tool_use",
            "id": "toolu-read",
            "name": "Read",
            "input": {"command": "must not leak"},
          },
        ],
      );

      expect(parts[0].state.shellCommand, "git diff --stat");
      expect(parts[1].state.shellCommand, isNull);
    });

    test("maps tool result state without inventing a tool name", () {
      final success = mapper
          .mapParts(
            sessionId: "session-1",
            messageId: "message-1",
            content: {"type": "tool_result", "tool_use_id": "toolu-1", "content": "done"},
          )
          .single;
      final failure = mapper
          .mapParts(
            sessionId: "session-1",
            messageId: "message-2",
            content: {
              "type": "tool_result",
              "tool_use_id": "toolu-2",
              "content": "boom",
              "is_error": true,
            },
          )
          .single;

      expect(success.tool, isNull);
      expect(success.state.status, PluginToolStatus.completed);
      expect(success.state.output, "done");
      expect(success.state.error, isNull);
      expect(failure.state.status, PluginToolStatus.error);
      expect(failure.state.output, isNull);
      expect(failure.state.error, "boom");
    });

    test("normalizes supported base64 images", () {
      for (final mime in ["image/gif", "IMAGE/JPEG", "image/png", "image/webp"]) {
        final mapped =
            mapper
                    .map(
                      content: _image(data: "AA", mime: mime),
                    )
                    .single
                as ClaudeMappedImageContentBlock;
        final attachment = mapped.attachment as PluginMessageAttachmentInlineImage;

        expect(attachment.mime, mime.toLowerCase());
        expect(attachment.base64, "AA==");
        expect(attachment.filename, isNull);
      }
    });

    test("degrades malformed, unsupported, and oversized images to metadata", () {
      final oversized = base64Encode(Uint8List(maxTranscriptImageBytes + 1));
      final mapped = mapper.map(
        content: [
          _image(data: "not base64"),
          _image(data: "AA==", mime: "image/svg+xml"),
          _image(data: oversized),
          {"type": "image", "source": "not-an-object"},
        ],
      );

      expect(
        mapped.map((block) => (block as ClaudeMappedImageContentBlock).attachment),
        everyElement(isA<PluginMessageAttachmentMetadata>()),
      );
    });

    test("bounds untrusted image MIME metadata", () {
      final mapped =
          mapper
                  .map(
                    content: _image(data: "AA==", mime: "X" * 300),
                  )
                  .single
              as ClaudeMappedImageContentBlock;

      expect(mapped.attachment.mime, "x" * 255);
      expect(mapped.attachment, isA<PluginMessageAttachmentMetadata>());
    });

    test("enforces the image budget across one mapped message", () {
      final image = base64Encode(Uint8List(17 * 1024 * 1024));
      final mapped = mapper.map(
        content: [
          _image(data: image),
          _image(data: image),
          _image(data: image),
        ],
      );

      expect((mapped[0] as ClaudeMappedImageContentBlock).attachment, isA<PluginMessageAttachmentInlineImage>());
      expect((mapped[1] as ClaudeMappedImageContentBlock).attachment, isA<PluginMessageAttachmentInlineImage>());
      expect((mapped[2] as ClaudeMappedImageContentBlock).attachment, isA<PluginMessageAttachmentMetadata>());
    });

    test("drops excess images without shifting or dropping later content", () {
      final parts = mapper.mapParts(
        sessionId: "session-1",
        messageId: "message-1",
        content: [
          for (var index = 0; index < 5; index++) _image(data: "AA=="),
          {"type": "text", "text": "after images"},
        ],
      );

      expect(parts, hasLength(6));
      expect(
        parts.take(4),
        everyElement(isA<PluginMessagePart>().having((part) => part.type, "type", PluginMessagePartType.file)),
      );
      expect(parts[4].type, PluginMessagePartType.unknown);
      expect(parts[5].id, "message-1-block-5");
      expect(parts[5].text, "after images");
    });

    test("absorbs redacted, future, and malformed blocks without exposing payloads", () {
      late final List<ClaudeMappedContentBlock> mapped;
      final warnings = _captureWarnings(() {
        mapped = mapper.map(
          content: [
            {"type": "redacted_thinking", "data": "private-redacted-data"},
            {"type": "future_block", "payload": "private-future-data"},
            {"type": "text", "text": 42, "payload": "private-malformed-data"},
            _ThrowingCastMap({"type": "text", "text": "private-cast-payload"}),
          ],
        );
      });

      expect(mapped[0], isA<ClaudeMappedUnsupportedContentBlock>());
      expect(mapped.skip(1), everyElement(isA<ClaudeMappedUnknownContentBlock>()));
      expect(mapped.toString(), isNot(contains("private-redacted-data")));
      expect(mapped.toString(), isNot(contains("private-future-data")));
      expect(mapped.toString(), isNot(contains("private-malformed-data")));
      expect(warnings, contains("[claude] content block decode failed"));
      expect(warnings, isNot(contains("private-malformed-data")));
      expect(warnings, isNot(contains("private-cast-payload")));
      expect(warnings, isNot(contains("private-decode-error")));
      expect(
        mapper.mapParts(sessionId: "session-1", messageId: "message-1", content: {"type": "future_block"}).single.type,
        PluginMessagePartType.unknown,
      );
    });
  });
}

Map<String, Object?> _image({required String data, String mime = "image/png"}) => {
  "type": "image",
  "source": {"type": "base64", "media_type": mime, "data": data},
};

String _captureWarnings(void Function() action) {
  final previousLevel = Log.level;
  final stderr = BufferingStdout();
  try {
    Log.level = LogLevel.warning;
    IOOverrides.runZoned(action, stderr: () => stderr);
  } finally {
    Log.level = previousLevel;
  }
  return stderr.text;
}

class _ThrowingCastMap(final Map<Object?, Object?> _values) extends MapBase<Object?, Object?> {
  @override
  Object? operator [](Object? key) => _values[key];

  @override
  void operator []=(Object? key, Object? value) => _values[key] = value;

  @override
  Iterable<Object?> get keys => _values.keys;

  @override
  void clear() => _values.clear();

  @override
  Object? remove(Object? key) => _values.remove(key);

  @override
  Map<RK, RV> cast<RK, RV>() => throw const FormatException("private-decode-error");
}
