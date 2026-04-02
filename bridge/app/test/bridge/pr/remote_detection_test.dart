import "dart:io";

import "package:sesori_bridge/src/bridge/pr/remote_detection.dart";
import "package:sesori_bridge/src/bridge/worktree_service.dart";
import "package:test/test.dart";

void main() {
  group("hasGitHubRemote", () {
    test("returns true for GitHub HTTPS URL", () async {
      final mockRunner = _createMockRunner(
        exitCode: 0,
        stdout: "https://github.com/org/repo.git",
      );

      final result = await hasGitHubRemote(
        processRunner: mockRunner,
        projectPath: "/path/to/project",
      );

      expect(result, isTrue);
    });

    test("returns true for GitHub SSH URL", () async {
      final mockRunner = _createMockRunner(
        exitCode: 0,
        stdout: "git@github.com:org/repo.git",
      );

      final result = await hasGitHubRemote(
        processRunner: mockRunner,
        projectPath: "/path/to/project",
      );

      expect(result, isTrue);
    });

    test("returns true for github.com with uppercase", () async {
      final mockRunner = _createMockRunner(
        exitCode: 0,
        stdout: "https://GitHub.COM/org/repo.git",
      );

      final result = await hasGitHubRemote(
        processRunner: mockRunner,
        projectPath: "/path/to/project",
      );

      expect(result, isTrue);
    });

    test("returns false for GitLab URL", () async {
      final mockRunner = _createMockRunner(
        exitCode: 0,
        stdout: "https://gitlab.com/org/repo.git",
      );

      final result = await hasGitHubRemote(
        processRunner: mockRunner,
        projectPath: "/path/to/project",
      );

      expect(result, isFalse);
    });

    test("returns false for local path", () async {
      final mockRunner = _createMockRunner(
        exitCode: 0,
        stdout: "/path/to/local/repo",
      );

      final result = await hasGitHubRemote(
        processRunner: mockRunner,
        projectPath: "/path/to/project",
      );

      expect(result, isFalse);
    });

    test("returns false for empty output", () async {
      final mockRunner = _createMockRunner(
        exitCode: 0,
        stdout: "",
      );

      final result = await hasGitHubRemote(
        processRunner: mockRunner,
        projectPath: "/path/to/project",
      );

      expect(result, isFalse);
    });

    test("returns false for whitespace-only output", () async {
      final mockRunner = _createMockRunner(
        exitCode: 0,
        stdout: "   \n  \t  ",
      );

      final result = await hasGitHubRemote(
        processRunner: mockRunner,
        projectPath: "/path/to/project",
      );

      expect(result, isFalse);
    });

    test("returns false on non-zero exit code", () async {
      final mockRunner = _createMockRunner(
        exitCode: 1,
        stdout: "https://github.com/org/repo.git",
      );

      final result = await hasGitHubRemote(
        processRunner: mockRunner,
        projectPath: "/path/to/project",
      );

      expect(result, isFalse);
    });

    test("returns false on timeout", () async {
      Future<ProcessResult> mockRunner(
        String executable,
        List<String> arguments, {
        String? workingDirectory,
      }) async {
        await Future<void>.delayed(const Duration(seconds: 10));
        return ProcessResult(0, 0, "https://github.com/org/repo.git", "");
      }

      final result = await hasGitHubRemote(
        processRunner: mockRunner,
        projectPath: "/path/to/project",
      );

      expect(result, isFalse);
    });

    test("passes correct working directory to process runner", () async {
      String? capturedWorkdir;
      Future<ProcessResult> mockRunner(
        String executable,
        List<String> arguments, {
        String? workingDirectory,
      }) async {
        capturedWorkdir = workingDirectory;
        return ProcessResult(0, 0, "https://github.com/org/repo.git", "");
      }

      await hasGitHubRemote(
        processRunner: mockRunner,
        projectPath: "/my/project/path",
      );

      expect(capturedWorkdir, equals("/my/project/path"));
    });

    test("passes correct git command to process runner", () async {
      String? capturedExecutable;
      List<String>? capturedArgs;
      Future<ProcessResult> mockRunner(
        String executable,
        List<String> arguments, {
        String? workingDirectory,
      }) async {
        capturedExecutable = executable;
        capturedArgs = arguments;
        return ProcessResult(0, 0, "https://github.com/org/repo.git", "");
      }

      await hasGitHubRemote(
        processRunner: mockRunner,
        projectPath: "/path/to/project",
      );

      expect(capturedExecutable, equals("git"));
      expect(capturedArgs, equals(["config", "--get", "remote.origin.url"]));
    });

    test("handles exception from process runner", () async {
      Future<ProcessResult> mockRunner(
        String executable,
        List<String> arguments, {
        String? workingDirectory,
      }) async {
        // Simulate an exception by returning a failed result
        return ProcessResult(0, 127, "", "command not found");
      }

      final result = await hasGitHubRemote(
        processRunner: mockRunner,
        projectPath: "/path/to/project",
      );

      expect(result, isFalse);
    });

    test("trims whitespace from output", () async {
      final mockRunner = _createMockRunner(
        exitCode: 0,
        stdout: "  \n  https://github.com/org/repo.git  \n  ",
      );

      final result = await hasGitHubRemote(
        processRunner: mockRunner,
        projectPath: "/path/to/project",
      );

      expect(result, isTrue);
    });
  });
}

ProcessRunner _createMockRunner({
  required int exitCode,
  required String stdout,
}) {
  return (String executable, List<String> arguments, {String? workingDirectory}) async {
    return ProcessResult(0, exitCode, stdout, "");
  };
}
