import "dart:io";

/// Platform lookup of the app-private temporary directory.
///
/// Each shell supplies its path_provider adapter; core owns the cached client
/// built on top of it so lookup, failure retry and warm-up live in one place.
abstract interface class TemporaryDirectoryProvider() {
  Future<Directory> temporaryDirectory();
}
