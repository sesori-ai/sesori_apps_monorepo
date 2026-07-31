import "dart:typed_data";

import "package:flutter/material.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:share_plus/share_plus.dart";

import "share_plus_client.dart";

@LazySingleton(as: ImageSharer)
class FlutterImageSharer implements ImageSharer {
  final SharePlusClient _sharePlusClient;

  FlutterImageSharer({required SharePlusClient sharePlusClient}) : _sharePlusClient = sharePlusClient;

  @override
  Future<void> shareImage({
    required Uint8List bytes,
    required String mime,
    required String filename,
    required ImageShareOrigin? origin,
  }) async {
    await _sharePlusClient.share(
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
