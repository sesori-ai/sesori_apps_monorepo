import "dart:async";
import "dart:io";

import "package:sesori_bridge/src/api/wake_lock_client.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

typedef ProcessStarter = Future<Process> Function(
  String executable,
  List<String> arguments,
);

Future<Process> _defaultProcessStarter(
  String executable,
  List<String> arguments,
) {
  return Process.start(executable, arguments);
}

class LinuxWakeLockApi implements WakeLockClient {
  LinuxWakeLockApi({ProcessStarter? processStarter})
      : _processStarter = processStarter ?? _defaultProcessStarter;

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
        process.exitCode.then((_) {
          if (_process == process) {
            _process = null;
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
