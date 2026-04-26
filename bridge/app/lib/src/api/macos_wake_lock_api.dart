import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "wake_lock_client.dart";

typedef ProcessStarter = Future<Process> Function(String executable, List<String> arguments);

class MacOSWakeLockApi implements WakeLockClient {
  final ProcessStarter _processStarter;
  Process? _process;

  MacOSWakeLockApi({required ProcessStarter processStarter}) : _processStarter = processStarter;

  @override
  Future<void> enable() async {
    await disable();
    try {
      _process = await _processStarter("caffeinate", <String>["-w", pid.toString()]);
    } on ProcessException catch (error) {
      Log.w("[wake-lock] caffeinate unavailable: $error");
    }
  }

  @override
  Future<void> disable() async {
    final process = _process;
    _process = null;
    process?.kill();
  }
}
