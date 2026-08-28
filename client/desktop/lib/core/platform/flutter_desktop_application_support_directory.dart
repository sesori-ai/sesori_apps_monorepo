import "dart:io";

import "package:injectable/injectable.dart";
import "package:path_provider/path_provider.dart" as path_provider;
import "package:sesori_desktop_core/sesori_desktop_core.dart";

/// Flutter/path-provider implementation of the desktop-owned application-data
/// root used by supervision logs and later desktop-only persisted state.
@LazySingleton(as: DesktopApplicationSupportDirectory)
class FlutterDesktopApplicationSupportDirectory() implements DesktopApplicationSupportDirectory {
  Future<Directory>? _directory;

  @override
  Future<Directory> resolve() => _directory ??= path_provider.getApplicationSupportDirectory();
}
