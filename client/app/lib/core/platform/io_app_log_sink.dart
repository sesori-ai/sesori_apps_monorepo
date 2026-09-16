import "dart:convert";
import "dart:io";

import "package:flutter/foundation.dart" show visibleForTesting;
import "package:injectable/injectable.dart";
import "package:path/path.dart" as path;
import "package:sesori_dart_core/sesori_dart_core.dart";

/// Mobile's app-private cache is excluded from OS backup and may be evicted.
@LazySingleton(as: LogSink)
class IoAppLogSink.forTesting({
  required final TemporaryDirectoryClient _directoryClient,
  required final int _maxFileBytes,
  required final void Function(String message) _reportFailure,
}) implements LogSink {
  new({required TemporaryDirectoryClient directoryClient})
    : this.forTesting(directoryClient: directoryClient, maxFileBytes: 5 * 1024 * 1024, reportFailure: stderr.writeln);

  @visibleForTesting
  this : assert(_maxFileBytes > 0, "maxFileBytes must be positive");

  Future<void> _writeTail = Future<void>.value();
  bool _failureReported = false;

  @override
  void write({required LogRecord record}) {
    const StdoutLogSink().write(record: record);
    _writeTail = _writeTail.then((_) => _append(record: record));
  }

  Future<void> _append({required LogRecord record}) async {
    try {
      final root = await _directoryClient.directory;
      final directory = Directory(path.join(root.path, "logs"));
      await directory.create(recursive: true);
      final file = File(path.join(directory.path, "app.log"));
      final rotated = File("${file.path}.1");
      var bytes = utf8.encode("${record.formatted}\n");
      if (bytes.length > _maxFileBytes) {
        var start = bytes.length - _maxFileBytes;
        // Skip a partial leading UTF-8 scalar; preserve the newest complete ones.
        while ((bytes[start] & 0xc0) == 0x80) {
          start++;
        }
        bytes = bytes.sublist(start);
      }
      // ignore: avoid_slow_async_io, log IO must not block the UI isolate
      if (await file.exists()) {
        final length = await file.length();
        if (length > 0 && length + bytes.length > _maxFileBytes) {
          // ignore: avoid_slow_async_io, log IO must not block the UI isolate
          if (await rotated.exists()) await rotated.delete();
          await file.rename(rotated.path);
        }
      }
      await file.writeAsBytes(bytes, mode: FileMode.append, flush: true);
      _failureReported = false;
    } on Object catch (error, stackTrace) {
      if (!_failureReported) {
        _failureReported = true;
        _reportFailure(
          "Failed to persist mobile app logs; console output remains available: ${error.toString()}\n${stackTrace.toString()}",
        );
      }
    }
  }

  @override
  Future<void> flush() => _writeTail;
}
