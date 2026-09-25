import "dart:io";

import "package:injectable/injectable.dart";
import "package:path/path.dart" as path;
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_persistence/sesori_persistence.dart";

@LazySingleton(as: PersistenceDirectory)
class DesktopPersistenceDirectory({required final DesktopApplicationSupportDirectory directories})
    implements PersistenceDirectory {
  @override
  Future<Directory> resolve() async {
    final root = await directories.resolve();
    return await Directory(path.join(root.path, "persistence")).create(recursive: true);
  }
}
