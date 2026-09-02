import "dart:io";
import "dart:typed_data";

import "package:file_selector/file_selector.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/core/platform/desktop_composer_image_picker.dart";

void main() {
  test("desktop picker limits the dialog to supported image extensions", () async {
    List<XTypeGroup>? capturedGroups;
    final picker = DesktopComposerImagePicker.forTesting(
      openFile: ({required acceptedTypeGroups}) async {
        capturedGroups = acceptedTypeGroups;
        return null;
      },
    );

    expect(await picker.pickImage(), isNull);
    expect(capturedGroups, hasLength(1));
    expect(capturedGroups!.single.extensions, containsAll(["bmp", "gif", "jpeg", "jpg", "png", "webp"]));
  });

  test("adapter returns the selected bytes and filename", () async {
    final bytes = Uint8List.fromList(const [0xFF, 0xD8, 0xFF, 0]);
    final directory = Directory.systemTemp.createTempSync("desktop_picker_test");
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File("${directory.path}/photo.jpg")..writeAsBytesSync(bytes);
    final picker = DesktopComposerImagePicker.forTesting(
      openFile: ({required acceptedTypeGroups}) async => XFile(file.path),
    );

    final picked = await picker.pickImage();

    expect(picked!.bytes, orderedEquals(bytes));
    expect(picked.filename, "photo.jpg");
  });

  test("adapter rejects an oversized file before materializing its bytes", () async {
    final directory = Directory.systemTemp.createTempSync("desktop_picker_test");
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File("${directory.path}/huge.jpg");
    final handle = file.openSync(mode: FileMode.write);
    handle.truncateSync(maxComposerPromptAttachmentBytes + 1);
    handle.closeSync();
    final picker = DesktopComposerImagePicker.forTesting(
      openFile: ({required acceptedTypeGroups}) async => XFile(file.path),
    );

    expect(picker.pickImage, throwsA(isA<AttachmentTooLargeError>()));
  });

  test("adapter returns null when selection is dismissed", () async {
    final picker = DesktopComposerImagePicker.forTesting(
      openFile: ({required acceptedTypeGroups}) async => null,
    );

    expect(await picker.pickImage(), isNull);
  });
}
