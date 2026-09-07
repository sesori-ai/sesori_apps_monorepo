import "dart:async";
import "dart:io";

import "package:sesori_bridge/src/api/git_cli_api.dart";
import "package:sesori_bridge/src/foundation/process_runner.dart";
import "package:sesori_bridge/src/foundation/streaming_process_runner.dart";
import "package:test/test.dart";

import "../../helpers/fake_process_runner.dart";

void main() {
  group("hasGitHubRemote", () {
    test("returns true for GitHub HTTPS URL", () async {
      final mockRunner = RecordingProcessRunner(exitCode: 0, stdout: "https://github.com/org/repo.git");

      final result = await _hasGitHubRemote(runner: mockRunner, projectPath: "/path/to/project");

      expect(result, isTrue);
    });

    test("returns true for GitHub SSH URL", () async {
      final mockRunner = RecordingProcessRunner(exitCode: 0, stdout: "git@github.com:org/repo.git");

      final result = await _hasGitHubRemote(runner: mockRunner, projectPath: "/path/to/project");

      expect(result, isTrue);
    });

    test("returns true for github.com with uppercase", () async {
      final mockRunner = RecordingProcessRunner(exitCode: 0, stdout: "https://GitHub.COM/org/repo.git");

      final result = await _hasGitHubRemote(runner: mockRunner, projectPath: "/path/to/project");

      expect(result, isTrue);
    });

    test("returns false for GitLab URL", () async {
      final mockRunner = RecordingProcessRunner(exitCode: 0, stdout: "https://gitlab.com/org/repo.git");

      final result = await _hasGitHubRemote(runner: mockRunner, projectPath: "/path/to/project");

      expect(result, isFalse);
    });

    test("returns false for local path", () async {
      final mockRunner = RecordingProcessRunner(exitCode: 0, stdout: "/path/to/local/repo");

      final result = await _hasGitHubRemote(runner: mockRunner, projectPath: "/path/to/project");

      expect(result, isFalse);
    });

    test("returns false for empty output", () async {
      final mockRunner = RecordingProcessRunner(exitCode: 0, stdout: "");

      final result = await _hasGitHubRemote(runner: mockRunner, projectPath: "/path/to/project");

      expect(result, isFalse);
    });

    test("returns false for whitespace-only output", () async {
      final mockRunner = RecordingProcessRunner(
        exitCode: 0,
        stdout: "   \n  \t  ",
      );

      final result = await _hasGitHubRemote(runner: mockRunner, projectPath: "/path/to/project");

      expect(result, isFalse);
    });

    test("returns false on non-zero exit code", () async {
      final mockRunner = RecordingProcessRunner(exitCode: 1, stdout: "https://github.com/org/repo.git");

      final result = await _hasGitHubRemote(runner: mockRunner, projectPath: "/path/to/project");

      expect(result, isFalse);
    });

    test("returns false on timeout", () async {
      final mockRunner = RecordingProcessRunner(
        responder: (_, _, {environment, workingDirectory, timeout = const Duration(seconds: 15)}) {
          throw TimeoutException("timed out", timeout);
        },
      );

      final result = await _hasGitHubRemote(runner: mockRunner, projectPath: "/path/to/project");

      expect(result, isFalse);
    });

    test("passes correct working directory to process runner", () async {
      final mockRunner = RecordingProcessRunner(exitCode: 0, stdout: "https://github.com/org/repo.git");

      await _hasGitHubRemote(runner: mockRunner, projectPath: "/my/project/path");

      expect(mockRunner.invocations.single.workingDirectory, equals("/my/project/path"));
    });

    test("passes correct git command to process runner", () async {
      final mockRunner = RecordingProcessRunner(exitCode: 0, stdout: "https://github.com/org/repo.git");

      await _hasGitHubRemote(runner: mockRunner, projectPath: "/path/to/project");

      expect(mockRunner.invocations.single.executable, equals("git"));
      expect(mockRunner.invocations.single.arguments, equals(["config", "--get", "remote.origin.url"]));
    });

    test("handles exception from process runner", () async {
      final mockRunner = RecordingProcessRunner(
        responder: (_, _, {environment, workingDirectory, timeout = const Duration(seconds: 15)}) {
          return ProcessResult(0, 127, "", "command not found");
        },
      );

      final result = await _hasGitHubRemote(runner: mockRunner, projectPath: "/path/to/project");

      expect(result, isFalse);
    });

    test("trims whitespace from output", () async {
      final mockRunner = RecordingProcessRunner(
        exitCode: 0,
        stdout: "  \n  https://github.com/org/repo.git  \n  ",
      );

      final result = await _hasGitHubRemote(runner: mockRunner, projectPath: "/path/to/project");

      expect(result, isTrue);
    });
  });
}

/// Runs the remote check through a real [GitCliApi] backed by [runner].
///
/// Every case in this suite exercises the same wiring; only the process
/// responses and the project path differ.
Future<bool> _hasGitHubRemote({required ProcessRunner runner, required String projectPath}) {
  return GitCliApi(
    streamingProcessRunner: const StreamingProcessRunner(),
    processRunner: runner,
    gitPathExists: ({required String gitPath}) => true,
  ).hasGitHubRemote(projectPath: projectPath);
}
