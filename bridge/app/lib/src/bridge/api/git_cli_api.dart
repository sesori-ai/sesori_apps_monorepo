import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../foundation/process_runner.dart";

class GitCliApi {
  final ProcessRunner _processRunner;

  GitCliApi({ProcessRunner processRunner = Process.run}) : _processRunner = processRunner;

  Future<bool> hasGitHubRemote({required String projectPath}) async {
    try {
      final result =
          await _processRunner(
            "git",
            ["config", "--get", "remote.origin.url"],
            workingDirectory: projectPath,
          ).timeout(
            const Duration(seconds: 5),
            onTimeout: () => ProcessResult(0, 1, "", ""),
          );

      if (result.exitCode != 0) return false;

      final output = result.stdout.toString().trim();
      return output.isNotEmpty && output.toLowerCase().contains("github.com");
    } on Object catch (e) {
      Log.w("[GitRemote] failed to detect remote: $e");
      return false;
    }
  }
}
