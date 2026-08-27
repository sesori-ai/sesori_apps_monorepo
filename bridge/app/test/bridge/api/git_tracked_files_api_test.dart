import "dart:io";

import "package:sesori_bridge/src/api/git_tracked_files_api.dart";
import "package:test/test.dart";

void main() {
  test("streams only the requested tracked-file prefix", () async {
    final directory = await Directory.systemTemp.createTemp("git_tracked_files_api_test");
    addTearDown(() => directory.delete(recursive: true));
    await _runGit(projectPath: directory.path, arguments: const ["init", "--quiet"]);
    for (final name in ["a.dart", "b.dart", "c.dart"]) {
      await File("${directory.path}/$name").writeAsString(name);
    }
    await _runGit(projectPath: directory.path, arguments: const ["add", "."]);

    final paths = await const GitTrackedFilesApi().listTrackedFiles(
      projectPath: directory.path,
      maximumPaths: 2,
    );

    expect(paths, ["a.dart", "b.dart"]);
  });

  test("rejects a non-positive bound before spawning Git", () async {
    await expectLater(
      () => const GitTrackedFilesApi().listTrackedFiles(projectPath: "/unused", maximumPaths: 0),
      throwsArgumentError,
    );
  });
}

Future<void> _runGit({required String projectPath, required List<String> arguments}) async {
  final result = await Process.run("git", arguments, workingDirectory: projectPath);
  if (result.exitCode != 0) {
    throw ProcessException("git", arguments, result.stderr.toString(), result.exitCode);
  }
}
