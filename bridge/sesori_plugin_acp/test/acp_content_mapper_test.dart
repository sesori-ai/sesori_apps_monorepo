import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show maxInlineMessageAttachmentBytes;
import "package:test/test.dart";

void main() {
  group("AcpContentMapper", () {
    const mapper = AcpContentMapper();

    test("preserves standard and legacy text while flattening lists", () {
      expect(
        mapper.text(
          content: [
            {"type": "text", "text": "standard "},
            "legacy ",
            [
              {"type": "text", "text": "nested"},
            ],
          ],
        ),
        "standard legacy nested",
      );
      expect(mapper.text(content: {"type": "text", "text": ""}), isNull);
    });

    test("preserves untyped, future, and wrapped text after known variant parsing", () {
      expect(mapper.text(content: {"text": "untyped"}), "untyped");
      expect(
        mapper.text(content: {"type": "future_block", "text": "future"}),
        "future",
      );
      expect(
        mapper.text(
          content: {
            "type": "content",
            "content": {"type": "text", "text": "wrapped"},
          },
        ),
        "wrapped",
      );

      final knownImage = mapper.map(
        content: {
          "type": "image",
          "data": "AA==",
          "mimeType": "image/png",
          "uri": null,
          "text": "must not bypass image validation",
        },
      );
      expect(knownImage.single, isA<AcpMappedInlineImageContentBlock>());
    });

    test("allows the bounded raster MIME set and retains only a URI basename", () {
      for (final mime in [
        "image/bmp",
        "image/gif",
        "IMAGE/JPEG; charset=binary",
        "image/png",
        "image/webp",
      ]) {
        final mapped =
            mapper
                    .map(
                      content: {
                        "type": "image",
                        "data": "AA",
                        "mimeType": " $mime ",
                        "uri": "https://secret.example/private/output.png?token=credential",
                      },
                    )
                    .single
                as AcpMappedInlineImageContentBlock;

        expect(mapped.attachment.mime, mime.trim().toLowerCase());
        expect(mapped.attachment.base64, "AA==");
        expect(mapped.attachment.filename, "output.png");
        expect(mapped.decodedBytes, 1);
        expect(mapped.toString(), isNot(contains("secret.example")));
        expect(mapped.toString(), isNot(contains("credential")));
      }
    });

    test("degrades invalid, unsupported, and oversized images to metadata", () {
      final oversized = base64Encode(Uint8List(maxInlineMessageAttachmentBytes + 1));
      final mapped = mapper.map(
        content: [
          {
            "type": "image",
            "data": "not base64",
            "mimeType": "image/png",
            "uri": "file:///private/invalid.png",
          },
          {
            "type": "image",
            "data": "AA==",
            "mimeType": "image/svg+xml",
            "uri": "file:///private/vector.svg",
          },
          {
            "type": "image",
            "data": oversized,
            "mimeType": "image/png",
            "uri": null,
          },
        ],
      );

      final invalid = mapped[0] as AcpMappedMetadataImageContentBlock;
      final unsupported = mapped[1] as AcpMappedMetadataImageContentBlock;
      final tooLarge = mapped[2] as AcpMappedMetadataImageContentBlock;
      expect(invalid.reason, AcpImageDegradationReason.invalid);
      expect(invalid.attachment.filename, "invalid.png");
      expect(unsupported.reason, AcpImageDegradationReason.unsupported);
      expect(unsupported.attachment.mime, "image/svg+xml");
      expect(unsupported.attachment.filename, "vector.svg");
      expect(tooLarge.reason, AcpImageDegradationReason.oversized);
    });

    test("does not derive metadata filenames from opaque URIs", () {
      for (final uri in ["data:text/plain,secret", "mailto:secret@example.com"]) {
        final mapped =
            mapper
                    .map(
                      content: {
                        "type": "image",
                        "data": "not base64",
                        "mimeType": "image/png",
                        "uri": uri,
                      },
                    )
                    .single
                as AcpMappedMetadataImageContentBlock;

        expect(mapped.attachment.filename, isNull);
      }
    });

    test("separates known unsupported and future content variants", () {
      final mapped = mapper.map(
        content: [
          {"type": "audio", "data": "private audio", "mimeType": "audio/wav"},
          {
            "type": "resource",
            "resource": {"uri": "file:///private/source.dart", "text": "private source"},
          },
          {"type": "resource_link", "uri": "file:///private/source.dart", "name": "source.dart"},
          {"type": "future_block", "private": "future payload"},
        ],
      );

      expect(mapped.take(3), everyElement(isA<AcpMappedUnsupportedContentBlock>()));
      expect(mapped.last, isA<AcpMappedUnknownContentBlock>());
      expect(
        mapper.text(
          content: {"type": "audio", "data": "private audio", "mimeType": "audio/wav"},
        ),
        isNull,
      );
    });

    test("malformed known blocks recover with one privacy-safe warning", () {
      late List<AcpMappedContentBlock> mapped;
      final output = _captureWarnings(() {
        mapped = mapper.map(
          content: [
            {"type": "text", "text": 42, "private": "secret text"},
            {"type": "image", "mimeType": "image/png", "uri": "file:///private/secret.png"},
          ],
        );
      });

      expect(mapped, hasLength(2));
      expect(mapped, everyElement(isA<AcpMappedUnknownContentBlock>()));
      expect("malformed content block".allMatches(output), hasLength(1));
      expect(output, isNot(contains("secret text")));
      expect(output, isNot(contains("secret.png")));
      expect(output, isNot(contains("type cast")));
    });

    test("a mapping scope deduplicates malformed warnings across chunks", () {
      final scope = AcpContentMappingScope();
      final output = _captureWarnings(() {
        for (var index = 0; index < 2; index++) {
          mapper.mapScoped(
            content: {"type": "text", "text": 42, "private": "secret"},
            scope: scope,
          );
        }
      });

      expect("malformed content block".allMatches(output), hasLength(1));
      expect(output, isNot(contains("secret")));
    });

    test("maps tool identity and status with fail-soft defaults", () {
      expect(mapper.toolName(update: {"kind": "read", "title": "Read file"}), "read");
      expect(mapper.toolName(update: {"kind": "", "title": "Read file"}), "Read file");
      expect(mapper.toolName(update: {"kind": 42, "title": null}), "tool");

      expect(mapper.toolStatus(status: "pending"), PluginToolStatus.pending);
      expect(mapper.toolStatus(status: "in_progress"), PluginToolStatus.running);
      expect(mapper.toolStatus(status: "completed"), PluginToolStatus.completed);
      expect(mapper.toolStatus(status: "failed"), PluginToolStatus.error);
      expect(mapper.toolStatus(status: "future"), isNull);
    });

    test("maps typed tool content text and diff while ignoring terminal and unknown variants", () {
      final mapped = mapper.toolContent(
        update: {
          "content": [
            {
              "type": "content",
              "content": {"type": "text", "text": "one "},
            },
            {
              "type": "diff",
              "path": "/private/source.dart",
              "oldText": "old",
              "newText": "new",
            },
            {"type": "terminal", "terminalId": "private-terminal"},
            {"type": "future", "private": "secret"},
            {
              "type": "content",
              "content": {
                "type": "image",
                "data": "AA==",
                "mimeType": "image/png",
                "uri": null,
              },
            },
            {
              "type": "content",
              "content": {"type": "text", "text": "two"},
            },
          ],
          "rawOutput": "must not replace standard content",
        },
      );

      expect(mapped, isA<AcpReplaceToolContentMutation>());
      final replacement = mapped as AcpReplaceToolContentMutation;
      expect(replacement.output, "one two");
      expect(replacement.hasDiff, isTrue);
      expect(replacement.imageCandidates, hasLength(1));
      expect(replacement.imageCandidates.single, isA<AcpMappedInlineImageContentBlock>());
      expect(mapped.toString(), isNot(contains("private-terminal")));
      expect(mapped.toString(), isNot(contains("source.dart")));
      expect(mapped.toString(), isNot(contains("secret")));
    });

    test("bounds tool images before scanning trailing text and diff content", () {
      late AcpReplaceToolContentMutation replacement;
      final output = _captureWarnings(() {
        replacement =
            mapper.toolContent(
                  update: {
                    "content": [
                      for (var index = 0; index < 5; index++)
                        {
                          "type": "content",
                          "content": {
                            "type": "image",
                            "data": "AA==",
                            "mimeType": "image/png",
                            "uri": "file:///private/image-$index.png",
                          },
                        },
                      {
                        "type": "content",
                        "content": {"type": "text", "text": "after images"},
                      },
                      {
                        "type": "diff",
                        "path": "/private/source.dart",
                        "oldText": "old",
                        "newText": "new",
                      },
                    ],
                  },
                )
                as AcpReplaceToolContentMutation;
      });

      expect(replacement.imageCandidates, hasLength(4));
      expect(replacement.output, "after images");
      expect(replacement.hasDiff, isTrue);
      expect("exceeds the count limit".allMatches(output), hasLength(1));
      expect(output, isNot(contains("source.dart")));
      expect(output, isNot(contains("image-4.png")));
    });

    test("preserves legacy tool text and bounded raw-output fallbacks", () {
      expect(
        mapper.toolContent(
          update: {
            "content": [
              {"text": "legacy"},
              {"type": "diff"},
            ],
          },
        ),
        isA<AcpReplaceToolContentMutation>()
            .having((content) => content.output, "output", "legacy")
            .having((content) => content.hasDiff, "hasDiff", isTrue),
      );
      expect(
        (mapper.toolContent(
                  update: {
                    "rawOutput": {"stdout": "out\n", "stderr": "error\n"},
                  },
                )
                as AcpUpdateToolOutputMutation)
            .output,
        "out\nerror",
      );
      expect(
        (mapper.toolContent(
                  update: {
                    "rawOutput": {
                      "content": {"type": "text", "text": "nested\n"},
                    },
                  },
                )
                as AcpUpdateToolOutputMutation)
            .output,
        "nested",
      );
      expect(
        (mapper.toolContent(
                  update: {
                    "rawOutput": {"exitCode": 7},
                  },
                )
                as AcpUpdateToolOutputMutation)
            .output,
        "exited with code 7",
      );

      final oversized = "x" * (maxToolOutputLength + 1);
      expect(
        (mapper.toolContent(update: {"rawOutput": oversized}) as AcpUpdateToolOutputMutation).output,
        "${"x" * maxToolOutputLength}…",
      );

      final unicode = "${"x" * (maxToolOutputLength - 1)}😀z";
      expect(
        (mapper.toolContent(update: {"rawOutput": unicode}) as AcpUpdateToolOutputMutation).output,
        "${"x" * (maxToolOutputLength - 1)}😀…",
      );
    });

    test("distinguishes replacement, raw-output update, and omission", () {
      expect(
        mapper.toolContent(update: const {}),
        isA<AcpUnchangedToolContentMutation>(),
      );
      expect(
        mapper.toolContent(update: {"rawOutput": ""}),
        isA<AcpUpdateToolOutputMutation>().having(
          (mutation) => mutation.output,
          "output",
          isNull,
        ),
      );
      expect(
        mapper.toolContent(update: {"rawOutput": {"stdout": 42}}),
        isA<AcpUnchangedToolContentMutation>(),
      );
      expect(
        mapper.toolContent(update: {"rawOutput": {"content": 42}}),
        isA<AcpUnchangedToolContentMutation>(),
      );
      expect(
        mapper.toolContent(update: {"rawOutput": {"stdout": 42, "stderr": "usable"}}),
        isA<AcpUpdateToolOutputMutation>().having(
          (mutation) => mutation.output,
          "output",
          "usable",
        ),
      );
      expect(
        mapper.toolContent(update: {"content": const <Object?>[]}),
        isA<AcpReplaceToolContentMutation>()
            .having((mutation) => mutation.output, "output", isNull)
            .having(
              (mutation) => mutation.imageCandidates,
              "imageCandidates",
              isEmpty,
            )
            .having((mutation) => mutation.hasDiff, "hasDiff", isFalse),
      );

      final imageOnly =
          mapper.toolContent(
                update: {
                  "content": [
                    {
                      "type": "content",
                      "content": {
                        "type": "image",
                        "data": "AA==",
                        "mimeType": "image/png",
                        "uri": null,
                      },
                    },
                  ],
                },
              )
              as AcpReplaceToolContentMutation;
      expect(imageOnly.output, isNull);
      expect(imageOnly.imageCandidates, hasLength(1));
    });

    test("rejects malformed top-level tool content but preserves legacy containers", () {
      expect(
        mapper.toolContent(update: {"content": 42}),
        isA<AcpUnchangedToolContentMutation>(),
      );
      for (final content in <Object>[
        "legacy",
        {"text": "legacy"},
        [
          {"text": "legacy"},
        ],
      ]) {
        expect(
          (mapper.toolContent(update: {"content": content}) as AcpReplaceToolContentMutation).output,
          "legacy",
        );
      }
    });

    test("uses raw output only when replacement content has no text", () {
      final withText =
          mapper.toolContent(
                update: {
                  "content": [
                    {
                      "type": "content",
                      "content": {"type": "text", "text": "standard"},
                    },
                  ],
                  "rawOutput": "fallback",
                },
              )
              as AcpReplaceToolContentMutation;
      final imageOnly =
          mapper.toolContent(
                update: {
                  "content": [
                    {
                      "type": "content",
                      "content": {
                        "type": "image",
                        "data": "AA==",
                        "mimeType": "image/png",
                        "uri": null,
                      },
                    },
                  ],
                  "rawOutput": "fallback",
                },
              )
              as AcpReplaceToolContentMutation;

      expect(withText.output, "standard");
      expect(imageOnly.output, "fallback");
    });
  });
}

String _captureWarnings(void Function() action) {
  final previousLevel = Log.level;
  final stderr = _BufferingStdout();
  try {
    Log.level = LogLevel.warning;
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
