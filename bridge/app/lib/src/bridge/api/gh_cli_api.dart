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
  bool _identityVerificationFailureReported = false;

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

  Future<GhAuthenticatedIdentity?> getAuthenticatedIdentity() async {
    try {
      final result = await _processRunner.run(
        "gh",
        const ["api", "--hostname", "github.com", "user", "--jq", ".login"],
      );
      if (result.exitCode != 0) {
        _reportIdentityVerificationFailure();
        return null;
      }

      final identity = GhAuthenticatedIdentity.tryParse(rawLogin: result.stdout.toString());
      if (identity == null) {
        _reportIdentityVerificationFailure();
        return null;
      }

      _authenticationFailureReported = false;
      _identityVerificationFailureReported = false;
      return identity;
    } on ProcessException {
      _reportAvailabilityFailure(
        message:
            "GitHub CLI (gh) is not installed or is unavailable on PATH. "
            "GitHub pull request and CI status sync is disabled.",
      );
      return null;
    }
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

  void _reportIdentityVerificationFailure() {
    if (_identityVerificationFailureReported) return;
    _identityVerificationFailureReported = true;
    Console.warning(
      "GitHub CLI (gh) could not verify the active github.com account. "
      "GitHub pull request and CI status metadata is hidden until verification succeeds. "
      "Run 'gh auth status --hostname github.com' to check authentication and connectivity.",
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
        githubRepositoryIdentity,
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
        githubRepositoryIdentity,
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
