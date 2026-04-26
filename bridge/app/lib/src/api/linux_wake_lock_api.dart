import "dart:async";
import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../bridge/foundation/process_starter.dart";
import "wake_lock_client.dart";

class LinuxWakeLockApi implements WakeLockClient {
  LinuxWakeLockApi({
    required ProcessStarter processStarter,
  }) : _processStarter = processStarter;

  final ProcessStarter _processStarter;

  Process? _process;

  @override
  Future<void> enable() async {
    if (_process != null) {
      return;
    }

    try {
      // Use `cat` instead of `sleep infinity` so the child exits when the
      // bridge dies. `cat` blocks on stdin; when the bridge process exits
      // (even via SIGKILL), the OS closes the stdin pipe, `cat` gets EOF,
      // exits, and systemd releases the inhibitor lock automatically.
      final process = await _processStarter(
        "systemd-inhibit",
        const <String>[
          "--what=idle:sleep",
          "--who=sesori-bridge",
          "--why=Bridge is running",
          "cat",
        ],
      );

      _process = process;
      unawaited(
        process.exitCode.then((exitCode) {
          if (_process == process) {
            _process = null;
            if (exitCode != 0) {
              Log.w("[wake-lock] systemd-inhibit exited unexpectedly with code $exitCode");
            }
          }
        }),
      );
    } on ProcessException catch (error) {
      Log.w("[wake-lock] systemd-inhibit unavailable: $error");
    }
  }

  @override
  Future<void> disable() async {
    final process = _process;
    _process = null;

    if (process == null) {
      return;
    }

    process.kill();
  }
}
