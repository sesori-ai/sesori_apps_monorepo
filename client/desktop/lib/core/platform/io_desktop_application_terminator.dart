import "dart:async";
import "dart:io" as io;

import "package:flutter/foundation.dart" show visibleForTesting;
import "package:flutter/services.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

import "macos_termination_channel.dart";

/// Ends the process. On macOS the runner terminates through AppKit, so a
/// pending system quit request is answered and Sparkle can install on quit.
@LazySingleton(as: DesktopApplicationTerminator)
class IoDesktopApplicationTerminator.forTesting({
  required final bool _isMacOS,
  required final MethodChannel _channel,
  required final void Function() _exit,
}) implements DesktopApplicationTerminator {
  new() : this.forTesting(isMacOS: io.Platform.isMacOS, channel: macosTerminationChannel, exit: () => io.exit(0));

  @visibleForTesting
  this;

  @override
  void terminate() {
    if (_isMacOS) {
      unawaited(_terminateThroughRunner());
    } else {
      _exit();
    }
  }

  @override
  void cancelTermination() {
    if (_isMacOS) {
      unawaited(
        _invoke(method: "cancelTermination").catchError((Object error, StackTrace stackTrace) {
          logw("Failed to decline the macOS quit request", error, stackTrace);
        }),
      );
    }
  }

  Future<void> _terminateThroughRunner() async {
    try {
      await _invoke(method: "terminate");
    } on Object catch (error, stackTrace) {
      logw("The macOS runner did not terminate; exiting directly", error, stackTrace);
      _exit();
    }
  }

  Future<void> _invoke({required String method}) => _channel.invokeMethod<void>(method);
}
