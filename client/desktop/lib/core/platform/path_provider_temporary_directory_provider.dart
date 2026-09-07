import "dart:io";

import "package:injectable/injectable.dart";
import "package:path_provider/path_provider.dart" as path_provider;
import "package:sesori_dart_core/sesori_dart_core.dart";

/// Desktop adapter for core's temporary-directory lookup.
@LazySingleton(as: TemporaryDirectoryProvider)
class PathProviderTemporaryDirectoryProvider() implements TemporaryDirectoryProvider {
  @override
  Future<Directory> temporaryDirectory() => path_provider.getTemporaryDirectory();
}
