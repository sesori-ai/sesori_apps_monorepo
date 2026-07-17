import "dart:io";

import "package:sesori_bridge/src/bridge/api/git_cli_api.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:test/test.dart";

void main() {
  test("commitAll disables signing for the command-scoped identity", () async {
    final processRunner = _RecordingProcessRunner();
    final api = GitCliApi(
      processRunner: processRunner,
      gitPathExists: ({required String gitPath}) => false,
    );

    final committed = await api.commitAll(
      projectPath: "/project",
      message: "Initial commit",
    );

    expect(committed, isTrue);
    expect(processRunner.workingDirectory, "/project");
    expect(processRunner.arguments, [
      "-c",
      "user.name=Sesori",
      "-c",
      "user.email=sesori@localhost",
      "-c",
      "commit.gpgSign=false",
      "commit",
      "-m",
      "Initial commit",
    ]);
  });
}

class _RecordingProcessRunner implements ProcessRunner {
  List<String>? arguments;
  String? workingDirectory;

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    expect(executable, "git");
    this.arguments = arguments;
    this.workingDirectory = workingDirectory;
    return ProcessResult(1, 0, "", "");
  }

  @override
  Future<int> startDetached({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
  }) {
    throw UnimplementedError();
  }
}
