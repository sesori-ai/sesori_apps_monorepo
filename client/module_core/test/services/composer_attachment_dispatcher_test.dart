import "dart:io";
import "dart:math" as math;
import "dart:typed_data";

import "package:image/image.dart" as image;
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

class _StubComposerFilePicker({required final ComposerPickResult? result}) implements ComposerFilePicker {
  @override
  Future<ComposerPickResult?> pick() async => result;
}

class _MockConnectionService() extends Mock implements ConnectionService;

class const _Locality({required final String? _localBridgeId}) implements ActiveBridgeLocality {
  @override
  bool isLocalBridge({required String bridgeId}) => bridgeId == _localBridgeId;

  @override
  String? get localBridgeId => _localBridgeId;

  @override
  Stream<String?> get localBridgeIdStream => Stream.value(_localBridgeId);
}

/// A PNG one byte over the per-prompt cap, counting full reads.
class _OversizedImageFileClient() implements HostFileClient {
  int fullReads = 0;

  @override
  Future<HostPathKind> kindOf({required String path}) async =>
      const HostRegularFile(sizeBytes: maxComposerPromptAttachmentBytes + 1);

  @override
  Future<Uint8List> readHeader({required String path, required int length}) async {
    final header = Uint8List(length);
    header.setAll(0, _png);
    return header;
  }

  @override
  Future<Uint8List> readAll({required String path}) async {
    fullReads++;
    return Uint8List(0);
  }
}

const _localBridgeId = "this-computer";
const _png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

