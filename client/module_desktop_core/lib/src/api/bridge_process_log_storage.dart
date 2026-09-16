import "dart:io";

import "package:injectable/injectable.dart";
import "package:meta/meta.dart";
import "package:path/path.dart" as path;

import "../foundation/platform/desktop_application_support_directory.dart";
import "rotating_file_storage.dart";

/// Layer-1 owner-only rotating storage for supervised helper output.
@lazySingleton
class BridgeProcessLogStorage._create({
  required final DesktopApplicationSupportDirectory _applicationSupportDirectory,
  required final RotatingFileStorage _storage,
}) {
  new({required DesktopApplicationSupportDirectory applicationSupportDirectory})
    : this._create(
        applicationSupportDirectory: applicationSupportDirectory,
        storage: RotatingFileStorage(fileName: "bridge.log"),
      );

  @visibleForTesting
  new forTesting({
    required DesktopApplicationSupportDirectory applicationSupportDirectory,
    required int maxFileBytes,
    required bool isWindows,
    required LogFilePermissionSetter setPermissions,
  }) : this._create(
         applicationSupportDirectory: applicationSupportDirectory,
         storage: RotatingFileStorage.forTesting(
           fileName: "bridge.log",
           maxFileBytes: maxFileBytes,
           isWindows: isWindows,
           setPermissions: setPermissions,
         ),
       );

  static const int defaultMaxFileBytes = RotatingFileStorage.defaultMaxFileBytes;

  Future<Directory> _logsDirectory() async =>
      Directory(path.join((await _applicationSupportDirectory.resolve()).path, "logs"));

  /// Prepares an empty active file even before the helper emits its first line.
  Future<String> get logFilePath async => await _storage.prepare(directory: await _logsDirectory());

  Future<void> appendLine({required String line}) async =>
      await _storage.appendLine(directory: await _logsDirectory(), line: line);
}
