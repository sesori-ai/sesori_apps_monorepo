import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeListMap, jsonDecodeMap;

import "../foundation/process_runner.dart";
import "gh_pull_request.dart";

class GhCliApi {
  final ProcessRunner _processRunner;

  GhCliApi({required ProcessRunner processRunner}) : _processRunner = processRunner;

  Future<bool> isAvailable() async {
    try {
      final result = await _processRunner.run("gh", const ["--version"]);
      return result.exitCode == 0;
    } on Object catch (e) {
      Log.w("[GhCli] gh --version failed: $e");
      return false;
    }
  }

  Future<bool> isAuthenticated() async {
    try {
      final result = await _processRunner.run("gh", const ["auth", "status"]);
      return result.exitCode == 0;
    } on Object catch (e) {
      Log.w("[GhCli] gh auth status failed: $e");
      return false;
    }
  }

  Future<List<GhPullRequest>> listOpenPrs({required String workingDirectory}) async {
    final result = await _processRunner.run(
      "gh",
      const <String>[
        "pr",
        "list",
        "--state",
        "open",
        "--json",
        "number,url,title,state,headRefName,isCrossRepository,mergeable,reviewDecision,statusCheckRollup",
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
    final result = await _processRunner.run(
      "gh",
      <String>[
        "pr",
        "view",
        number.toString(),
        "--json",
        "number,url,title,state,headRefName,isCrossRepository,mergeable,reviewDecision,statusCheckRollup",
      ],
      workingDirectory: workingDirectory,
    );
    if (result.exitCode != 0) {
      throw Exception("gh pr view failed with exit code ${result.exitCode}");
    }

    final map = jsonDecodeMap(result.stdout.toString());
    return GhPullRequest.fromJson(map);
  }
}
