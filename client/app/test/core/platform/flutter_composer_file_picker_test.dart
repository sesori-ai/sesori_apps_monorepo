import "dart:convert";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:image_picker/image_picker.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/platform/document_picker_client.dart";
import "package:sesori_mobile/core/platform/flutter_composer_file_picker.dart";
import "package:sesori_mobile/core/platform/platform_image_downscale_builder.dart";

class MockImagePicker() extends Mock implements ImagePicker;

class _MockConnectionService() extends Mock implements ConnectionService;

class _MockActiveBridgeLocality() extends Mock implements ActiveBridgeLocality;

/// Stands in for the platform decoder: returns [result] for any input and
/// records what it was given.
class _FakeDownscaleBuilder() implements PlatformImageDownscaleBuilder {
  final given = <Uint8List>[];
  PlatformImageDownscaleResult result = const PlatformImageKept();

  @override
  Future<PlatformImageDownscaleResult> downscale({required Uint8List bytes}) async {
    given.add(bytes);
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => registerFallbackValue(ImageSource.gallery));

  late MockImagePicker imagePicker;
  late _FakeDownscaleBuilder downscaleBuilder;
  late FlutterComposerFilePicker picker;
  late List<XFile> openedFiles;
  late ComposerAttachmentDispatcher attachmentDispatcher;

  setUp(() {
    imagePicker = MockImagePicker();
    downscaleBuilder = _FakeDownscaleBuilder();
    openedFiles = const [];
    picker = FlutterComposerFilePicker(
      picker: imagePicker,
      downscaleBuilder: downscaleBuilder,
      documentPicker: DocumentPickerClient.forTesting(openFiles: () async => openedFiles),
    );
    attachmentDispatcher = ComposerAttachmentDispatcher(
      filePicker: picker,
      downscaleBuilder: const ComposerImageDownscaleBuilder(),
      hostFiles: HostFileRepository(client: const HostFileClient()),
      connectionService: _MockConnectionService(),
      locality: _MockActiveBridgeLocality(),
    );
  });

