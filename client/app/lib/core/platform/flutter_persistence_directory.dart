import "dart:io";

import "package:injectable/injectable.dart";
import "package:path/path.dart" as path;
import "package:sesori_persistence/sesori_persistence.dart";

import "application_support_directory_client.dart";

@LazySingleton(as: PersistenceDirectory)
class FlutterPersistenceDirectory({required final ApplicationSupportDirectoryClient directories})
    implements PersistenceDirectory {
  @override
  Future<Directory> resolve() async {
    final root = await directories.directory;
    // Android backup XML excludes this whole filesDir subtree, including WAL,
    // SHM and journals. iOS keeps Application Support backup eligibility.
    return await Directory(path.join(root.path, "persistence")).create(recursive: true);
  }
}
