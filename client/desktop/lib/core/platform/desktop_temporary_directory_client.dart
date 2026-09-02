import "dart:async";
import "dart:io";

import "package:flutter/foundation.dart" show visibleForTesting;
import "package:injectable/injectable.dart";
import "package:path_provider/path_provider.dart" as path_provider;

@visibleForTesting
typedef DesktopTemporaryDirectoryLoader = Future<Directory> Function();

/// Cached seam around path_provider's app-private temporary directory.
@lazySingleton
class DesktopTemporaryDirectoryClient.forTesting({
  required final DesktopTemporaryDirectoryLoader _load,
}) {
  Future<Directory>? _directory;

  new() : this.forTesting(load: path_provider.getTemporaryDirectory);

  @visibleForTesting
  this;

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
}
