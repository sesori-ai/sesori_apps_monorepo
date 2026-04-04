import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../foundation/process_runner.dart";

class GitCliApi {
  final ProcessRunner _processRunner;

  GitCliApi({ProcessRunner? processRunner}) : _processRunner = processRunner ?? ProcessRunner();

  Future<bool> hasGitHubRemote({required String projectPath}) async {
    try {
      final result = await _processRunner.run(
        "git",
        ["config", "--get", "remote.origin.url"],
        workingDirectory: projectPath,
        timeout: const Duration(seconds: 5),
      );

      if (result.exitCode != 0) return false;

      final output = result.stdout.toString().trim();
      return output.isNotEmpty && output.toLowerCase().contains("github.com");
    } on Object catch (e) {
      Log.w("[GitCli] failed to detect remote: $e");
      return false;
    }
  }
}
