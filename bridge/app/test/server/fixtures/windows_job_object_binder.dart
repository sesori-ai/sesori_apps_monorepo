import "dart:async";
import "dart:convert";
import "dart:io";

import "package:sesori_bridge/src/server/api/windows_job_object_api.dart";

/// Test fixture standing in for the bridge.
///
/// With `--start-in-job` it starts PowerShell through `cmd.exe` inside the job
/// with the production [WindowsJobObjectApi], prints the PowerShell pid it
/// reports and stays alive until it is killed.
///
/// Otherwise it starts a long-lived `ping`, binds it to this process's
/// lifetime unless `--no-bind` is passed, prints its pid and exits without
/// stopping it.
Future<void> main(List<String> args) async {
  if (args.contains("--start-in-job")) {
    final shell = WindowsJobObjectApi().startBoundToBridgeLifetime(
      executable: "powershell",
      arguments: [
        "-NoProfile",
        "-NonInteractive",
        "-Command",
        r"[Console]::WriteLine($PID); [Console]::Out.Flush(); Start-Sleep 60",
      ],
      environment: null,
      workingDirectory: null,
      runInShell: true,
      includeParentEnvironment: true,
    );
    unawaited(shell.stdin.close());
    unawaited(shell.stderr.drain<void>());
    stdout.writeln(await shell.stdout.transform(utf8.decoder).transform(const LineSplitter()).first);
    await stdout.flush();
    await shell.exitCode;
    return;
  }

  // Detached, so the child holds no pipe to this process that could end it.
  final ping = await Process.start("ping", ["-n", "60", "127.0.0.1"], mode: ProcessStartMode.detached);
  if (!args.contains("--no-bind")) {
    WindowsJobObjectApi().bindToBridgeLifetime(pid: ping.pid);
  }
  stdout.writeln(ping.pid);
  await stdout.flush();
  exit(0);
}
