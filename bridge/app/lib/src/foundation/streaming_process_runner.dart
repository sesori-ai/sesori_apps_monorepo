import "dart:async";
import "dart:io";

abstract interface class StreamingProcess() {
  Stream<List<int>> get stdout;

  Stream<List<int>> get stderr;

  Future<int> get exitCode;

  bool kill();
}

/// Runs a process whose output must be consumed incrementally, while owning
/// spawn, timeout, and final cleanup at the Foundation boundary.
class const StreamingProcessRunner() {
  Future<T> run<T>({
    required String executable,
    required List<String> arguments,
    required Future<T> Function({required StreamingProcess process}) operation,
    String? workingDirectory,
    Map<String, String>? environment,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final ioProcess = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
    );
    final process = _IoStreamingProcess(ioProcess);
    try {
      return await operation(process: process).timeout(
        timeout,
        onTimeout: () {
          process.kill();
          throw TimeoutException("$executable timed out after $timeout", timeout);
        },
      );
    } finally {
      process.kill();
    }
  }
}

final class _IoStreamingProcess(final Process _process) implements StreamingProcess {
  @override
  Stream<List<int>> get stdout => _process.stdout;

  @override
  Stream<List<int>> get stderr => _process.stderr;

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  bool kill() => _process.kill();
}
