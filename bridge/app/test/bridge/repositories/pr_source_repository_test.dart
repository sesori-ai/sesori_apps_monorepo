import "dart:collection";
import "dart:io";

import "package:sesori_bridge/src/bridge/api/gh_cli_api.dart";
import "package:sesori_bridge/src/bridge/api/git_cli_api.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/bridge/repositories/pr_source_repository.dart";
import "package:test/test.dart";

void main() {
  group("PrSourceRepository", () {
    test("maps the verified gh identity into repository evidence", () async {
      final repository = _repository(
        ghResults: [_result(stdout: "  OctoCat\n")],
        gitResults: const [],
      );

      final identity = await repository.getAuthenticatedIdentity();

      expect(identity?.login, "octocat");
    });

    test("rejects an empty gh identity", () async {
      final repository = _repository(
        ghResults: [_result(stdout: "  \n")],
        gitResults: const [],
      );

      expect(await repository.getAuthenticatedIdentity(), isNull);
    });

    test("returns a canonical lowercase GitHub owner/repository identity", () async {
      final repository = _repository(
        ghResults: const [],
        gitResults: [
          _result(stdout: "true\n"),
          _result(stdout: "origin\n"),
          _result(stdout: "git@GitHub.com:Sesori-AI/Sesori_Apps_Monorepo.git\n"),
        ],
      );

      final identity = await repository.getGithubRepositoryIdentity(
        projectPath: "/repo",
      );

      expect(identity, "sesori-ai/sesori_apps_monorepo");
    });

    test("rejects non-GitHub and nested repository identities", () async {
      for (final remoteUrl in [
        "https://gitlab.com/sesori-ai/sesori_apps_monorepo.git",
        "https://github.com/sesori-ai/mobile/sesori_apps_monorepo.git",
      ]) {
        final repository = _repository(
          ghResults: const [],
          gitResults: [
            _result(stdout: "true\n"),
            _result(stdout: "origin\n"),
            _result(stdout: "$remoteUrl\n"),
          ],
        );

        expect(
          await repository.getGithubRepositoryIdentity(projectPath: "/repo"),
          isNull,
          reason: remoteUrl,
        );
      }
    });
  });
}

PrSourceRepository _repository({
  required List<ProcessResult> ghResults,
  required List<ProcessResult> gitResults,
}) {
  return PrSourceRepository(
    ghCli: GhCliApi(processRunner: _QueueProcessRunner(results: ghResults)),
    gitCli: GitCliApi(
      processRunner: _QueueProcessRunner(results: gitResults),
      gitPathExists: ({required String gitPath}) => true,
    ),
  );
}

ProcessResult _result({required String stdout}) {
  return ProcessResult(1, 0, stdout, "");
}

class _QueueProcessRunner extends ProcessRunner {
  final Queue<ProcessResult> _results;

  _QueueProcessRunner({required List<ProcessResult> results}) : _results = Queue<ProcessResult>.from(results);

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (_results.isEmpty) {
      throw StateError("Unexpected command: $executable ${arguments.join(" ")}");
    }
    return _results.removeFirst();
  }
}
