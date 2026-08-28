import "dart:convert";
import "dart:io";

import "package:injectable/injectable.dart";
import "package:meta/meta.dart";
import "package:path/path.dart" as path;

import "../foundation/platform/desktop_application_support_directory.dart";

/// Applies one owner-only POSIX mode to a filesystem path.
@visibleForTesting
typedef BridgeLogPermissionSetter = Future<void> Function({
  required String path,
  required String mode,
});

/// Layer-1 rotating file storage for supervised helper output.
///
/// The active file and its single rotated predecessor live only under the
/// desktop app's application-support directory. On POSIX, the log directory is
/// hardened to 0700 and every current/rotated file to 0600 before content is
/// written.
@lazySingleton
class BridgeProcessLogStorage.forTesting({
  required final DesktopApplicationSupportDirectory _applicationSupportDirectory,
  required final int _maxFileBytes,
  required final bool _isWindows,
  required final BridgeLogPermissionSetter _setPermissions,
}) {
  new({required DesktopApplicationSupportDirectory applicationSupportDirectory})
    : this.forTesting(
        applicationSupportDirectory: applicationSupportDirectory,
        maxFileBytes: defaultMaxFileBytes,
        isWindows: Platform.isWindows,
        setPermissions: _setPosixPermissions,
      );

  @visibleForTesting
  this : assert(_maxFileBytes > 0, "maxFileBytes must be positive");

  static const int defaultMaxFileBytes = 5 * 1024 * 1024;
  static const String _logsDirectoryName = "logs";
  static const String _currentFileName = "bridge.log";
  static const String _rotatedFileName = "bridge.log.1";

  Future<void> _writeTail = Future<void>.value();
  bool _directoryPrepared = false;
  bool _currentFilePrepared = false;

  /// Prepares and returns the active helper log used by desktop "Open Logs".
  Future<String> get logFilePath async {
    final Directory root = await _applicationSupportDirectory.resolve();
    final Directory logsDirectory = Directory(path.join(root.path, _logsDirectoryName));
    final File currentFile = File(path.join(logsDirectory.path, _currentFileName));
    await _prepareDirectory(directory: logsDirectory);
    await _prepareFile(file: currentFile);
    return currentFile.path;
  }

  /// Appends one logical line, serializing concurrent stdout/stderr writes and
  /// rotating before the configured size cap would be exceeded.
  Future<void> appendLine({required String line}) {
    final Future<void> operation = _writeTail.then((_) => _appendLine(line: line));
    // Keep the serialization tail usable after a failed write while returning
    // the original failing future to the tracker, which reports it.
    _writeTail = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  Future<void> _appendLine({required String line}) async {
    final Directory root = await _applicationSupportDirectory.resolve();
    final Directory logsDirectory = Directory(path.join(root.path, _logsDirectoryName));
    final File currentFile = File(path.join(logsDirectory.path, _currentFileName));
    final File rotatedFile = File(path.join(logsDirectory.path, _rotatedFileName));

    try {
      await _prepareDirectory(directory: logsDirectory);
      await _prepareFile(file: currentFile);
      final List<int> bytes = _fitLineToCap(line: line);
      final int currentLength = await currentFile.length();
      if (currentLength > 0 && currentLength + bytes.length > _maxFileBytes) {
        await _rotate(currentFile: currentFile, rotatedFile: rotatedFile);
      }
      await currentFile.writeAsBytes(bytes, mode: FileMode.append, flush: true);
    } on Object {
      // A transient filesystem failure must not poison later retries.
      _directoryPrepared = false;
      _currentFilePrepared = false;
      rethrow;
    }
  }

  Future<void> _prepareDirectory({required Directory directory}) async {
    // ignore: avoid_slow_async_io, async filesystem work must not block the desktop UI isolate
    if (!await directory.exists()) {
      await directory.create(recursive: true);
      _directoryPrepared = false;
    }
    if (!_isWindows && !_directoryPrepared) {
      await _setPermissions(path: directory.path, mode: "700");
    }
    _directoryPrepared = true;
  }

  Future<void> _prepareFile({required File file}) async {
    // ignore: avoid_slow_async_io, async filesystem work must not block the desktop UI isolate
    if (!await file.exists()) {
      await file.create(recursive: true);
      _currentFilePrepared = false;
    }
    if (!_isWindows && !_currentFilePrepared) {
      await _setPermissions(path: file.path, mode: "600");
    }
    _currentFilePrepared = true;
  }

  Future<void> _rotate({required File currentFile, required File rotatedFile}) async {
    // ignore: avoid_slow_async_io, async filesystem work must not block the desktop UI isolate
    if (await rotatedFile.exists()) {
      await rotatedFile.delete();
    }
    await currentFile.rename(rotatedFile.path);
    if (!_isWindows) {
      await _setPermissions(path: rotatedFile.path, mode: "600");
    }
    await currentFile.create(recursive: true);
    if (!_isWindows) {
      await _setPermissions(path: currentFile.path, mode: "600");
    }
    _currentFilePrepared = true;
  }

  List<int> _fitLineToCap({required String line}) {
    final List<int> full = utf8.encode("$line\n");
    if (full.length <= _maxFileBytes) {
      return full;
    }

    // Keep the newest complete Unicode scalar values. This preserves valid
    // UTF-8 while ensuring even one exceptionally large helper line cannot
    // exceed the file-size cap.
    final List<int> runes = line.runes.toList(growable: false);
    int start = runes.length;
    int byteLength = 1; // trailing newline
    while (start > 0) {
      final int runeLength = utf8.encode(String.fromCharCode(runes[start - 1])).length;
      if (byteLength + runeLength > _maxFileBytes) {
        break;
      }
      start--;
      byteLength += runeLength;
    }
    return utf8.encode("${String.fromCharCodes(runes.skip(start))}\n");
  }

  static Future<void> _setPosixPermissions({required String path, required String mode}) async {
    final ProcessResult result = await Process.run("chmod", <String>[mode, path], runInShell: false);
    if (result.exitCode != 0) {
      final String stderr = result.stderr.toString().trim();
      throw FileSystemException(
        stderr.isEmpty ? "chmod $mode failed with exit code ${result.exitCode}" : stderr,
        path,
      );
    }
  }
}
