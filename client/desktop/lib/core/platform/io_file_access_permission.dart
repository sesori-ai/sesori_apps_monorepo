import "dart:io";

import "package:flutter/foundation.dart" show visibleForTesting;
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

@visibleForTesting
typedef ProtectedFileProbe = Future<void> Function({required String filePath});

/// Opens a protected file read-only, without reading its contents or prompting.
@LazySingleton(as: FileAccessPermission)
class IoFileAccessPermission.forTesting({
  required final UrlLauncher _urlLauncher,
  required final bool _isMacOS,
  required final ProtectedFileProbe _probe,
}) implements FileAccessPermission {
  new({required UrlLauncher urlLauncher})
    : this.forTesting(urlLauncher: urlLauncher, isMacOS: Platform.isMacOS, probe: _openProtectedFile);

  @visibleForTesting
  this;

  /// The system-wide TCC database exists on every macOS install and is readable
  /// only with Full Disk Access. The per-user copy is absent on some installs.
  @visibleForTesting
  static const protectedFilePath = "/Library/Application Support/com.apple.TCC/TCC.db";

  @override
  Future<FileAccessStatus> check() async {
    if (!_isMacOS) return FileAccessStatus.unsupported;
    try {
      await _probe(filePath: protectedFilePath);
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
