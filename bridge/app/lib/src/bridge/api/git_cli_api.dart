import "dart:async";
import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeListMap, jsonDecodeMap;

import "../foundation/process_runner.dart";
import "gh_pull_request.dart";

const _ghCommandTimeout = Duration(seconds: 15);

class GitCliApi {
  final ProcessRunner _processRunner;

  GitCliApi({ProcessRunner processRunner = Process.run}) : _processRunner = processRunner;

  Future<bool> isGithubCliAvailable() async {
    try {
      final result = await _runGh(arguments: const ["--version"]);
      return result.exitCode == 0;
    } on Object catch (e) {
      Log.w("[GitCli] gh --version failed: $e");
      return false;
    }
  }

  Future<bool> isGithubCliAuthenticated() async {
    try {
      final result = await _runGh(arguments: const ["auth", "status"]);
      return result.exitCode == 0;
    } on Object catch (e) {
      Log.w("[GitCli] gh auth status failed: $e");
      return false;
    }
  }

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
      Log.w("[GitCli] failed to detect remote: $e");
      return false;
    }
  }

  Future<List<GhPullRequest>> listOpenPrs({required String workingDirectory}) async {
    final result = await _runGh(
      arguments: const <String>[
        "pr",
        "list",
        "--state",
        "open",
        "--json",
        "number,url,title,state,headRefName,mergeable,reviewDecision,statusCheckRollup",
        "--limit",
        "100",
      ],
      workingDirectory: workingDirectory,
    );
    if (result.exitCode != 0) {
      throw Exception("gh pr list failed with exit code ${result.exitCode}");
    }

    final maps = jsonDecodeListMap(result.stdout.toString());
    return maps.map(GhPullRequest.fromJson).toList(growable: false);
  }

  Future<GhPullRequest> getPrByNumber({
    required int number,
    required String workingDirectory,
  }) async {
    final result = await _runGh(
      arguments: <String>[
        "pr",
        "view",
        number.toString(),
        "--json",
        "number,url,title,state,headRefName,mergeable,reviewDecision,statusCheckRollup",
      ],
      workingDirectory: workingDirectory,
    );
    if (result.exitCode != 0) {
      throw Exception("gh pr view failed with exit code ${result.exitCode}");
    }

    final map = jsonDecodeMap(result.stdout.toString());
    return GhPullRequest.fromJson(map);
  }

  Future<ProcessResult> _runGh({
    required List<String> arguments,
    String? workingDirectory,
  }) {
    return _processRunner("gh", arguments, workingDirectory: workingDirectory).timeout(
      _ghCommandTimeout,
    );
  }
}
