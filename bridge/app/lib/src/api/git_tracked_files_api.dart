import "dart:io";

import "../foundation/streaming_process_runner.dart";

/// Streams bounded tracked-file names from Git without buffering the complete
/// repository index output in bridge memory.
class GitTrackedFilesApi({required final StreamingProcessRunner _processRunner}) {
  static const Duration _timeout = Duration(seconds: 15);
  static const List<String> _arguments = ["ls-files", "--cached", "-z", "--", "."];

  Future<List<String>> listTrackedFiles({required String projectPath, required int maximumPaths}) async {
    if (maximumPaths <= 0) {
      throw ArgumentError.value(maximumPaths, "maximumPaths", "must be positive");
    }

    return await _processRunner.run(
      executable: "git",
      arguments: _arguments,
      workingDirectory: projectPath,
      environment: const {"LC_ALL": "C"},
      timeout: _timeout,
      operation: ({required process}) => _collect(process: process, maximumPaths: maximumPaths),
    );
  }

  Future<List<String>> _collect({
    required StreamingProcess process,
    required int maximumPaths,
  }) async {
    final paths = <String>[];
    final currentPath = StringBuffer();
    final stderrFuture = process.stderr.transform(const SystemEncoding().decoder).join();

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
        if (paths.length == maximumPaths) return paths;
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
