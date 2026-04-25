import "dart:async";
import "dart:io";

import "wake_lock_client.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

typedef ProcessStarter = Future<Process> Function(
  String executable,
  List<String> arguments,
);

class LinuxWakeLockApi implements WakeLockClient {
  LinuxWakeLockApi({required ProcessStarter processStarter})
      : _processStarter = processStarter;

  final ProcessStarter _processStarter;

  Process? _process;

  @override
  Future<void> enable() async {
    if (_process != null) {
      return;
    }

    try {
      final process = await _processStarter(
        "systemd-inhibit",
        const <String>[
          "--what=idle:sleep",
          "--who=sesori-bridge",
          "--why=Bridge is running",
          "sleep",
          "infinity",
        ],
      );

      _process = process;
      unawaited(
        process.exitCode.then((exitCode) {
          if (_process == process) {
            _process = null;
          }
          if (exitCode != 0) {
            Log.w("[wake-lock] systemd-inhibit exited with code $exitCode");
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
