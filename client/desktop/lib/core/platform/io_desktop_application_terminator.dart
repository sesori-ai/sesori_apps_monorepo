import "dart:io" as io;

import "package:flutter/foundation.dart" show visibleForTesting;
import "package:injectable/injectable.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

@visibleForTesting
typedef DesktopProcessExit = void Function({required int exitCode});

@LazySingleton(as: DesktopApplicationTerminator)
class IoDesktopApplicationTerminator.forTesting({required final DesktopProcessExit _exit})
    implements DesktopApplicationTerminator {
  new() : this.forTesting(exit: ({required int exitCode}) => io.exit(exitCode));

  @visibleForTesting
  this;

  @override
  void terminate({required int exitCode}) {
    _exit(exitCode: exitCode);
  }
}
