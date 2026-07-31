import "dart:typed_data";

import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "pasteboard_client.dart";

@LazySingleton(as: ImageClipboard)
class FlutterImageClipboard implements ImageClipboard {
  final PasteboardClient _pasteboardClient;

  FlutterImageClipboard({required PasteboardClient pasteboardClient}) : _pasteboardClient = pasteboardClient;

  @override
  Future<void> writeImage({required Uint8List bytes}) => _pasteboardClient.writeImage(bytes: bytes);
}
