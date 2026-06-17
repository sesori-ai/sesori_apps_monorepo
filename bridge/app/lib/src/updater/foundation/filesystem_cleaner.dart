import 'dart:io';

/// Foundation primitive: best-effort deletion of a filesystem path.
///
/// Shared by the staging and apply steps of the update pipeline so cleanup of
/// archives, staging directories, and residue lives in one place rather than
/// being duplicated (or borrowed via a static method on a sibling service).
class FilesystemCleaner {
  const FilesystemCleaner();

  Future<void> delete({required String path, required bool recursive}) async {
    // Synchronous dart:io is used deliberately: the `avoid_slow_async_io` lint
    // (enforced project-wide) prefers the sync variants for type/existence
    // checks, which are faster than their async counterparts.
    try {
      final FileSystemEntityType entityType = FileSystemEntity.typeSync(path);
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
    } on Object {
      stderr.writeln('Warning: updater cleanup failed for $path');
    }
  }
}
