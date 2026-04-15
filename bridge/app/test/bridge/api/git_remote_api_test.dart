import "dart:async";
import "dart:io";

import "package:sesori_bridge/src/bridge/api/git_cli_api.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:test/test.dart";

void main() {
  group("hasGitHubRemote", () {
    test("returns true for GitHub HTTPS URL", () async {
      final mockRunner = FakeProcessRunner.result(
        exitCode: 0,
        stdout: "https://github.com/org/repo.git",
      );

      final result =
          await GitCliApi(
            processRunner: mockRunner,
            gitPathExists: ({required String gitPath}) => true,
          ).hasGitHubRemote(
            projectPath: "/path/to/project",
          );

      expect(result, isTrue);
    });

    test("returns true for GitHub SSH URL", () async {
      final mockRunner = FakeProcessRunner.result(
        exitCode: 0,
        stdout: "git@github.com:org/repo.git",
      );

      final result =
          await GitCliApi(
            processRunner: mockRunner,
            gitPathExists: ({required String gitPath}) => true,
          ).hasGitHubRemote(
            projectPath: "/path/to/project",
          );

      expect(result, isTrue);
    });

    test("returns true for github.com with uppercase", () async {
      final mockRunner = FakeProcessRunner.result(
        exitCode: 0,
        stdout: "https://GitHub.COM/org/repo.git",
      );

      final result =
          await GitCliApi(
            processRunner: mockRunner,
            gitPathExists: ({required String gitPath}) => true,
          ).hasGitHubRemote(
            projectPath: "/path/to/project",
          );

      expect(result, isTrue);
    });

    test("returns false for GitLab URL", () async {
      final mockRunner = FakeProcessRunner.result(
        exitCode: 0,
        stdout: "https://gitlab.com/org/repo.git",
      );

      final result =
          await GitCliApi(
            processRunner: mockRunner,
            gitPathExists: ({required String gitPath}) => true,
          ).hasGitHubRemote(
            projectPath: "/path/to/project",
          );

      expect(result, isFalse);
    });

    test("returns false for local path", () async {
      final mockRunner = FakeProcessRunner.result(
        exitCode: 0,
        stdout: "/path/to/local/repo",
      );

      final result =
          await GitCliApi(
            processRunner: mockRunner,
            gitPathExists: ({required String gitPath}) => true,
          ).hasGitHubRemote(
            projectPath: "/path/to/project",
          );

      expect(result, isFalse);
    });

    test("returns false for empty output", () async {
      final mockRunner = FakeProcessRunner.result(
        exitCode: 0,
        stdout: "",
      );

      final result =
          await GitCliApi(
            processRunner: mockRunner,
            gitPathExists: ({required String gitPath}) => true,
          ).hasGitHubRemote(
            projectPath: "/path/to/project",
          );

      expect(result, isFalse);
    });

    test("returns false for whitespace-only output", () async {
      final mockRunner = FakeProcessRunner.result(
        exitCode: 0,
        stdout: "   \n  \t  ",
      );

      final result =
          await GitCliApi(
            processRunner: mockRunner,
            gitPathExists: ({required String gitPath}) => true,
          ).hasGitHubRemote(
            projectPath: "/path/to/project",
          );

      expect(result, isFalse);
    });

    test("returns false on non-zero exit code", () async {
      final mockRunner = FakeProcessRunner.result(
        exitCode: 1,
        stdout: "https://github.com/org/repo.git",
      );

      final result =
          await GitCliApi(
            processRunner: mockRunner,
            gitPathExists: ({required String gitPath}) => true,
          ).hasGitHubRemote(
            projectPath: "/path/to/project",
          );

      expect(result, isFalse);
    });

    test("returns false on timeout", () async {
      final mockRunner = FakeProcessRunner((
        String executable,
        List<String> arguments, {
        String? workingDirectory,
        Duration timeout = const Duration(seconds: 15),
      }) async {
        throw TimeoutException("timed out", timeout);
      });

      final result =
          await GitCliApi(
            processRunner: mockRunner,
            gitPathExists: ({required String gitPath}) => true,
          ).hasGitHubRemote(
            projectPath: "/path/to/project",
          );

      expect(result, isFalse);
    });

    test("passes correct working directory to process runner", () async {
      final mockRunner = FakeProcessRunner.result(
        exitCode: 0,
        stdout: "https://github.com/org/repo.git",
      );

      await GitCliApi(
        processRunner: mockRunner,
        gitPathExists: ({required String gitPath}) => true,
      ).hasGitHubRemote(
        projectPath: "/my/project/path",
      );

      expect(mockRunner.invocations.single.workingDirectory, equals("/my/project/path"));
    });

    test("passes correct git command to process runner", () async {
      final mockRunner = FakeProcessRunner.result(
        exitCode: 0,
        stdout: "https://github.com/org/repo.git",
      );

      await GitCliApi(
        processRunner: mockRunner,
        gitPathExists: ({required String gitPath}) => true,
      ).hasGitHubRemote(
        projectPath: "/path/to/project",
      );

      expect(mockRunner.invocations.single.executable, equals("git"));
      expect(mockRunner.invocations.single.arguments, equals(["config", "--get", "remote.origin.url"]));
    });

    test("handles exception from process runner", () async {
      final mockRunner = FakeProcessRunner((
        String executable,
        List<String> arguments, {
        String? workingDirectory,
        Duration timeout = const Duration(seconds: 15),
      }) async {
        return ProcessResult(0, 127, "", "command not found");
      });

      final result =
          await GitCliApi(
            processRunner: mockRunner,
            gitPathExists: ({required String gitPath}) => true,
          ).hasGitHubRemote(
            projectPath: "/path/to/project",
          );

      expect(result, isFalse);
    });

    test("trims whitespace from output", () async {
      final mockRunner = FakeProcessRunner.result(
        exitCode: 0,
        stdout: "  \n  https://github.com/org/repo.git  \n  ",
      );

      final result =
          await GitCliApi(
            processRunner: mockRunner,
            gitPathExists: ({required String gitPath}) => true,
          ).hasGitHubRemote(
            projectPath: "/path/to/project",
          );

      expect(result, isTrue);
    });
  });
}

class Invocation {
  final String executable;
  final List<String> arguments;
  final String? workingDirectory;

  const Invocation({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
  });
}

class FakeProcessRunner implements ProcessRunner {
  final Future<ProcessResult> Function(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Duration timeout,
  })
  _runImpl;

  final List<Invocation> invocations = <Invocation>[];

  FakeProcessRunner(this._runImpl);

  factory FakeProcessRunner.result({required int exitCode, required String stdout}) {
    return FakeProcessRunner((
      String executable,
      List<String> arguments, {
      String? workingDirectory,
      Duration timeout = const Duration(seconds: 15),
    }) async {
      return ProcessResult(0, exitCode, stdout, "");
    });
  }

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    invocations.add(
      Invocation(
        executable: executable,
        arguments: List<String>.from(arguments),
        workingDirectory: workingDirectory,
      ),
    );
    return _runImpl(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      timeout: timeout,
    );
  }
}
