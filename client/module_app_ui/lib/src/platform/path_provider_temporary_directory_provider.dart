import "dart:io";

import "package:path_provider/path_provider.dart" as path_provider;
import "package:sesori_dart_core/sesori_dart_core.dart";

/// Shared adapter for core's temporary-directory lookup.
class PathProviderTemporaryDirectoryProvider() implements TemporaryDirectoryProvider {
  @override
  Future<Directory> temporaryDirectory() => path_provider.getTemporaryDirectory();
}
