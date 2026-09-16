import "dart:convert";
import "dart:io";

import "package:path/path.dart" as path;

typedef LogFilePermissionSetter = Future<void> Function({required String path, required String mode});

/// Package-internal Layer-1 primitive; each facade owns a separate file instance.
class RotatingFileStorage.forTesting({
  required final String _fileName,
  required final int _maxFileBytes,
  required final bool _isWindows,
  required final LogFilePermissionSetter _setPermissions,
}) {
  new({required String fileName})
    : this.forTesting(
        fileName: fileName,
        maxFileBytes: defaultMaxFileBytes,
        isWindows: Platform.isWindows,
        setPermissions: _setPosixPermissions,
      );

  this : assert(_maxFileBytes > 0, "maxFileBytes must be positive");

  static const int defaultMaxFileBytes = 5 * 1024 * 1024;
  Future<void> _writeTail = Future<void>.value();
  bool _directoryPrepared = false;
  bool _currentFilePrepared = false;

  Future<String> prepare({required Directory directory}) async {
    final file = File(path.join(directory.path, _fileName));
    await _prepareDirectory(directory: directory);
    await _prepareFile(file: file);
    return file.path;
  }

  Future<void> appendLine({required Directory directory, required String line}) {
    final operation = _writeTail.then((_) => _appendLine(directory: directory, line: line));
    // The original future reports failure to its caller; the queue remains usable.
    _writeTail = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  Future<void> _appendLine({required Directory directory, required String line}) async {
    final currentFile = File(path.join(directory.path, _fileName));
    final rotatedFile = File("${currentFile.path}.1");
    try {
      await _prepareDirectory(directory: directory);
      await _prepareFile(file: currentFile);
      final bytes = _fitLineToCap(line: line);
      final currentLength = await currentFile.length();
      if (currentLength > 0 && currentLength + bytes.length > _maxFileBytes) {
        await _rotate(currentFile: currentFile, rotatedFile: rotatedFile);
      }
      await currentFile.writeAsBytes(bytes, mode: FileMode.append, flush: true);
    } on Object {
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
    if (!_isWindows) await _setPermissions(path: rotatedFile.path, mode: "600");
    await currentFile.create(recursive: true);
    if (!_isWindows) await _setPermissions(path: currentFile.path, mode: "600");
    _currentFilePrepared = true;
  }

  List<int> _fitLineToCap({required String line}) {
    final full = utf8.encode("$line\n");
    if (full.length <= _maxFileBytes) return full;
    // Retain the newest complete Unicode scalars, including the trailing newline.
    final runes = line.runes.toList(growable: false);
    int start = runes.length;
    int byteLength = 1;
    while (start > 0) {
      final runeLength = utf8.encode(String.fromCharCode(runes[start - 1])).length;
      if (byteLength + runeLength > _maxFileBytes) break;
      start--;
      byteLength += runeLength;
    }
    return utf8.encode("${String.fromCharCodes(runes.skip(start))}\n");
  }

  static Future<void> _setPosixPermissions({required String path, required String mode}) async {
    final result = await Process.run("chmod", <String>[mode, path], runInShell: false);
    if (result.exitCode != 0) {
      final stderr = result.stderr.toString().trim();
      throw FileSystemException(
        stderr.isEmpty ? "chmod $mode failed with exit code ${result.exitCode}" : stderr,
        path,
      );
    }
  }
}
