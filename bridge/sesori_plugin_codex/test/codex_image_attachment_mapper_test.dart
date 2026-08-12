import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:codex_plugin/src/repositories/mappers/codex_image_attachment_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show maxTranscriptImageBytes;
import "package:test/test.dart";

void main() {
  group("CodexImageAttachmentMapper", () {
    const mapper = CodexImageAttachmentMapper();

    test("allows the bounded raster MIME set and normalizes filenames", () {
      for (final mime in [
        "image/bmp",
        "image/gif",
        "IMAGE/JPEG; charset=binary",
        "image/png",
        "image/webp",
      ]) {
        final attachment = mapper
            .map(
              candidates: [
                CodexImageAttachmentCandidate.base64(
                  data: "AA==",
                  mime: " $mime ",
                  filenameHint: r" C:\private\render.png ",
                ),
              ],
            )
            .single;

        expect(attachment, isA<PluginMessageAttachmentInlineImage>());
        final image = attachment as PluginMessageAttachmentInlineImage;
        expect(image.mime, mime.trim().toLowerCase());
        expect(image.filename, "render.png");
        expect(image.base64, "AA==");
      }
    });

    test("normalizes supported base64 and data URL forms", () {
      final attachments = mapper.map(
        candidates: const [
          CodexImageAttachmentCandidate.base64(
            data: "AA",
            mime: "image/png",
            filenameHint: null,
          ),
          CodexImageAttachmentCandidate.base64(
            data: "-_8=",
            mime: "image/png",
            filenameHint: null,
          ),
          CodexImageAttachmentCandidate.base64(
            data: "%2BA%3D%3D",
            mime: "image/png",
            filenameHint: null,
          ),
          CodexImageAttachmentCandidate.imageUrl(
            imageUrl: "DATA:image/png;BASE64,AA==",
          ),
        ],
      );

      expect(
        attachments.map((attachment) => (attachment as PluginMessageAttachmentInlineImage).base64),
        ["AA==", "+/8=", "+A==", "AA=="],
      );
    });

    test("rejects malformed base64 and bounded data URL headers", () {
      final attachments = mapper.map(
        candidates: [
          for (final data in ["A", "A===", "AA=A", "AA\n=="])
            CodexImageAttachmentCandidate.base64(
              data: data,
              mime: "image/png",
              filenameHint: null,
            ),
        ],
      );
      final oversizedHeader = mapper
          .map(
            candidates: [
              CodexImageAttachmentCandidate.imageUrl(
                imageUrl: "data:${"a" * 257};base64,AA==",
              ),
            ],
          )
          .single;

      expect(attachments, everyElement(isA<PluginMessageAttachmentMetadata>()));
      expect(oversizedHeader, isA<PluginMessageAttachmentMetadata>());
    });

    test("converts invalid, unsupported, and remote candidates to metadata", () {
      final attachments = mapper.map(
        candidates: const [
          CodexImageAttachmentCandidate.base64(
            data: "not base64",
            mime: "image/png",
            filenameHint: null,
          ),
          CodexImageAttachmentCandidate.base64(
            data: "AA==",
            mime: "image/svg+xml",
            filenameHint: null,
          ),
          CodexImageAttachmentCandidate.imageUrl(
            imageUrl: "https://example.com/private/output.png?token=secret",
          ),
          CodexImageAttachmentCandidate.imageUrl(
            imageUrl: "data:image/png,not-base64",
          ),
        ],
      );

      expect(attachments, everyElement(isA<PluginMessageAttachmentMetadata>()));
      final remote = attachments[2] as PluginMessageAttachmentMetadata;
      expect(remote.mime, "application/octet-stream");
      expect(remote.filename, "output.png");
    });

    test("the bounded prefix consumes invalid slots and drops later images", () {
      final attachments = mapper.map(
        candidates: [
          const CodexImageAttachmentCandidate.base64(
            data: "invalid payload",
            mime: "image/png",
            filenameHint: null,
          ),
          for (var index = 0; index < 4; index++)
            const CodexImageAttachmentCandidate.base64(
              data: "AA==",
              mime: "image/png",
              filenameHint: null,
            ),
        ],
      );

      expect(attachments, hasLength(4));
      expect(attachments.first, isA<PluginMessageAttachmentMetadata>());
      expect(attachments.skip(1), everyElement(isA<PluginMessageAttachmentInlineImage>()));
    });

    test("drops excess candidates before inspecting their payload", () {
      final output = _captureWarnings(() {
        mapper.map(
          candidates: [
            for (var index = 0; index < 4; index++)
              const CodexImageAttachmentCandidate.base64(
                data: "AA==",
                mime: "image/png",
                filenameHint: null,
              ),
            const CodexImageAttachmentCandidate.base64(
              data: "private invalid payload",
              mime: "image/svg+xml",
              filenameHint: "/private/secret.svg",
            ),
          ],
        );
      });

      expect(output, contains("count limit"));
      expect(output, isNot(contains("invalid image attachment")));
      expect(output, isNot(contains("unsupported image attachment")));
      expect(output, isNot(contains("private")));
    });

    test("enforces individual and aggregate decoded byte limits", () {
      final seventeenMiB = base64Encode(Uint8List(17 * 1024 * 1024));
      final tooLarge = base64Encode(Uint8List(maxTranscriptImageBytes + 1));
      final attachments = mapper.map(
        candidates: [
          CodexImageAttachmentCandidate.base64(
            data: seventeenMiB,
            mime: "image/png",
            filenameHint: null,
          ),
          CodexImageAttachmentCandidate.base64(
            data: seventeenMiB,
            mime: "image/png",
            filenameHint: null,
          ),
          CodexImageAttachmentCandidate.base64(
            data: seventeenMiB,
            mime: "image/png",
            filenameHint: null,
          ),
          CodexImageAttachmentCandidate.base64(
            data: tooLarge,
            mime: "image/png",
            filenameHint: null,
          ),
        ],
      );

      expect(attachments[0], isA<PluginMessageAttachmentInlineImage>());
      expect(attachments[1], isA<PluginMessageAttachmentInlineImage>());
      expect(attachments[2], isA<PluginMessageAttachmentMetadata>());
      expect(attachments[3], isA<PluginMessageAttachmentMetadata>());
    });

    test("reapplies count and byte limits when mapped batches merge", () {
      final seventeenMiB = base64Encode(Uint8List(17 * 1024 * 1024));
      final oversized = base64Encode(Uint8List(maxTranscriptImageBytes + 1));
      final bounded = mapper.boundMappedAttachments(
        attachments: [
          PluginMessageAttachment.inlineImage(
            mime: "image/png",
            base64: oversized,
            filename: "oversized.png",
          ),
          PluginMessageAttachment.inlineImage(
            mime: "image/png",
            base64: seventeenMiB,
            filename: "first.png",
          ),
          PluginMessageAttachment.inlineImage(
            mime: "image/png",
            base64: seventeenMiB,
            filename: "second.png",
          ),
          PluginMessageAttachment.inlineImage(
            mime: "image/png",
            base64: seventeenMiB,
            filename: "third.png",
          ),
          for (var index = 0; index < 4; index++)
            PluginMessageAttachment.metadata(
              mime: "image/png",
              filename: "metadata-$index.png",
            ),
        ],
      );

      expect(bounded, hasLength(4));
      expect(bounded[0], isA<PluginMessageAttachmentMetadata>());
      expect(bounded[1], isA<PluginMessageAttachmentInlineImage>());
      expect(bounded[2], isA<PluginMessageAttachmentInlineImage>());
      expect(bounded[3], isA<PluginMessageAttachmentMetadata>());
      expect(
        (bounded[3] as PluginMessageAttachmentMetadata).filename,
        "third.png",
      );
    });

    test("deduplicates privacy-safe warnings per collection and reason", () {
      late List<PluginMessageAttachment> attachments;
      final output = _captureWarnings(() {
        attachments = mapper.map(
          candidates: const [
            CodexImageAttachmentCandidate.base64(
              data: "private invalid payload",
              mime: "image/png",
              filenameHint: "/private/secret.png",
            ),
            CodexImageAttachmentCandidate.base64(
              data: "another private invalid payload",
              mime: "image/png",
              filenameHint: "secret-2.png",
            ),
            CodexImageAttachmentCandidate.imageUrl(
              imageUrl: "https://secret.example/private.png?token=credential",
            ),
            CodexImageAttachmentCandidate.imageUrl(
              imageUrl: "file:///private/secret.png",
            ),
            CodexImageAttachmentCandidate.base64(
              data: "AA==",
              mime: "image/png",
              filenameHint: "dropped-secret.png",
            ),
          ],
        );
      });

      expect(attachments, hasLength(4));
      expect("invalid image attachment".allMatches(output), hasLength(1));
      expect("unsupported image attachment".allMatches(output), hasLength(1));
      expect("count limit".allMatches(output), hasLength(1));
      for (final secret in [
        "private invalid payload",
        "secret.example",
        "/private/secret.png",
        "credential",
        "FormatException",
      ]) {
        expect(output, isNot(contains(secret)));
      }
    });

    test("warning deduplication resets for each collection", () {
      final output = _captureWarnings(() {
        for (var collection = 0; collection < 2; collection++) {
          mapper.map(
            candidates: const [
              CodexImageAttachmentCandidate.base64(
                data: "invalid payload",
                mime: "image/png",
                filenameHint: null,
              ),
            ],
          );
        }
      });

      expect("invalid image attachment".allMatches(output), hasLength(2));
    });

    test("candidate and attachment strings do not expose encoded data", () {
      const secret = "private-encoded-payload";
      const candidate = CodexImageAttachmentCandidate.base64(
        data: secret,
        mime: "image/png",
        filenameHint: null,
      );
      final attachment = mapper
          .map(
            candidates: const [
              CodexImageAttachmentCandidate.base64(
                data: "AA==",
                mime: "image/png",
                filenameHint: null,
              ),
            ],
          )
          .single;

      expect(candidate.toString(), isNot(contains(secret)));
      expect(attachment.toString(), isNot(contains("AA==")));
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

class _BufferingStdout implements Stdout {
  final StringBuffer _buffer = StringBuffer();

  String get text => _buffer.toString();

  @override
  void writeln([Object? object = ""]) => _buffer.writeln(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
