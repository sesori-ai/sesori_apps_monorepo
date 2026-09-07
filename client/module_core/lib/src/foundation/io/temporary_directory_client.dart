import "dart:async";
import "dart:io";

import "package:injectable/injectable.dart";

import "../../logging/logging.dart";
import "../platform/temporary_directory_provider.dart";

/// App-wide cached seam around the platform's temporary-directory lookup.
///
/// The first lookup is shared by every caller; a failed lookup is forgotten so
/// the next caller retries. Voice starts warming this client when its
/// dependency graph is constructed as the composer mounts, so the platform call
/// normally finishes before the user's first recording gesture.
@lazySingleton
class TemporaryDirectoryClient({required final TemporaryDirectoryProvider _provider}) {
  Future<Directory>? _directory;

  Future<Directory> get directory {
    final cached = _directory;
    if (cached != null) return cached;

    final completer = Completer<Directory>();
    final resolution = completer.future;
    _directory = resolution;
    Future<Directory>.sync(_provider.temporaryDirectory).then(
      completer.complete,
      onError: (Object error, StackTrace stackTrace) {
        if (identical(_directory, resolution)) _directory = null;
        completer.completeError(error, stackTrace);
      },
    );
    return resolution;
  }

  /// Best-effort eager lookup; a failure is logged and retried on next use.
  Future<void> warmUp() async {
    try {
      await directory;
    } catch (error, stackTrace) {
      logw("Failed to warm the temporary-directory cache", error, stackTrace);
    }
  }
}
