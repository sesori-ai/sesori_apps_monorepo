import "dart:io";

import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/src/repositories/trackers/acp_content_tracker.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show maxTranscriptImageCollectionBytes;
import "package:test/test.dart";

void main() {
  group("AcpContentTracker", () {
    test("preserves mixed order with stable text and image suffixes", () {
      final tracker = AcpContentTracker();

      final mutations = tracker.append(
        blocks: [
          const AcpMappedTextContentBlock(text: "before"),
          _inline(decodedBytes: 1),
          const AcpMappedTextContentBlock(text: "after "),
          const AcpMappedTextContentBlock(text: "continued"),
          const AcpMappedUnsupportedContentBlock(),
          _metadata(),
          const AcpMappedTextContentBlock(text: "last"),
        ],
      );

      expect(
        mutations.map((mutation) => mutation.partIdSuffix),
        ["text", "image-1", "text-1", "text-1", "image-2", "text-2"],
      );
      expect(
        mutations.whereType<AcpTextDeltaMutation>().map((mutation) => mutation.delta),
        ["before", "after ", "continued", "last"],
      );
      expect(tracker.snapshot.textPartCount, 3);
      expect(tracker.snapshot.imageCandidateCount, 2);
      expect(tracker.snapshot.decodedImageBytes, 1);
    });

    test("uses text for the first segment after a leading image", () {
      final tracker = AcpContentTracker();

      final mutations = tracker.append(
        blocks: [
          _inline(decodedBytes: 1),
          const AcpMappedTextContentBlock(text: "text"),
        ],
      );

      expect(
        mutations.map((mutation) => mutation.partIdSuffix),
        ["image-1", "text"],
      );
      final image = mutations.first as AcpImageMutation;
      expect(
        (image.attachment as PluginMessageAttachmentInlineImage).base64,
        "AA==",
      );
    });

    test("enforces count and aggregate budgets without retaining overflow bytes", () {
      final tracker = AcpContentTracker();
      final mutations = tracker.append(
        blocks: [
          _inline(decodedBytes: maxTranscriptImageCollectionBytes),
          _inline(decodedBytes: 1),
          _metadata(),
          _inline(decodedBytes: 0),
          const AcpMappedTextContentBlock(text: "before dropped image"),
          _inline(decodedBytes: 0),
          const AcpMappedTextContentBlock(text: "after dropped image"),
        ],
      );

      final images = mutations.whereType<AcpImageMutation>().toList();
      expect(images, hasLength(4));
      expect(images[0].attachment, isA<PluginMessageAttachmentInlineImage>());
      expect(images[1].attachment, isA<PluginMessageAttachmentMetadata>());
      expect(images[2].attachment, isA<PluginMessageAttachmentMetadata>());
      expect(images[3].attachment, isA<PluginMessageAttachmentInlineImage>());
      expect(mutations.whereType<AcpTextDeltaMutation>().map((mutation) => mutation.partIdSuffix), [
        "text",
        "text-1",
      ]);
      expect(tracker.snapshot.imageCandidateCount, 5);
      expect(tracker.snapshot.decodedImageBytes, maxTranscriptImageCollectionBytes);
    });

    test("deduplicates privacy-safe warnings per message tracker", () {
      final output = _captureWarnings(() {
        AcpContentTracker().append(
          blocks: [_metadata(), _metadata(), _metadata(), _metadata(), _metadata()],
        );
      });

      expect("invalid image attachment".allMatches(output), hasLength(1));
      expect("exceeds the count limit".allMatches(output), hasLength(1));
      expect(output, isNot(contains("image.png")));
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

AcpMappedInlineImageContentBlock _inline({required int decodedBytes}) {
  return AcpMappedInlineImageContentBlock(
    attachment: const PluginMessageAttachment.inlineImage(
      mime: "image/png",
      base64: "AA==",
      filename: "image.png",
    ) as PluginMessageAttachmentInlineImage,
    decodedBytes: decodedBytes,
  );
}

AcpMappedMetadataImageContentBlock _metadata() {
  return const AcpMappedMetadataImageContentBlock(
    attachment: PluginMessageAttachment.metadata(
      mime: "image/png",
      filename: "image.png",
    ) as PluginMessageAttachmentMetadata,
    reason: AcpImageDegradationReason.invalid,
  );
}
