import "dart:async";
import "dart:io";

import "package:flutter/foundation.dart" show visibleForTesting;
import "package:injectable/injectable.dart";
import "package:path_provider/path_provider.dart" as path_provider;

typedef ApplicationSupportDirectoryLoader = Future<Directory> Function();

/// Cached injectable seam around path_provider's app-support directory lookup.
@lazySingleton
class ApplicationSupportDirectoryClient.forTesting({
  required final ApplicationSupportDirectoryLoader _load,
}) {
  Future<Directory>? _directory;

  new() : this.forTesting(load: path_provider.getApplicationSupportDirectory);

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
