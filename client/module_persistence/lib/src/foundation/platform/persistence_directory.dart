import "dart:io";

/// Resolves the client store's non-purgeable directory, not a cache directory.
///
/// The shell provides an existing directory with its native backup policy
/// applied. Database filenames and connection lifetime belong to persistence.
abstract interface class PersistenceDirectory() {
  Future<Directory> resolve();
}
