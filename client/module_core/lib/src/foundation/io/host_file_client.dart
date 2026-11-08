import "dart:io";
import "dart:typed_data";

import "package:injectable/injectable.dart";

sealed class const HostPathKind();

final class const HostRegularFile({required final int sizeBytes}) extends HostPathKind;

final class const HostDirectory() extends HostPathKind;

/// Missing, a link to nothing, or something other than a file or a folder.
final class const HostOtherPath() extends HostPathKind;

/// Reads files on this computer for the composer, so a dropped or picked path
/// can be sniffed without loading the whole file.
@lazySingleton
class const HostFileClient() {
  Future<HostPathKind> kindOf({required String path}) async {
    final stat = await FileStat.stat(path);
    return switch (stat.type) {
      FileSystemEntityType.file => HostRegularFile(sizeBytes: stat.size),
      FileSystemEntityType.directory => const HostDirectory(),
      _ => const HostOtherPath(),
    };
  }

  /// Up to [length] bytes from the start of the file at [path].
  Future<Uint8List> readHeader({required String path, required int length}) async {
    final file = await File(path).open();
    try {
      return await file.read(length);
    } finally {
      await file.close();
    }
  }

  Future<Uint8List> readAll({required String path}) => File(path).readAsBytes();
}
