import "dart:async";
import "dart:io";

/// Runs shell commands with automatic subprocess cleanup on timeout.
///
/// Production code uses the default implementation which spawns real processes
/// via [Process.start] and kills them on timeout. Tests create a class that
/// `implements ProcessRunner` and override [run].
class ProcessRunner {
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
    );
    final stdout = StringBuffer();
    final stderr = StringBuffer();
    process.stdout.transform(const SystemEncoding().decoder).listen(stdout.write);
    process.stderr.transform(const SystemEncoding().decoder).listen(stderr.write);

    final exitCode = await process.exitCode.timeout(
      timeout,
      onTimeout: () {
        process.kill();
        throw TimeoutException("$executable timed out after $timeout", timeout);
      },
    );
    return ProcessResult(process.pid, exitCode, stdout.toString(), stderr.toString());
  }

  /// Spawns [executable] and returns its pid without waiting for it to exit.
  ///
  /// The child runs with [ProcessStartMode.inheritStdio] so it attaches to the
  /// same terminal and keeps running after this process exits — used to launch a
  /// successor bridge during a restart. Throws if the process cannot be started.
  Future<int> startDetached(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      environment: environment,
      mode: ProcessStartMode.inheritStdio,
    );
    return process.pid;
  }
}
