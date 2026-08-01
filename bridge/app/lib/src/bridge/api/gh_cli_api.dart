import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Console;
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeListMap, jsonDecodeMap;

import "../foundation/process_runner.dart";
import "gh_authenticated_identity.dart";
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
            "GitHub pull request and CI status sync is disabled.",
      );
      return false;
    } on ProcessException {
      _reportAvailabilityFailure(
        message:
            "GitHub CLI (gh) is not installed or is unavailable on PATH. "
            "GitHub pull request and CI status sync is disabled.",
      );
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
            "GitHub pull request and CI status sync is disabled.",
      );
      return false;
    }
  }

  Future<GhAuthenticatedIdentity> getAuthenticatedIdentity() async {
    const arguments = ["api", "--hostname", "github.com", "user", "--jq", ".login"];
    final result = await _processRunner.run(
      "gh",
      arguments,
    );
    if (result.exitCode != 0) {
      throw ProcessException(
        "gh",
        arguments,
        result.stderr.toString(),
        result.exitCode,
      );
    }

    _authenticationFailureReported = false;
    return GhAuthenticatedIdentity(rawLogin: result.stdout.toString());
  }

  void _reportAvailabilityFailure({required String message}) {
    if (_availabilityFailureReported) return;
    _availabilityFailureReported = true;
    Console.warning(message);
  }

  void _reportAuthenticationFailure() {
    if (_authenticationFailureReported) return;
    _authenticationFailureReported = true;
    Console.warning(
      "GitHub CLI (gh) is not authenticated for github.com. Run 'gh auth login' or set GH_TOKEN/GITHUB_TOKEN "
      "to enable GitHub pull request and CI status sync.",
    );
  }

  Future<List<GhPullRequest>> listOpenPrs({
    required String workingDirectory,
    required String githubRepositoryIdentity,
  }) async {
    final result = await _processRunner.run(
      "gh",
      <String>[
        "pr",
        "list",
        "--repo",
        "github.com/$githubRepositoryIdentity",
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
    required String githubRepositoryIdentity,
  }) async {
    final result = await _processRunner.run(
      "gh",
      <String>[
        "pr",
        "view",
        number.toString(),
        "--repo",
        "github.com/$githubRepositoryIdentity",
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
