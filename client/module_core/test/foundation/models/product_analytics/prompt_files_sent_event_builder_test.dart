import "dart:typed_data";

import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/foundation/models/product_analytics/prompt_files_sent_event_builder.dart";
import "package:test/test.dart";

ComposerFileAttachment _file({required ComposerAttachmentSource source}) =>
    ComposerFileAttachment(bytes: Uint8List.fromList(const [1, 2, 3]), filename: "secret-plan.pdf", source: source);

final _image = ComposerImageAttachment(mime: "image/png", bytes: Uint8List(1), filename: "screenshot.png");

void main() {
  test("reports nothing for a prompt without attachments", () {
    expect(promptFilesSentEvent(attachments: const []), isNull);
  });

  test("reports nothing for a prompt holding only inline images", () {
    expect(promptFilesSentEvent(attachments: [_image, _image]), isNull);
  });

  test("buckets the number of files, not counting inline images", () {
    List<ComposerAttachment> files(int count) => [
      _image,
      for (var i = 0; i < count; i++) _file(source: ComposerAttachmentSource.picker),
    ];
    for (final (count, bucket) in [
      (1, AnalyticsFileCountBucket.one),
      (2, AnalyticsFileCountBucket.twoToFour),
      (4, AnalyticsFileCountBucket.twoToFour),
      (5, AnalyticsFileCountBucket.fivePlus),
      (12, AnalyticsFileCountBucket.fivePlus),
    ]) {
      expect(promptFilesSentEvent(attachments: files(count))?.fileCount, bucket, reason: "$count files");
    }
  });

  test("reports the one source all files came from", () {
    for (final (source, expected) in [
      (ComposerAttachmentSource.picker, AnalyticsFileSource.picker),
      (ComposerAttachmentSource.drop, AnalyticsFileSource.drop),
      (ComposerAttachmentSource.paste, AnalyticsFileSource.paste),
    ]) {
      final event = promptFilesSentEvent(
        attachments: [
          _file(source: source),
          _file(source: source),
        ],
      );
      expect(event?.source, expected, reason: source.name);
    }
  });

  test("reports mixed when the files came from more than one source", () {
    final event = promptFilesSentEvent(
      attachments: [
        _file(source: ComposerAttachmentSource.drop),
        _file(source: ComposerAttachmentSource.paste),
      ],
    );

    expect(event?.source, AnalyticsFileSource.mixed);
  });

  test("an image's way in does not make the files mixed", () {
    final event = promptFilesSentEvent(
      attachments: [
        _image,
        _file(source: ComposerAttachmentSource.drop),
      ],
    );

    expect(event?.source, AnalyticsFileSource.drop);
  });

  test("carries only its two bounded parameters, never names or sizes", () {
    final event = promptFilesSentEvent(
      attachments: [
        ComposerFileAttachment(
          bytes: Uint8List(2048),
          filename: "/Users/someone/secret-plan.pdf",
          source: ComposerAttachmentSource.picker,
        ),
        _file(source: ComposerAttachmentSource.paste),
        _file(source: ComposerAttachmentSource.drop),
      ],
    );

    expect(event?.wireName, "prompt_files_sent");
    expect(event?.parameters, {"file_count": "2_4", "source": "mixed"});
  });
}