  void stubPick(XFile? file) {
    when(
      () => imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: any(named: "maxWidth"),
        maxHeight: any(named: "maxHeight"),
        imageQuality: any(named: "imageQuality"),
        requestFullMetadata: any(named: "requestFullMetadata"),
      ),
    ).thenAnswer((_) async => file);
  }

  Future<ComposerAttachOutcome?> pickOutcome() =>
      attachmentDispatcher.pick(
        source: ComposerPickSource.photos,
        attachmentsSupported: true,
        fileUploadsSupported: false,
        stagedAttachmentBytes: 0,
      );

  Future<ComposerAttachment?> pickAttachment() async => (await pickOutcome())?.attachments.single;

  /// A path-backed pick named [name], like the real picker returns.
  XFile pickedFile({required String name, required Uint8List bytes}) {
    final file = File("${Directory.systemTemp.createTempSync("picker_test").path}/$name")..writeAsBytesSync(bytes);
    addTearDown(() => file.parent.deleteSync(recursive: true));
    return XFile(file.path);
  }

  Uint8List jpegBytes([int length = 16]) {
    final bytes = Uint8List(length);
    bytes.setAll(0, const [0xFF, 0xD8, 0xFF]);
    return bytes;
  }

  test("a dismissed picker stages nothing", () async {
    stubPick(null);
    expect(await pickAttachment(), isNull);
  });

  test("clipboard bytes use shared validation and have no filename", () async {
    final bytes = jpegBytes();

    final outcome = await attachmentDispatcher.routeImageBytes(
      bytes: bytes,
      filename: null,
      attachmentsSupported: true,
      fileUploadsSupported: false,
      stagedAttachmentBytes: 0,
    );
    final attachment = outcome.attachments.single;

    expect(attachment.mime, "image/jpeg");
    expect(attachment.bytes, same(bytes));
    expect(attachment.filename, isNull);
  });

  test("reads the selected file while shared validation keeps its filename", () async {
    // A path-backed XFile, like the real picker returns — XFile.fromData does
    // not consistently surface a platform filename.
    final png = Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0]);
    final file = File("${Directory.systemTemp.createTempSync("picker_test").path}/shot.png")..writeAsBytesSync(png);
    addTearDown(() => file.parent.deleteSync(recursive: true));
    stubPick(XFile(file.path));

    final attachment = await pickAttachment();

    if (attachment == null) fail("no image was picked");
    expect(attachment.mime, "image/png");
    expect(attachment.filename, "shot.png");
    expect(attachment.bytes, png);
  });

  test("Android asks for the original image, so an animated GIF stays animated", () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    stubPick(null);

    await pickAttachment();

    verify(() => imagePicker.pickImage(source: ImageSource.gallery, requestFullMetadata: false)).called(1);
  });

  test("Android hands a GIF over untouched so it stays animated", () async {
    final gif = Uint8List.fromList([...latin1.encode("GIF89a"), 1, 0, 1, 0, 0, 0]);
    stubPick(XFile.fromData(gif, name: "anim.gif"));

    final attachment = await pickAttachment();

    expect(attachment?.mime, "image/gif");
    expect(attachment?.bytes, gif);
  });

  test("Android shrinks any other photo with the platform decoder and names it after the result", () async {
    final heic = Uint8List.fromList([0, 0, 0, 24, ...latin1.encode("ftypheic"), 0, 0, 0, 0]);
    final jpeg = jpegBytes();
    downscaleBuilder.result = PlatformImageDownscaled(jpeg: jpeg);
    final file = File("${Directory.systemTemp.createTempSync("picker_test").path}/IMG_0001.HEIC")
      ..writeAsBytesSync(heic);
    addTearDown(() => file.parent.deleteSync(recursive: true));
    stubPick(XFile(file.path));

    final attachment = await pickAttachment();

    expect(downscaleBuilder.given, [heic]);
    expect(attachment?.mime, "image/jpeg");
    expect(attachment?.bytes, jpeg);
    expect(attachment?.filename, "IMG_0001.jpg");
  });

  test("a photo the platform can't decode is turned away as unsupported", () async {
    final heic = Uint8List.fromList([0, 0, 0, 24, ...latin1.encode("ftypheic"), 0, 0, 0, 0]);
    stubPick(XFile.fromData(heic, name: "photo.heic"));

    expect(pickAttachment, throwsA(isA<UnsupportedAttachmentImageError>()));
  });

  test("iOS applies the shared size rule natively", () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    stubPick(XFile.fromData(jpegBytes(), name: "photo.jpg"));

    await pickAttachment();

    expect(downscaleBuilder.given, isEmpty);

    verify(
      () => imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
        requestFullMetadata: false,
      ),
    ).called(1);
  });

  test("re-encoded jpeg content sniffs as jpeg regardless of extension", () async {
    stubPick(XFile.fromData(jpegBytes(), name: "photo.heic"));

    final attachment = await pickAttachment();

    expect(attachment?.mime, "image/jpeg");
  });

  test("unsupported selected content is rejected by shared validation", () async {
    stubPick(XFile.fromData(Uint8List.fromList(const [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]), name: "blob.bin"));

    expect(pickAttachment, throwsA(isA<UnsupportedAttachmentImageError>()));
  });

  test("an image over the outbound composer limit is rejected", () async {
    stubPick(XFile.fromData(jpegBytes(maxComposerPromptAttachmentBytes + 1), name: "huge.jpg"));

    final outcome = await pickOutcome();

    expect(outcome?.attachments, isEmpty);
    expect(outcome?.rejections, {ComposerAttachRejectionReason.overBudget: 1});
  });

  test("a photo named by image_picker's iOS copy is named photo with its extension", () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    stubPick(pickedFile(name: "image_picker_6E5F8D3A-1B2C-4D5E-8F90-ABCDEF012345.jpg", bytes: jpegBytes()));

    expect((await pickAttachment())?.filename, "photo.jpg");
  });

  test("a photo without a display name on Android is named photo after the shrunk result", () async {
    downscaleBuilder.result = PlatformImageDownscaled(jpeg: jpegBytes());
    stubPick(pickedFile(name: "image_picker.png", bytes: jpegBytes()));

    expect((await pickAttachment())?.filename, "photo.jpg");
  });

  test("a photo keeps its own name when it merely starts like image_picker's", () async {
    stubPick(pickedFile(name: "image_picker_notes.jpg", bytes: jpegBytes()));

    expect((await pickAttachment())?.filename, "image_picker_notes.jpg");
  });

  group("Files", () {
    const channel = MethodChannel("com.sesori.app/document-picker");

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    test("on iOS hands over file_selector's copies without the gallery", () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      openedFiles = [XFile("/tmp/Inbox/Report.pdf"), XFile("/tmp/Inbox/notes.txt")];

      final picked = await picker.pick(source: ComposerPickSource.files);

      if (picked is! ComposerPickedHostPaths) fail("expected host paths, got $picked");
      expect(picked.paths, ["/tmp/Inbox/Report.pdf", "/tmp/Inbox/notes.txt"]);
      expect(picked.oversizedCount, 0);
      verifyNever(
        () => imagePicker.pickImage(
          source: any(named: "source"),
          maxWidth: any(named: "maxWidth"),
          maxHeight: any(named: "maxHeight"),
          imageQuality: any(named: "imageQuality"),
          requestFullMetadata: any(named: "requestFullMetadata"),
        ),
      );
    });

    test("on iOS a dismissed picker hands over nothing", () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      expect(await picker.pick(source: ComposerPickSource.files), isNull);
    });

    test("on Android asks the native picker to leave out files over the budget, and passes on how many it did", () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return {
          "paths": ["/cache/composer-picks/0/Report.pdf"],
          "oversizedCount": 2,
        };
      });

      final picked = await picker.pick(source: ComposerPickSource.files);

      expect(calls.single.method, "pick");
      expect(calls.single.arguments, {"maxBytes": maxComposerPromptAttachmentBytes});
      if (picked is! ComposerPickedHostPaths) fail("expected host paths, got $picked");
      expect(picked.paths, ["/cache/composer-picks/0/Report.pdf"]);
      expect(picked.oversizedCount, 2);
    });

    test("on Android a dismissed picker hands over nothing", () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => null,
      );

      expect(await picker.pick(source: ComposerPickSource.files), isNull);
    });
  });
}
