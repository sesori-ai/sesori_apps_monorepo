import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/platform/flutter_clipboard_image_reader.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel("sesori/clipboard");
  const reader = FlutterClipboardImageReader();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final imageBytes = Uint8List.fromList([1, 2, 3, 4]);

  void mockHandler(Future<Object?>? Function(MethodCall call)? handler) {
    messenger.setMockMethodCallHandler(channel, handler);
  }

  tearDown(() => mockHandler(null));

  test("returns a PickedMedia built from the native map", () async {
    late MethodCall received;
    mockHandler((call) async {
      received = call;
      return <String, Object?>{
        "bytes": imageBytes,
        "mimeType": "image/png",
        "filename": "clipboard.png",
      };
    });

    final media = await reader.readImage();

    expect(received.method, "readImage");
    expect(media, isNotNull);
    expect(media!.bytes, imageBytes);
    expect(media.mimeType, "image/png");
    expect(media.filename, "clipboard.png");
  });

  test("defaults the mime type when the native side omits it", () async {
    mockHandler((_) async => <String, Object?>{"bytes": imageBytes});

    final media = await reader.readImage();

    expect(media, isNotNull);
    expect(media!.mimeType, "image/jpeg");
    expect(media.filename, isNull);
  });

  test("returns null when the clipboard holds no image", () async {
    mockHandler((_) async => null);

    expect(await reader.readImage(), isNull);
  });

  test("returns null when the payload has no usable bytes", () async {
    mockHandler((_) async => <String, Object?>{"bytes": Uint8List(0), "mimeType": "image/png"});

    expect(await reader.readImage(), isNull);
  });

  test("returns null when the platform channel is unavailable", () async {
    // No mock handler registered -> MissingPluginException -> treated as empty.
    mockHandler(null);

    expect(await reader.readImage(), isNull);
  });

  test("throws MediaPickerException on a platform error", () async {
    mockHandler((_) async => throw PlatformException(code: "BOOM", message: "kaboom"));

    expect(reader.readImage(), throwsA(isA<MediaPickerException>()));
  });
}
