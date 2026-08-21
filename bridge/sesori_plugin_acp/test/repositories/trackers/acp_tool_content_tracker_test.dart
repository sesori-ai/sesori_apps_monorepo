import "dart:io";

import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/src/repositories/trackers/acp_tool_content_tracker.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show maxTranscriptImageCollectionBytes;
import "package:test/test.dart";

void main() {
  group("AcpToolContentTracker", () {
    test("applies replacement, output-only, and unchanged mutations", () {
      final tracker = AcpToolContentTracker()
        ..apply(
          mutation: AcpReplaceToolContentMutation(
            output: "first",
            imageCandidates: [_inline(filename: "first.png", decodedBytes: 1)],
            hasDiff: false,
          ),
        );

      expect(tracker.snapshot.output, "first");
      expect(tracker.snapshot.attachments.single.filename, "first.png");

      tracker.apply(mutation: const AcpUnchangedToolContentMutation());
      expect(tracker.snapshot.output, "first");
      expect(tracker.snapshot.attachments.single.filename, "first.png");

      tracker.apply(
        mutation: const AcpUpdateToolOutputMutation(output: "updated"),
      );
      expect(tracker.snapshot.output, "updated");
      expect(tracker.snapshot.attachments.single.filename, "first.png");
    });

    test("layers late initial attachments below an earlier output update", () {
      final tracker = AcpToolContentTracker()
        ..apply(
          mutation: const AcpUpdateToolOutputMutation(output: "new output"),
        )
        ..applyInitial(
          mutation: AcpReplaceToolContentMutation(
            output: "initial output",
            imageCandidates: [_inline(filename: "initial.png", decodedBytes: 1)],
            hasDiff: false,
          ),
        );

      expect(tracker.snapshot.output, "new output");
      expect(tracker.snapshot.attachments.single.filename, "initial.png");
    });

    test("present empty and image-only collections replace the whole state", () {
      final tracker = AcpToolContentTracker()
        ..apply(
          mutation: AcpReplaceToolContentMutation(
            output: "old",
            imageCandidates: [_inline(filename: "old.png", decodedBytes: 1)],
            hasDiff: false,
          ),
        )
        ..apply(
          mutation: AcpReplaceToolContentMutation(
            output: null,
            imageCandidates: [_inline(filename: "new.png", decodedBytes: 1)],
            hasDiff: false,
          ),
        );

      expect(tracker.snapshot.output, isNull);
      expect(tracker.snapshot.attachments, hasLength(1));
      expect(tracker.snapshot.attachments.single.filename, "new.png");

      tracker.apply(
        mutation: const AcpReplaceToolContentMutation(
          output: null,
          imageCandidates: [],
          hasDiff: false,
        ),
      );
      expect(tracker.snapshot.output, isNull);
      expect(tracker.snapshot.attachments, isEmpty);
    });

    test("enforces count and aggregate budgets for each replacement", () {
      final tracker = AcpToolContentTracker()
        ..apply(
          mutation: AcpReplaceToolContentMutation(
            output: null,
            imageCandidates: [
              _inline(
                filename: "one.png",
                decodedBytes: maxTranscriptImageCollectionBytes,
              ),
              _inline(filename: "two.png", decodedBytes: 1),
              _metadata(),
              _inline(filename: "four.png", decodedBytes: 0),
              _inline(filename: "five.png", decodedBytes: 0),
            ],
            hasDiff: false,
          ),
        );

      expect(tracker.snapshot.attachments, hasLength(4));
      expect(
        tracker.snapshot.attachments.map((attachment) => attachment.runtimeType),
        [
          PluginMessageAttachmentInlineImage,
          PluginMessageAttachmentMetadata,
          PluginMessageAttachmentMetadata,
          PluginMessageAttachmentInlineImage,
        ],
      );

      tracker.apply(
        mutation: AcpReplaceToolContentMutation(
          output: null,
          imageCandidates: [_inline(filename: "reset.png", decodedBytes: 1)],
          hasDiff: false,
        ),
      );
      expect(tracker.snapshot.attachments.single.filename, "reset.png");
    });

    test("deduplicates privacy-safe warnings within each collection", () {
      final output = _captureWarnings(() {
        AcpToolContentTracker().apply(
          mutation: AcpReplaceToolContentMutation(
            output: null,
            imageCandidates: [
              _metadata(),
              _metadata(),
              _metadata(),
              _metadata(),
              _metadata(),
            ],
            hasDiff: false,
          ),
        );
      });

      expect("invalid tool image attachment".allMatches(output), hasLength(1));
      expect("exceeds the count limit".allMatches(output), hasLength(1));
      expect(output, isNot(contains("private.png")));
    });
  });
}

AcpMappedInlineImageContentBlock _inline({
  required String filename,
  required int decodedBytes,
}) {
  return AcpMappedInlineImageContentBlock(
    attachment: PluginMessageAttachment.inlineImage(
      mime: "image/png",
      base64: "AA==",
      filename: filename,
    ) as PluginMessageAttachmentInlineImage,
    decodedBytes: decodedBytes,
  );
}

AcpMappedMetadataImageContentBlock _metadata() {
  return const AcpMappedMetadataImageContentBlock(
    attachment: PluginMessageAttachment.metadata(
      mime: "image/png",
      filename: "private.png",
    ) as PluginMessageAttachmentMetadata,
    reason: AcpImageDegradationReason.invalid,
  );
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
