import "dart:io";

import "package:flutter/foundation.dart" show visibleForTesting;
import "package:injectable/injectable.dart";
import "package:path/path.dart" as path;
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

@visibleForTesting
typedef ProtectedFileProbe = Future<void> Function({required String filePath});

/// Opens a protected file read-only, without reading its contents or prompting.
@LazySingleton(as: FileAccessPermission)
class IoFileAccessPermission.forTesting({
  required final UrlLauncher _urlLauncher,
  required final bool _isMacOS,
  required final String? _homeDirectory,
  required final ProtectedFileProbe _probe,
}) implements FileAccessPermission {
  new({required UrlLauncher urlLauncher})
    : this.forTesting(
        urlLauncher: urlLauncher,
        isMacOS: Platform.isMacOS,
        homeDirectory: Platform.environment["HOME"],
        probe: _openProtectedFile,
      );

  @visibleForTesting
  this;

  @override
  Future<FileAccessStatus> check() async {
    if (!_isMacOS) return FileAccessStatus.unsupported;
    final home = _homeDirectory;
    if (home == null || home.trim().isEmpty) {
      logw("Cannot check macOS file access because the home directory is unavailable");
      return FileAccessStatus.unknown;
    }
    try {
      await _probe(filePath: path.join(home, "Library", "Application Support", "com.apple.TCC", "TCC.db"));
      return FileAccessStatus.granted;
    } on FileSystemException catch (error, stackTrace) {
      if (error.osError?.errorCode == 1 || error.osError?.errorCode == 13) return FileAccessStatus.denied;
      logw("Could not determine macOS protected-file access", error, stackTrace);
      return FileAccessStatus.unknown;
    }
  }

  @override
  Future<void> openSystemSettings() async {
    if (!_isMacOS) return;
    final opened = await _urlLauncher.launch(
      Uri.parse("x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"),
    );
    if (!opened) throw StateError("Could not open macOS Full Disk Access settings");
  }

  static Future<void> _openProtectedFile({required String filePath}) async {
    final file = await File(filePath).open();
    await file.close();
  }
}
