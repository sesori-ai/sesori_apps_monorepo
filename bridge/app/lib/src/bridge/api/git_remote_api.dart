import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../foundation/process_runner.dart";

class GitRemoteApi {
  final ProcessRunner _processRunner;

  GitRemoteApi({ProcessRunner processRunner = Process.run}) : _processRunner = processRunner;

  /// Detects if a project has a GitHub remote.
  ///
  /// Runs `git config --get remote.origin.url` in the project directory
  /// and checks if the output contains "github.com" (case-insensitive).
  Future<bool> hasGitHubRemote({required String projectPath}) async {
    try {
      final result =
          await _processRunner(
                "git",
                ["config", "--get", "remote.origin.url"],
                workingDirectory: projectPath,
              )
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () => ProcessResult(0, 1, "", ""),
              )
              .catchError((_) => ProcessResult(0, 1, "", ""));

      if (result.exitCode != 0) {
        return false;
      }

      final output = result.stdout.toString().trim();
      if (output.isEmpty) {
        return false;
      }

      return output.toLowerCase().contains("github.com");
    } catch (e) {
      Log.w("[remote] failed to detect remote: $e");
      return false;
    }
  }
}
