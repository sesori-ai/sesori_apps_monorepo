import 'dart:io';

class UpdateRelaunchClient {
  Future<Never> relaunchWindowsSwapScript({required String scriptPath}) async {
    await Process.start(
      'powershell',
      ['-ExecutionPolicy', 'Bypass', '-File', scriptPath],
      mode: ProcessStartMode.detached,
    );
    exit(0);
  }

  Future<Never> relaunchBinary({
    required String binaryPath,
    required List<String> args,
  }) async {
    await Process.start(
      binaryPath,
      args,
      mode: ProcessStartMode.inheritStdio,
    );
    exit(0);
  }
}
