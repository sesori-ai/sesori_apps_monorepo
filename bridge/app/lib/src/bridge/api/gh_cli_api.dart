import "dart:async";
import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeListMap, jsonDecodeMap;

import "../foundation/process_runner.dart";
import "gh_pull_request.dart";

const _ghCommandTimeout = Duration(seconds: 15);

class GhCliApi {
  final ProcessRunner _processRunner;

  GhCliApi({ProcessRunner processRunner = Process.run}) : _processRunner = processRunner;

  Future<bool> isAvailable() async {
    try {
      final result = await _runGh(arguments: const ["--version"]);
      return result.exitCode == 0;
    } on Object catch (e) {
      Log.w("[GhCli] gh --version failed: $e");
      return false;
    }
  }

  Future<bool> isAuthenticated() async {
    try {
      final result = await _runGh(arguments: const ["auth", "status"]);
      return result.exitCode == 0;
    } on Object catch (e) {
      Log.w("[GhCli] gh auth status failed: $e");
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
    final result = await _runGh(
      arguments: <String>[
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

  /// Runs a `gh` command with timeout. Uses [Process.start] so the subprocess
  /// can be killed on timeout (unlike [Process.run] + [Future.timeout] which
  /// leaves the child running). Falls back to [_processRunner] when injected
  /// for testing.
  Future<ProcessResult> _runGh({
    required List<String> arguments,
    String? workingDirectory,
  }) async {
    // When a custom processRunner is injected (tests), use it directly.
    // In production (Process.run default), use Process.start for kill-on-timeout.
    if (_processRunner != Process.run) {
      return _processRunner("gh", arguments, workingDirectory: workingDirectory).timeout(_ghCommandTimeout);
    }

    final process = await Process.start("gh", arguments, workingDirectory: workingDirectory);
    final exitCode = await process.exitCode.timeout(
      _ghCommandTimeout,
      onTimeout: () {
        process.kill();
        throw TimeoutException("gh command timed out after $_ghCommandTimeout", _ghCommandTimeout);
      },
    );
    final stdout = await process.stdout.transform(const SystemEncoding().decoder).join();
    final stderr = await process.stderr.transform(const SystemEncoding().decoder).join();
    return ProcessResult(process.pid, exitCode, stdout, stderr);
  }
}
