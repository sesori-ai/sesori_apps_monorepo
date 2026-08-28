import "dart:async";
import "dart:io";

import "package:flutter/foundation.dart" show visibleForTesting;
import "package:injectable/injectable.dart";
import "package:path_provider/path_provider.dart" as path_provider;
import "package:sesori_desktop_core/sesori_desktop_core.dart";

@visibleForTesting
typedef DesktopApplicationSupportDirectoryLoader = Future<Directory> Function();

/// Flutter/path-provider implementation of the desktop-owned application-data
/// root used by supervision logs and later desktop-only persisted state.
@LazySingleton(as: DesktopApplicationSupportDirectory)
class FlutterDesktopApplicationSupportDirectory.forTesting({
  required final DesktopApplicationSupportDirectoryLoader _load,
}) implements DesktopApplicationSupportDirectory {
  Future<Directory>? _directory;

  new() : this.forTesting(load: path_provider.getApplicationSupportDirectory);

  @visibleForTesting
  this;

  @override
  Future<Directory> resolve() {
    final Future<Directory>? cached = _directory;
    if (cached != null) {
      return cached;
    }

    final Completer<Directory> completer = Completer<Directory>();
    final Future<Directory> resolution = completer.future;
    _directory = resolution;
    Future<Directory>.sync(_load).then(
      completer.complete,
      onError: (Object error, StackTrace stackTrace) {
        if (identical(_directory, resolution)) {
          _directory = null;
        }
        completer.completeError(error, stackTrace);
      },
    );
    return resolution;
  }
}
