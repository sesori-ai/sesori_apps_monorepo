import "dart:convert";

import "package:clock/clock.dart";
import "package:sesori_bridge/src/repositories/prompt_upload_repository.dart";
import "package:sesori_bridge/src/services/prompt_part_delivery_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  final now = DateTime(2026, 11, 8, 15, 30);
  late _RecordingUploads uploads;
  late PromptPartDeliveryService service;

  setUp(() {
    uploads = _RecordingUploads();
    service = PromptPartDeliveryService(uploads: uploads, clock: Clock.fixed(now));
  });

  Future<List<PromptPart>> deliver({required List<PromptPart> parts, bool inlineImages = true}) {
    return service.deliverableParts(sessionId: "ses_1", inlineImages: inlineImages, parts: parts);
  }

  const image = PromptPart.fileData(mime: "image/png", base64: "iVBORw0KGgo=", filename: "shot.png");

  test("passes an image through when the plugin takes images, and saves nothing", () async {
    expect(await deliver(parts: const [image]), const [image]);
    expect(uploads.saves, isEmpty);
    expect(uploads.sweepCutoffs, isEmpty);
  });

  test("saves a file and replaces it in place with a note naming the saved path", () async {
    final delivered = await deliver(
      parts: [
        const PromptPart.text(text: "Read"),
        PromptPart.fileData(
          mime: "application/octet-stream",
          base64: base64Encode(utf8.encode("report")),
          filename: "My Report.pdf",
        ),
        image,
      ],
    );

    final save = uploads.saves.single;
    expect(save.sessionId, "ses_1");
    expect(utf8.decode(save.bytes), "report");
    expect(save.filename, "My Report.pdf");
    expect(delivered, const [
      PromptPart.text(text: "Read"),
      PromptPart.text(text: 'Attached file "My Report.pdf": `/uploads/ses_1/My Report.pdf`'),
      image,
    ]);
  });

  test("saves an image when the plugin doesn't take images", () async {
    final delivered = await deliver(parts: const [image], inlineImages: false);

    expect(uploads.saves.map((save) => save.filename), ["shot.png"]);
    expect(delivered, const [PromptPart.text(text: 'Attached file "shot.png": `/uploads/ses_1/shot.png`')]);
  });

  test("names a file without a name, or with an empty one, attachment", () async {
    final delivered = await deliver(
      parts: const [
        PromptPart.fileData(mime: "application/octet-stream", base64: "", filename: null),
        PromptPart.fileData(mime: "application/octet-stream", base64: "", filename: ""),
      ],
    );

    expect(uploads.saves.map((save) => save.filename), ["attachment", "attachment"]);
    expect(delivered, const [
      PromptPart.text(text: 'Attached file "attachment": `/uploads/ses_1/attachment`'),
      PromptPart.text(text: 'Attached file "attachment": `/uploads/ses_1/attachment`'),
    ]);
  });

  test("keeps backticks, double quotes and line breaks in the name from breaking the note", () async {
    final delivered = await deliver(
      parts: const [
        PromptPart.fileData(mime: "application/octet-stream", base64: "", filename: "a`b.txt"),
        PromptPart.fileData(mime: "application/octet-stream", base64: "", filename: 'my "final"\r\nnotes.txt'),
      ],
    );

    expect(uploads.saves.map((save) => save.filename), ["a`b.txt", 'my "final"\r\nnotes.txt']);
    expect(delivered, const [
      PromptPart.text(text: 'Attached file "a\'b.txt": `/uploads/ses_1/a`b.txt`'),
      PromptPart.text(text: 'Attached file "my \'final\'  notes.txt": `/uploads/ses_1/my "final"\r\nnotes.txt`'),
    ]);
  });

  test("passes text, path and url parts through", () async {
    const parts = [
      PromptPart.text(text: "hi"),
      PromptPart.filePath(mime: "text/plain", path: "/tmp/a.txt", filename: null),
      PromptPart.fileUrl(mime: "text/plain", url: "https://example.com/a.txt", filename: null),
    ];

    expect(await deliver(parts: parts), parts);
    expect(uploads.sweepCutoffs, isEmpty);
  });

  test("sweeps uploads older than 30 days once after saving", () async {
    await deliver(
      parts: const [
        PromptPart.fileData(mime: "application/octet-stream", base64: "", filename: "a"),
        PromptPart.fileData(mime: "application/octet-stream", base64: "", filename: "b"),
      ],
    );

    expect(uploads.sweepCutoffs, [now.subtract(const Duration(days: 30))]);
  });

  test("a failed sweep does not fail the delivery", () async {
    uploads.sweepError = StateError("sweep failed");

    final delivered = await deliver(parts: const [image], inlineImages: false);
    await pumpEventQueue();

    expect(delivered, hasLength(1));
    expect(uploads.sweepCutoffs, hasLength(1));
  });

  test("a failed save propagates", () async {
    uploads.saveError = StateError("disk full");

    await expectLater(deliver(parts: const [image], inlineImages: false), throwsStateError);
    expect(uploads.sweepCutoffs, isEmpty);
  });
}

class _RecordingUploads() implements PromptUploadRepository {
  final List<({String sessionId, List<int> bytes, String filename})> saves = [];
  final List<DateTime> sweepCutoffs = [];
  Object? saveError;
  Object? sweepError;

  @override
  Future<String> save({required String sessionId, required List<int> bytes, required String filename}) async {
    if (saveError case final error?) throw error;
    saves.add((sessionId: sessionId, bytes: bytes, filename: filename));
    return "/uploads/$sessionId/$filename";
  }

  @override
  Future<void> deleteFileFoldersDatedBefore({required DateTime cutoff}) async {
    sweepCutoffs.add(cutoff);
    if (sweepError case final error?) throw error;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
