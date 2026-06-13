import 'dart:io';

import '../../bridge/foundation/post_update_restart_flag.dart';

typedef RelaunchProcessStarter =
    Future<Process> Function(
      String executable,
      List<String> arguments, {
      required Map<String, String>? environment,
      required ProcessStartMode mode,
    });

class UpdateRelaunchClient {
  UpdateRelaunchClient({required RelaunchProcessStarter processStarter}) : _processStarter = processStarter;

  final RelaunchProcessStarter _processStarter;

  Future<Never> relaunchWindowsSwapScript({required String scriptPath}) async {
    await _processStarter(
      'powershell',
      ['-ExecutionPolicy', 'Bypass', '-File', scriptPath],
      environment: const <String, String>{sesoriPostUpdateRestartEnvVar: '1'},
      mode: ProcessStartMode.detached,
    );
    exit(0);
  }

  Future<Never> relaunchBinary({
    required String binaryPath,
    required List<String> args,
  }) async {
    await _processStarter(
      binaryPath,
      args,
      environment: const <String, String>{sesoriPostUpdateRestartEnvVar: '1'},
      mode: ProcessStartMode.inheritStdio,
    );
    exit(0);
  }
}
