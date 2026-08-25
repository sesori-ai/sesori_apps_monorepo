import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

class const FilesystemCleaner() {
  Future<void> delete({required String path, required bool recursive}) async {
    try {
      final entityType = FileSystemEntity.typeSync(path, followLinks: false);
      switch (entityType) {
        case FileSystemEntityType.file:
          File(path).deleteSync();
        case FileSystemEntityType.directory:
          Directory(path).deleteSync(recursive: recursive);
        case FileSystemEntityType.link:
          Link(path).deleteSync();
        case FileSystemEntityType.unixDomainSock:
        case FileSystemEntityType.pipe:
        case FileSystemEntityType.notFound:
      }
    } on Object catch (error, stackTrace) {
      Log.w("updater cleanup failed for $path", error, stackTrace);
    }
  }
}
