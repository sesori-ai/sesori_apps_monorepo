import "dart:typed_data";

import "package:injectable/injectable.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:share_plus/share_plus.dart";

import "desktop_share_client.dart";

@LazySingleton(as: ImageSharer)
class DesktopImageSharer({required final DesktopShareClient _shareClient}) implements ImageSharer {
  @override
  Future<void> shareImage({
    required Uint8List bytes,
    required String mime,
    required String filename,
    required ImageShareOrigin? origin,
  }) async {
    await _shareClient.share(
      params: ShareParams(
        files: [XFile.fromData(bytes, mimeType: mime, name: filename)],
        fileNameOverrides: [filename],
        sharePositionOrigin: origin == null
            ? null
            : Rect.fromLTWH(origin.left, origin.top, origin.width, origin.height),
      ),
    );
  }
}
