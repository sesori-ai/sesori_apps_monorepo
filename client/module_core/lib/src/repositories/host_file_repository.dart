import "dart:typed_data";

import "package:injectable/injectable.dart";

import "../foundation/io/host_file_client.dart";
import "../foundation/models/image/supported_raster_image_format.dart";

/// What the composer can learn about a path on this computer, without
/// loading a file it will not stage.
@lazySingleton
class HostFileRepository({required final HostFileClient _client}) {
  /// Enough bytes for every supported raster signature.
  static const _headerBytes = 16;

  Future<HostPathKind> kindOf({required String path}) => _client.kindOf(path: path);

  /// The supported image format the file at [path] starts with, read from its
  /// first bytes only, or null when it is not one.
  Future<SupportedRasterImageFormat?> imageFormatOf({required String path}) async =>
      detectSupportedRasterImageFormat(bytes: await _client.readHeader(path: path, length: _headerBytes));

  Future<Uint8List> readAll({required String path}) => _client.readAll(path: path);
}
