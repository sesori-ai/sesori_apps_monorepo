import "dart:async";
import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeListMap, jsonDecodeMap;

import "../worktree_service.dart";
import "gh_pull_request.dart";

const _ghCommandTimeout = Duration(seconds: 15);

class GhCliService {
  final ProcessRunner _processRunner;

  GhCliService({ProcessRunner processRunner = Process.run}) : _processRunner = processRunner;

  Future<bool> isAvailable() async {
    try {
      final result = await _runGh(arguments: const ["--version"]);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isAuthenticated() async {
    try {
      final result = await _runGh(arguments: const ["auth", "status"]);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<List<GhPullRequest>> listOpenPrs({required String workingDirectory}) async {
    try {
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
        Log.w("[GhCli] gh pr list failed with exit code ${result.exitCode}");
        return const <GhPullRequest>[];
      }

      final maps = jsonDecodeListMap(result.stdout.toString());
      return maps.map(GhPullRequest.fromJson).toList(growable: false);
    } on ProcessException catch (e) {
      Log.w("[GhCli] process error listing PRs: $e");
      return const <GhPullRequest>[];
    } on TimeoutException catch (e) {
      Log.w("[GhCli] timeout listing PRs: $e");
      return const <GhPullRequest>[];
    } on FormatException catch (e) {
      Log.w("[GhCli] failed to parse gh pr list output: $e");
      return const <GhPullRequest>[];
    }
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
