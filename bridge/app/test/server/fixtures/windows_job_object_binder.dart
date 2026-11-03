import "dart:io";

import "package:sesori_bridge/src/server/api/windows_job_object_api.dart";

/// Test fixture: starts a long-lived `ping`, binds it to this process's
/// lifetime with the production [WindowsJobObjectApi] unless `--no-bind` is
/// passed, prints its pid and exits without stopping it.
Future<void> main(List<String> args) async {
  // Detached, so the child holds no pipe to this process that could end it.
  final ping = await Process.start("ping", ["-n", "60", "127.0.0.1"], mode: ProcessStartMode.detached);
  if (!args.contains("--no-bind")) {
    WindowsJobObjectApi().bindToBridgeLifetime(pid: ping.pid);
  }
  stdout.writeln(ping.pid);
  await stdout.flush();
  exit(0);
}
