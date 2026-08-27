import "dart:async";
import "dart:io";

/// Streams bounded tracked-file names from Git without buffering the complete
/// repository index output in bridge memory.
class const GitTrackedFilesApi() {
  static const Duration _timeout = Duration(seconds: 15);
  static const List<String> _arguments = ["ls-files", "--cached", "-z", "--", "."];

  Future<List<String>> listTrackedFiles({required String projectPath, required int maximumPaths}) async {
    if (maximumPaths <= 0) {
      throw ArgumentError.value(maximumPaths, "maximumPaths", "must be positive");
    }

    final process = await Process.start(
      "git",
      _arguments,
      workingDirectory: projectPath,
      environment: const {"LC_ALL": "C"},
    );
    final stderrFuture = process.stderr.transform(const SystemEncoding().decoder).join();
    final operation = _collect(
      process: process,
      stderrFuture: stderrFuture,
      maximumPaths: maximumPaths,
    );
    return await operation.timeout(
      _timeout,
      onTimeout: () {
        process.kill();
        throw TimeoutException("git timed out after $_timeout", _timeout);
      },
    );
  }

  Future<List<String>> _collect({
    required Process process,
    required Future<String> stderrFuture,
    required int maximumPaths,
  }) async {
    final paths = <String>[];
    final currentPath = StringBuffer();

    await for (final chunk in process.stdout.transform(const SystemEncoding().decoder)) {
      var start = 0;
      while (start < chunk.length) {
        final terminator = chunk.indexOf("\u0000", start);
        if (terminator < 0) {
          currentPath.write(chunk.substring(start));
          break;
        }
        currentPath.write(chunk.substring(start, terminator));
        if (currentPath.isNotEmpty) paths.add(currentPath.toString());
        currentPath.clear();
        start = terminator + 1;
        if (paths.length == maximumPaths) {
          process.kill();
          await process.exitCode;
          await stderrFuture;
          return paths;
        }
      }
    }

    if (currentPath.isNotEmpty && paths.length < maximumPaths) paths.add(currentPath.toString());
    final exitCode = await process.exitCode;
    final stderr = await stderrFuture;
    if (exitCode != 0) {
      throw ProcessException("git", _arguments, stderr, exitCode);
    }
    return paths;
  }
}
