import "dart:typed_data";

import "package:injectable/injectable.dart";
import "package:pasteboard/pasteboard.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

@LazySingleton(as: ImageClipboard)
class FlutterImageClipboard implements ImageClipboard {
  @override
  Future<void> writeImage({required Uint8List bytes}) => Pasteboard.writeImage(bytes);
}
