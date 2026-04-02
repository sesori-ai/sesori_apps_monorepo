import "dart:io";

import "../worktree_service.dart";

/// Detects if a project has a GitHub remote.
///
/// Runs `git config --get remote.origin.url` in the project directory
/// and checks if the output contains "github.com" (case-insensitive).
///
/// Returns true if:
/// - Command succeeds (exit code 0)
/// - Output contains "github.com" (case-insensitive)
///
/// Returns false if:
/// - Command fails (non-zero exit code)
/// - Command times out (5 seconds)
/// - Output is empty
/// - Output does not contain "github.com"
Future<bool> hasGitHubRemote({
  required ProcessRunner processRunner,
  required String projectPath,
}) async {
  try {
    final result =
        await processRunner(
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
    return false;
  }
}
