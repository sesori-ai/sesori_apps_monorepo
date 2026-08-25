import "dart:convert";
import "dart:typed_data";

import "package:opencode_plugin/opencode_plugin.dart";
import "package:opencode_plugin/src/models/openapi/compaction_part.g.dart";
import "package:opencode_plugin/src/models/openapi/file_part.g.dart";
import "package:opencode_plugin/src/models/openapi/file_part_source.g.dart";
import "package:opencode_plugin/src/models/openapi/file_part_source_text.g.dart";
import "package:opencode_plugin/src/models/openapi/file_source.g.dart";
import "package:opencode_plugin/src/models/openapi/text_part.g.dart";
import "package:opencode_plugin/src/models/openapi/tool_part.g.dart";
import "package:opencode_plugin/src/models/openapi/tool_state_completed.g.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show maxTranscriptImageBytes;
import "package:test/test.dart";

FilePart _filePart({
  required String url,
  required String mime,
  required String? filename,
  required FilePartSource? source,
}) => FilePart(
  id: "part-file",
  sessionID: "session-1",
  messageID: "message-1",
  mime: mime,
  filename: filename,
  url: url,
  source: source,
);

void main() {
  const mapper = MessagePartMapper();

  test("maps manual compaction to visible command text", () {
    final part = mapper.mapPart(
      const CompactionPart(
        id: "part-1",
        sessionID: "session-1",
        messageID: "message-1",
        auto: false,
        overflow: null,
        tailStartId: null,
      ),
    );

    expect(part.type, equals(PluginMessagePartType.text));
    expect(part.text, equals("/compact"));
    expect(part.type.isVisible, isTrue);
  });

  test("maps automatic compaction to visible command text", () {
    final part = mapper.mapPart(
      const CompactionPart(
        id: "part-1",
        sessionID: "session-1",
        messageID: "message-1",
        auto: true,
        overflow: true,
        tailStartId: null,
      ),
    );

    expect(part.type, equals(PluginMessagePartType.text));
    expect(part.text, equals("/compact"));
    expect(part.type.isVisible, isTrue);
  });

  test("hides synthetic text intended only for the assistant", () {
    final part = mapper.mapPart(
      const TextPart(
        id: "part-1",
        sessionID: "session-1",
        messageID: "message-1",
        text: "Bridge-owned context",
        synthetic: true,
        ignored: null,
        time: null,
        metadata: null,
      ),
    );

    expect(part.type, equals(PluginMessagePartType.unknown));
    expect(part.type.isVisible, isFalse);
  });

  test("normalizes a data image to one bounded inline representation", () {
    final part = mapper.mapPart(
      _filePart(
        url: "data:image/png;base64,aGVsbG8=",
        mime: "image/png",
        filename: "image.png",
        source: null,
      ),
    );

    expect(
      part.attachment,
      equals(
        const PluginMessageAttachment.inlineImage(
          mime: "image/png",
          base64: "aGVsbG8=",
          filename: "image.png",
        ),
      ),
    );
    final json = jsonEncode(part.toJson());
    expect(json, contains('"base64":"aGVsbG8="'));
    expect(json, isNot(contains("data:image/png")));
    expect(part.toString(), isNot(contains("aGVsbG8=")));
  });

  test("keeps only metadata for local file references", () {
    final part = mapper.mapPart(
      _filePart(
        url: "file:///Users/alice/private/project/secret.dart",
        mime: "text/plain",
        filename: r"C:\Users\alice\private\project\secret.dart",
        source: const FileSource(
          text: FilePartSourceText(value: "secret", start: 0, end: 6),
          path: "/Users/alice/private/project/secret.dart",
        ),
      ),
    );

    expect(
      part.attachment,
      equals(const PluginMessageAttachment.metadata(mime: "text/plain", filename: "secret.dart")),
    );
    expect(jsonEncode(part.toJson()), isNot(contains("/Users/alice")));
  });

  test("does not expose malformed or unsupported attachment URLs", () {
    final malformed = mapper.mapPart(
      _filePart(
        url: "data:image/png,not-base64",
        mime: "image/png",
        filename: "broken.png",
        source: null,
      ),
    );
    final customScheme = mapper.mapPart(
      _filePart(
        url: "intent://open/private-file",
        mime: "application/pdf",
        filename: "document.pdf",
        source: null,
      ),
    );
    final svg = mapper.mapPart(
      _filePart(
        url: "data:image/svg+xml;base64,PHN2Zz48L3N2Zz4=",
        mime: "image/svg+xml",
        filename: "diagram.svg",
        source: null,
      ),
    );

    expect(
      malformed.attachment,
      equals(const PluginMessageAttachment.metadata(mime: "image/png", filename: "broken.png")),
    );
    expect(
      customScheme.attachment,
      equals(const PluginMessageAttachment.metadata(mime: "application/pdf", filename: "document.pdf")),
    );
    expect(
      svg.attachment,
      equals(const PluginMessageAttachment.metadata(mime: "image/svg+xml", filename: "diagram.svg")),
    );
  });

  test("carries a bounded number of completed tool attachments through tool state", () {
    final part = mapper.mapPart(
      ToolPart(
        id: "part-tool",
        sessionID: "session-1",
        messageID: "message-1",
        callID: "call-1",
        tool: "browser",
        state: ToolStateCompleted(
          input: const {},
          output: "done",
          title: "Screenshot",
          metadata: const {},
          time: const ToolStateCompletedTime(start: 0, end: 1, compacted: null),
          attachments: List.generate(
            5,
            (index) => _filePart(
              url: "data:image/png;base64,aGVsbG8=",
              mime: "image/png",
              filename: "screenshot-$index.png",
              source: null,
            ),
          ),
        ),
        metadata: null,
      ),
    );

    final attachments = part.state.attachments;
    expect(attachments, hasLength(4));
    expect(
      attachments.first,
      equals(
        const PluginMessageAttachment.inlineImage(
          mime: "image/png",
          base64: "aGVsbG8=",
          filename: "screenshot-0.png",
        ),
      ),
    );
  });

  test("derives a single image tool attachment filename from its path title", () {
    final part = mapper.mapPart(
      ToolPart(
        id: "part-tool",
        sessionID: "session-1",
        messageID: "message-1",
        callID: "call-1",
        tool: "read",
        state: ToolStateCompleted(
          input: const {},
          output: "Image read successfully",
          title: r"client\assets\images\why-needed.png",
          metadata: const {},
          time: const ToolStateCompletedTime(start: 0, end: 1, compacted: null),
          attachments: [
            _filePart(
              url: "data:image/png;base64,aGVsbG8=",
              mime: "image/png",
              filename: null,
              source: null,
            ),
          ],
        ),
        metadata: null,
      ),
    );

    expect(
      part.state.attachments.single,
      equals(
        const PluginMessageAttachment.inlineImage(
          mime: "image/png",
          base64: "aGVsbG8=",
          filename: "why-needed.png",
        ),
      ),
    );
  });

  test("does not treat a non-filename tool title as attachment metadata", () {
    final part = mapper.mapPart(
      ToolPart(
        id: "part-tool",
        sessionID: "session-1",
        messageID: "message-1",
        callID: "call-1",
        tool: "webfetch",
        state: ToolStateCompleted(
          input: const {},
          output: "Image fetched successfully",
          title: "https://files.example.com/image.png (image/png)",
          metadata: const {},
          time: const ToolStateCompletedTime(start: 0, end: 1, compacted: null),
          attachments: [
            _filePart(
              url: "data:image/png;base64,aGVsbG8=",
              mime: "image/png",
              filename: null,
              source: null,
            ),
          ],
        ),
        metadata: null,
      ),
    );

    expect(
      part.state.attachments.single,
      equals(
        const PluginMessageAttachment.inlineImage(
          mime: "image/png",
          base64: "aGVsbG8=",
          filename: null,
        ),
      ),
    );
  });

  test("retains tool image bytes beyond the legacy inline-wire budget", () {
    final threeMegabyteImage = base64Encode(Uint8List(3 * 1024 * 1024));
    final part = mapper.mapPart(
      ToolPart(
        id: "part-tool",
        sessionID: "session-1",
        messageID: "message-1",
        callID: "call-1",
        tool: "browser",
        state: ToolStateCompleted(
          input: const {},
          output: "done",
          title: "Screenshots",
          metadata: const {},
          time: const ToolStateCompletedTime(start: 0, end: 1, compacted: null),
          attachments: [
            _filePart(
              url: "data:image/png;base64,$threeMegabyteImage",
              mime: "image/png",
              filename: "first.png",
              source: null,
            ),
            _filePart(
              url: "data:image/png;base64,$threeMegabyteImage",
              mime: "image/png",
              filename: "second.png",
              source: null,
            ),
          ],
        ),
        metadata: null,
      ),
    );

    expect(part.state.attachments.first, isA<PluginMessageAttachmentInlineImage>());
    expect(part.state.attachments.last, isA<PluginMessageAttachmentInlineImage>());
  });

  test("enforces transcript image per-image and aggregate retention limits", () {
    final seventeenMiB = base64Encode(Uint8List(17 * 1024 * 1024));
    final aggregateDataUrl = "data:image/png;base64,$seventeenMiB";
    final aggregate = mapper.mapPart(
      ToolPart(
        id: "part-tool",
        sessionID: "session-1",
        messageID: "message-1",
        callID: "call-1",
        tool: "browser",
        state: ToolStateCompleted(
          input: const {},
          output: "done",
          title: "Screenshots",
          metadata: const {},
          time: const ToolStateCompletedTime(start: 0, end: 1, compacted: null),
          attachments: [
            for (var index = 0; index < 3; index++)
              _filePart(
                url: aggregateDataUrl,
                mime: "image/png",
                filename: "image-$index.png",
                source: null,
              ),
          ],
        ),
        metadata: null,
      ),
    );
    final oversized = mapper.mapPart(
      _filePart(
        url: "data:image/png;base64,${base64Encode(Uint8List(maxTranscriptImageBytes + 1))}",
        mime: "image/png",
        filename: "oversized.png",
        source: null,
      ),
    );

    expect(aggregate.state.attachments[0], isA<PluginMessageAttachmentInlineImage>());
    expect(aggregate.state.attachments[1], isA<PluginMessageAttachmentInlineImage>());
    expect(aggregate.state.attachments[2], isA<PluginMessageAttachmentMetadata>());
    expect(oversized.attachment, isA<PluginMessageAttachmentMetadata>());
  });
}
