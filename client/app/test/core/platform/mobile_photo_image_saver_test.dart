import "dart:typed_data";

import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/platform/gal_client.dart";
import "package:sesori_mobile/core/platform/mobile_photo_image_saver.dart";

class _FakeGalClient implements GalClient {
  bool hasAccessResult = false;
  bool requestAccessResult = false;
  int requestAccessCalls = 0;
  Uint8List? savedBytes;
  String? savedName;

  @override
  Future<bool> hasAccess() async => hasAccessResult;

  @override
  Future<bool> requestAccess() async {
    requestAccessCalls++;
    return requestAccessResult;
  }

  @override
  Future<void> putImageBytes({required Uint8List bytes, required String name}) async {
    savedBytes = bytes;
    savedName = name;
  }
}

void main() {
  late _FakeGalClient galClient;
  late MobilePhotoImageSaver imageSaver;

  setUp(() {
    galClient = _FakeGalClient();
    imageSaver = MobilePhotoImageSaver(galClient: galClient);
    expect(imageSaver.isSupported, isTrue);
  });

  test("saves through the injected Gal client without requesting existing access", () async {
    final bytes = Uint8List.fromList(const [1, 2, 3]);
    galClient.hasAccessResult = true;

    final result = await imageSaver.saveImage(bytes: bytes, mime: "image/png", filename: "image.png");

    expect(result, ImageSaveResult.saved);
    expect(galClient.requestAccessCalls, 0);
    expect(identical(galClient.savedBytes, bytes), isTrue);
    expect(galClient.savedName, "image");
  });

  test("requests access and reports denial without saving", () async {
    final result = await imageSaver.saveImage(
      bytes: Uint8List.fromList(const [1, 2, 3]),
      mime: "image/png",
      filename: "image.png",
    );

    expect(result, ImageSaveResult.accessDenied);
    expect(galClient.requestAccessCalls, 1);
    expect(galClient.savedBytes, isNull);
  });
}
