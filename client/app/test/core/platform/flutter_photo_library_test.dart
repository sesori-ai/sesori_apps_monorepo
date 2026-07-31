import "dart:typed_data";

import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/platform/flutter_photo_library.dart";
import "package:sesori_mobile/core/platform/gal_client.dart";

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
  late FlutterPhotoLibrary photoLibrary;

  setUp(() {
    galClient = _FakeGalClient();
    photoLibrary = FlutterPhotoLibrary(galClient: galClient);
  });

  test("saves through the injected Gal client without requesting existing access", () async {
    final bytes = Uint8List.fromList(const [1, 2, 3]);
    galClient.hasAccessResult = true;

    final result = await photoLibrary.saveImage(bytes: bytes, filename: "image.png");

    expect(result, PhotoLibrarySaveResult.saved);
    expect(galClient.requestAccessCalls, 0);
    expect(identical(galClient.savedBytes, bytes), isTrue);
    expect(galClient.savedName, "image");
  });

  test("requests access and reports denial without saving", () async {
    final result = await photoLibrary.saveImage(
      bytes: Uint8List.fromList(const [1, 2, 3]),
      filename: "image.png",
    );

    expect(result, PhotoLibrarySaveResult.accessDenied);
    expect(galClient.requestAccessCalls, 1);
    expect(galClient.savedBytes, isNull);
  });
}
