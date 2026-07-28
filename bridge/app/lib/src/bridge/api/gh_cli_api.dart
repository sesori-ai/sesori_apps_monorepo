import "dart:async";
import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeListMap, jsonDecodeMap;

import "../foundation/process_runner.dart";
import "gh_pull_request.dart";

class GhCliApi {
  final ProcessRunner _processRunner;
  bool _availabilityFailureReported = false;
  bool _authenticationFailureReported = false;

  GhCliApi({required ProcessRunner processRunner}) : _processRunner = processRunner;

  Future<bool> isAvailable() async {
    try {
      final result = await _processRunner.run("gh", const ["--version"]);
      if (result.exitCode == 0) {
        _availabilityFailureReported = false;
        return true;
      }
      _reportAvailabilityFailure(
        message:
            "GitHub CLI (gh) is installed but unusable: 'gh --version' exited with code ${result.exitCode}. "
            "GitHub pull request and CI status sync is disabled; local worktree diffs do not require gh.",
      );
      return false;
    } on ProcessException {
      _reportAvailabilityFailure(
        message:
            "GitHub CLI (gh) is not installed or is unavailable on PATH. "
            "GitHub pull request and CI status sync is disabled; local worktree diffs do not require gh.",
      );
      return false;
    } on Object catch (error, stackTrace) {
      if (!_availabilityFailureReported) {
        _availabilityFailureReported = true;
        Log.w(
          "GitHub CLI availability check failed. GitHub pull request and CI status sync is disabled; "
          "local worktree diffs do not require gh.",
          error,
          stackTrace,
        );
      }
      return false;
    }
  }

  Future<bool> isAuthenticated() async {
    try {
      final result = await _processRunner.run(
        "gh",
        const ["auth", "status", "--hostname", "github.com"],
      );
      if (result.exitCode == 0) {
        _authenticationFailureReported = false;
        return true;
      }
      _reportAuthenticationFailure();
      return false;
    } on ProcessException {
      _reportAvailabilityFailure(
        message:
            "GitHub CLI (gh) is not installed or is unavailable on PATH. "
            "GitHub pull request and CI status sync is disabled; local worktree diffs do not require gh.",
      );
      return false;
    } on Object catch (error, stackTrace) {
      if (!_authenticationFailureReported) {
        _authenticationFailureReported = true;
        Log.w(
          "GitHub CLI authentication check failed. GitHub pull request and CI status sync is disabled; "
          "local worktree diffs do not require gh.",
          error,
          stackTrace,
        );
      }
      return false;
    }
  }

  void _reportAvailabilityFailure({required String message}) {
    if (_availabilityFailureReported) return;
    _availabilityFailureReported = true;
    Log.i(message);
  }

  void _reportAuthenticationFailure() {
    if (_authenticationFailureReported) return;
    _authenticationFailureReported = true;
    Log.i(
      "GitHub CLI (gh) is not authenticated for github.com. Run 'gh auth login' or set GH_TOKEN/GITHUB_TOKEN "
      "to enable GitHub pull request and CI status sync. Local worktree diffs do not require gh.",
    );
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
