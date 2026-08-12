import "dart:async";
import "dart:io";

import "package:flutter/foundation.dart" show visibleForTesting;
import "package:injectable/injectable.dart";
import "package:path_provider/path_provider.dart" as path_provider;
import "package:sesori_dart_core/logging.dart";

typedef TemporaryDirectoryLoader = Future<Directory> Function();

/// App-wide cached seam around path_provider's temporary-directory lookup.
///
/// Voice starts warming this client when its dependency graph is constructed as
/// the composer mounts, so the platform call normally finishes before the
/// user's first recording gesture.
@lazySingleton
class TemporaryDirectoryClient.forTesting({required TemporaryDirectoryLoader load}) {
  final TemporaryDirectoryLoader _load;
  Future<Directory>? _directory;

  TemporaryDirectoryClient() : this.forTesting(load: path_provider.getTemporaryDirectory);

  @visibleForTesting
  this : _load = load;

  Future<Directory> get directory {
    final cached = _directory;
    if (cached != null) return cached;

    final completer = Completer<Directory>();
    final resolution = completer.future;
    _directory = resolution;
    Future<Directory>.sync(_load).then(
      completer.complete,
      onError: (Object error, StackTrace stackTrace) {
        if (identical(_directory, resolution)) _directory = null;
        completer.completeError(error, stackTrace);
      },
    );
    return resolution;
  }

  Future<void> warmUp() async {
    try {
      await directory;
    } catch (error, stackTrace) {
      logw("Failed to warm the temporary-directory cache", error, stackTrace);
    }
  }
}
