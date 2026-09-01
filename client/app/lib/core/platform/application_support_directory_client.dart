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

  Future<Directory> get directory => _directory ??= _load();
}
