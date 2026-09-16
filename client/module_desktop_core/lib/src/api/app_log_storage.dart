import "dart:io";

import "package:injectable/injectable.dart";
import "package:meta/meta.dart";
import "package:path/path.dart" as path;
import "package:sesori_dart_core/logging.dart";

import "../foundation/platform/desktop_application_support_directory.dart";
import "rotating_file_storage.dart";

/// Desktop's finite, best-effort app-log writes; helper logs remain independent.
@LazySingleton(as: LogSink)
class AppLogStorage.forTesting({
  required final DesktopApplicationSupportDirectory _applicationSupportDirectory,
  required final RotatingFileStorage _storage,
  required final void Function(String message) _reportFailure,
}) implements LogSink {
  new({required DesktopApplicationSupportDirectory applicationSupportDirectory})
    : this.forTesting(
        applicationSupportDirectory: applicationSupportDirectory,
        storage: RotatingFileStorage(fileName: "app.log"),
        reportFailure: stderr.writeln,
      );

  @visibleForTesting
  this;

  Future<void> _lastWrite = Future<void>.value();
  bool _failureReported = false;

  @override
  void write({required LogRecord record}) {
    const StdoutLogSink().write(record: record);
    _lastWrite = _lastWrite.then((_) => _append(record: record));
  }

  Future<void> _append({required LogRecord record}) async {
    try {
      final root = await _applicationSupportDirectory.resolve();
      await _storage.appendLine(directory: Directory(path.join(root.path, "logs")), line: record.formatted);
      _failureReported = false;
    } on Object catch (error, stackTrace) {
      if (!_failureReported) {
        _failureReported = true;
        _reportFailure(
          "Failed to persist desktop app logs; console output remains available: ${error.toString()}\n${stackTrace.toString()}",
        );
      }
    }
  }

  @override
  Future<void> flush() => _lastWrite;
}