void main() {
  Uint8List bytesWithPrefix({required List<int> prefix, int length = 16}) {
    final bytes = Uint8List(length);
    bytes.setAll(0, prefix);
    return bytes;
  }

  ComposerAttachmentDispatcher dispatcherFor({
    required ComposerPickResult? picked,
    String? activeBridgeId,
    HostFileClient fileClient = const HostFileClient(),
  }) {
    final connectionService = _MockConnectionService();
    when(() => connectionService.activeConfig).thenReturn(
      ServerConnectionConfig(relayHost: "relay.example", authToken: null, bridgeId: activeBridgeId),
    );
    return ComposerAttachmentDispatcher(
      filePicker: _StubComposerFilePicker(result: picked),
      downscaleBuilder: const ComposerImageDownscaleBuilder(),
      hostFiles: HostFileRepository(client: fileClient),
      connectionService: connectionService,
      locality: const _Locality(localBridgeId: _localBridgeId),
    );
  }

  group("ComposerAttachmentDispatcher", () {
    test("returns null when selection is dismissed", () async {
      expect(
        await dispatcherFor(picked: null).pick(attachmentsSupported: true, stagedAttachmentBytes: 0),
        isNull,
      );
    });

    test("validates picked bytes and normalizes the filename", () async {
      final bytes = bytesWithPrefix(prefix: const [0xFF, 0xD8, 0xFF]);
      final dispatcher = dispatcherFor(
        picked: ComposerPickedImage(bytes: bytes, filename: "  photo.jpg  "),
      );

      final outcome =
          await dispatcher.pick(attachmentsSupported: true, stagedAttachmentBytes: 0) ?? fail("no image picked");

      final attachment = outcome.attachments.single;
      expect(attachment.mime, "image/jpeg");
      expect(attachment.bytes, same(bytes));
      expect(attachment.filename, "photo.jpg");
      expect(outcome.insertedText, isNull);
      expect(outcome.rejections, isEmpty);
    });

    test("recognizes supported composer image signatures", () async {
      final dispatcher = dispatcherFor(picked: null);
      final cases = <(List<int>, String)>[
        (const [0xFF, 0xD8, 0xFF], "image/jpeg"),
        (_png, "image/png"),
        ("GIF89a".codeUnits, "image/gif"),
        (const [0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50], "image/webp"),
        (const [0x42, 0x4D], "image/bmp"),
      ];

      for (final (prefix, mime) in cases) {
        final attachment = await dispatcher.attachmentFromBytes(
          bytes: bytesWithPrefix(prefix: prefix),
          filename: "image",
        );
        expect(attachment.mime, mime);
      }
    });

    test("converts an empty filename to null", () async {
      final attachment = await dispatcherFor(picked: null).attachmentFromBytes(
        bytes: bytesWithPrefix(prefix: const [0xFF, 0xD8, 0xFF]),
        filename: "   ",
      );

      expect(attachment.filename, isNull);
    });

    test("rejects unsupported bytes", () async {
      await expectLater(
        dispatcherFor(picked: null).attachmentFromBytes(
          bytes: Uint8List.fromList(List<int>.generate(16, (index) => index)),
          filename: "blob.bin",
        ),
        throwsA(isA<UnsupportedAttachmentImageError>()),
      );
    });

    test("rejects bytes that stay above the outbound limit", () async {
      // Not decodable, so the downscale keeps the original and the limit applies.
      final bytes = bytesWithPrefix(
        prefix: const [0xFF, 0xD8, 0xFF],
        length: maxComposerPromptAttachmentBytes + 1,
      );

      await expectLater(
        dispatcherFor(picked: null).attachmentFromBytes(bytes: bytes, filename: "huge.jpg"),
        throwsA(isA<AttachmentTooLargeError>()),
      );
    });

    test("stages an oversized image as a downscaled JPEG with a matching filename", () async {
      final random = math.Random(7);
      final source = image.Image(width: 2600, height: 900);
      for (final pixel in source) {
        pixel.setRgb(random.nextInt(256), random.nextInt(256), random.nextInt(256));
      }
      final png = image.encodePng(source, level: 1);
      final dispatcher = dispatcherFor(
        picked: ComposerPickedImage(bytes: png, filename: "screenshot.png"),
      );

      final outcome =
          await dispatcher.pick(attachmentsSupported: true, stagedAttachmentBytes: 0) ?? fail("no image picked");

      final attachment = outcome.attachments.single;
      expect(attachment.mime, "image/jpeg");
      expect(attachment.filename, "screenshot.jpg");
      expect(attachment.bytes.length, lessThan(png.length));
    });
  });

  group("routeHostPaths", () {
    late Directory root;
    late String imagePath;
    late String notesPath;
    late String folderPath;
    late String spacedPath;
    late String quotedPath;

    setUp(() {
      root = Directory.systemTemp.createTempSync("composer_routing_test");
      imagePath = (File("${root.path}/shot.png")..writeAsBytesSync(bytesWithPrefix(prefix: _png))).path;
      notesPath = (File("${root.path}/notes.dart")..writeAsStringSync("void main() {}")).path;
      folderPath = (Directory("${root.path}/lib")..createSync()).path;
      spacedPath = (File("${root.path}/my report.pdf")..writeAsStringSync("%PDF-1.7")).path;
      quotedPath = (File('${root.path}/say"hi".txt')..writeAsStringSync("hi")).path;
    });

    tearDown(() => root.deleteSync(recursive: true));

    test("stages a supported image without inserting its path", () async {
      final outcome = await dispatcherFor(picked: null, activeBridgeId: _localBridgeId).routeHostPaths(
        paths: [imagePath],
        attachmentsSupported: true,
        stagedAttachmentBytes: 0,
      );

      expect(outcome.attachments.single.mime, "image/png");
      expect(outcome.attachments.single.filename, "shot.png");
      expect(outcome.insertedText, isNull);
      expect(outcome.rejections, isEmpty);
    });

    test("inserts an image's path on a local bridge whose backend takes no attachments", () async {
      final outcome = await dispatcherFor(picked: null, activeBridgeId: _localBridgeId).routeHostPaths(
        paths: [imagePath],
        attachmentsSupported: null,
        stagedAttachmentBytes: 0,
      );

      expect(outcome.attachments, isEmpty);
      expect(outcome.insertedText, imagePath);
      expect(outcome.rejections, isEmpty);
    });

    test("inserts an image's path on a local bridge once the budget is spent", () async {
      final outcome = await dispatcherFor(picked: null, activeBridgeId: _localBridgeId).routeHostPaths(
        paths: [imagePath],
        attachmentsSupported: true,
        stagedAttachmentBytes: maxComposerPromptAttachmentBytes,
      );

      expect(outcome.attachments, isEmpty);
      expect(outcome.insertedText, imagePath);
    });

    test("inserts non-image files and folders on a local bridge, quoting paths with spaces or quotes", () async {
      final outcome = await dispatcherFor(picked: null, activeBridgeId: _localBridgeId).routeHostPaths(
        paths: [notesPath, folderPath, spacedPath, quotedPath],
        attachmentsSupported: true,
        stagedAttachmentBytes: 0,
      );

      expect(outcome.attachments, isEmpty);
      final escapedQuotedPath = quotedPath.replaceAll('"', r'\"');
      expect(outcome.insertedText, '$notesPath $folderPath "$spacedPath" "$escapedQuotedPath"');
      expect(outcome.rejections, isEmpty);
    });

    test("stages a mixed drop's images and turns the rest away on a remote bridge", () async {
      final outcome = await dispatcherFor(picked: null, activeBridgeId: "another-computer").routeHostPaths(
        paths: [notesPath, imagePath, folderPath],
        attachmentsSupported: true,
        stagedAttachmentBytes: 0,
      );

      expect(outcome.attachments.single.filename, "shot.png");
      expect(outcome.insertedText, isNull);
      expect(outcome.rejections, {ComposerAttachRejectionReason.notTransferable: 2});
    });

    test("treats a missing connection as a remote bridge", () async {
      final outcome = await dispatcherFor(picked: null, activeBridgeId: null).routeHostPaths(
        paths: [notesPath],
        attachmentsSupported: true,
        stagedAttachmentBytes: 0,
      );

      expect(outcome.insertedText, isNull);
      expect(outcome.rejections, {ComposerAttachRejectionReason.notTransferable: 1});
    });

    test("names an over-budget image on a remote bridge", () async {
      final outcome = await dispatcherFor(picked: null, activeBridgeId: "another-computer").routeHostPaths(
        paths: [imagePath],
        attachmentsSupported: true,
        stagedAttachmentBytes: maxComposerPromptAttachmentBytes,
      );

      expect(outcome.attachments, isEmpty);
      expect(outcome.rejections, {ComposerAttachRejectionReason.overBudget: 1});
    });

    test("counts each reason a remote drop turns files away for", () async {
      final outcome = await dispatcherFor(picked: null, activeBridgeId: "another-computer").routeHostPaths(
        paths: [notesPath, imagePath, folderPath],
        attachmentsSupported: true,
        stagedAttachmentBytes: maxComposerPromptAttachmentBytes,
      );

      expect(outcome.rejections, {
        ComposerAttachRejectionReason.notTransferable: 2,
        ComposerAttachRejectionReason.overBudget: 1,
      });
    });

    test("stages an image larger than the remaining budget once downscaling makes it fit", () async {
      final random = math.Random(7);
      final source = image.Image(width: 2600, height: 900);
      for (final pixel in source) {
        pixel.setRgb(random.nextInt(256), random.nextInt(256), random.nextInt(256));
      }
      final png = image.encodePng(source, level: 1);
      final largePath = (File("${root.path}/large.png")..writeAsBytesSync(png)).path;

      final outcome = await dispatcherFor(picked: null, activeBridgeId: "another-computer").routeHostPaths(
        paths: [largePath],
        attachmentsSupported: true,
        stagedAttachmentBytes: maxComposerPromptAttachmentBytes - png.length + 1,
      );

      expect(outcome.attachments.single.filename, "large.jpg");
      expect(outcome.rejections, isEmpty);
    });

    test("never reads an image above the per-prompt cap", () async {
      final fileClient = _OversizedImageFileClient();
      final dispatcher = dispatcherFor(picked: null, activeBridgeId: "another-computer", fileClient: fileClient);

      final outcome = await dispatcher.routeHostPaths(
        paths: ["/photos/huge.png"],
        attachmentsSupported: true,
        stagedAttachmentBytes: 0,
      );

      expect(outcome.rejections, {ComposerAttachRejectionReason.overBudget: 1});
      expect(fileClient.fullReads, 0);
    });

    test("routes picked host paths the same way", () async {
      final outcome = await dispatcherFor(
        picked: ComposerPickedHostPaths(paths: [notesPath, imagePath]),
        activeBridgeId: _localBridgeId,
      ).pick(attachmentsSupported: true, stagedAttachmentBytes: 0);

      expect(outcome?.attachments.single.filename, "shot.png");
      expect(outcome?.insertedText, notesPath);
    });
  });
}
