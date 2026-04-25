import "dart:io";

import "wake_lock_client.dart";

typedef ProcessStarter = Future<Process> Function(String executable, List<String> arguments);

class MacOSWakeLockApi implements WakeLockClient {
  final ProcessStarter _processStarter;
  Process? _process;

  MacOSWakeLockApi({required ProcessStarter processStarter}) : _processStarter = processStarter;

  @override
  Future<void> enable() async {
    await disable();
    _process = await _processStarter("caffeinate", <String>["-w", pid.toString()]);
  }

  @override
  Future<void> disable() async {
    final process = _process;
    _process = null;
    process?.kill();
  }
}
