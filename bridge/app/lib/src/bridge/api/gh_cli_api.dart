import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Console;
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

import "../../api/gh_pull_request_batch.dart";
import "../foundation/process_runner.dart";
import "gh_authenticated_identity.dart";

class GhCliApi {
  static const int maxPullRequestTargetsPerQuery = 20;
  static const int _pullRequestPageSize = 10;

  final ProcessRunner _processRunner;
  bool _availabilityFailureReported = false;
  _GhAuthenticationFailure? _reportedAuthenticationFailure;

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
        _reportedAuthenticationFailure = null;
        return true;
      }
      final stderr = result.stderr.toString();
      _reportAuthenticationFailure(
        failure: _reportsNoConfiguredGithubAccount(stderr: stderr)
            ? _GhAuthenticationFailure.unauthenticated
            : _GhAuthenticationFailure.verificationFailed,
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

    _reportedAuthenticationFailure = null;
    return GhAuthenticatedIdentity(rawLogin: result.stdout.toString());
  }

  void _reportAvailabilityFailure({required String message}) {
    if (_availabilityFailureReported) return;
    _availabilityFailureReported = true;
    Console.warning(message);
  }

  bool _reportsNoConfiguredGithubAccount({required String stderr}) {
    // gh also calls tokens invalid for connectivity failures, so only its local no-account diagnostics are definitive.
    return stderr.contains("You are not logged into any GitHub hosts") ||
        stderr.contains("You are not logged into any accounts on github.com");
  }

  void _reportAuthenticationFailure({required _GhAuthenticationFailure failure}) {
    if (_reportedAuthenticationFailure == failure) return;
    _reportedAuthenticationFailure = failure;
    final message = switch (failure) {
      _GhAuthenticationFailure.unauthenticated =>
        "GitHub CLI (gh) is not authenticated for github.com. Run 'gh auth login' or set GH_TOKEN/GITHUB_TOKEN "
            "to enable GitHub pull request and CI status sync.",
      _GhAuthenticationFailure.verificationFailed =>
        "GitHub CLI (gh) could not verify authentication for github.com. "
            "GitHub pull request and CI status sync is temporarily unavailable. "
            "Run 'gh auth status --hostname github.com' to check authentication and connectivity.",
    };
    Console.warning(message);
  }

  Future<GhPullRequestBatchResponse> queryInitialPullRequestPages({
    required List<GhPullRequestTarget> targets,
  }) {
    _requireValidQuerySize(count: targets.length);

    final definitions = <String>[];
    final selections = <String>["viewer { login }"];
    final fields = <String, String>{};
    for (var index = 0; index < targets.length; index++) {
      definitions.addAll([
        "\$owner$index: String!",
        "\$name$index: String!",
        "\$branch$index: String!",
      ]);
      selections.add(
        """
        target$index: repository(owner: \$owner$index, name: \$name$index, followRenames: true) {
          nameWithOwner
          open: pullRequests(
            headRefName: \$branch$index
            states: [OPEN]
            first: $_pullRequestPageSize
            orderBy: {field: CREATED_AT, direction: DESC}
          ) { ...PullRequestConnection }
          terminal: pullRequests(
            headRefName: \$branch$index
            states: [MERGED, CLOSED]
            first: $_pullRequestPageSize
            orderBy: {field: CREATED_AT, direction: DESC}
          ) { ...PullRequestConnection }
        }
        """,
      );
      final target = targets[index];
      fields["owner$index"] = target.repositoryOwner;
      fields["name$index"] = target.repositoryName;
      fields["branch$index"] = target.branchName;
    }

    final query = _buildPullRequestQuery(definitions: definitions, selections: selections);
    final jq = _buildInitialPullRequestJq(targetCount: targets.length);
    return _runPullRequestQuery(query: query, fields: fields, jq: jq);
  }

  Future<GhPullRequestBatchResponse> queryPullRequestCursorPages({
    required List<GhPullRequestCursorRequest> requests,
  }) {
    _requireValidQuerySize(count: requests.length);

    final definitions = <String>[];
    final selections = <String>["viewer { login }"];
    final fields = <String, String>{};
    for (var index = 0; index < requests.length; index++) {
      definitions.addAll([
        "\$owner$index: String!",
        "\$name$index: String!",
        "\$branch$index: String!",
        "\$cursor$index: String!",
      ]);
      final states = switch (requests[index].stateGroup) {
        GhPullRequestStateGroup.open => "[OPEN]",
        GhPullRequestStateGroup.terminal => "[MERGED, CLOSED]",
      };
      selections.add(
        """
        target$index: repository(owner: \$owner$index, name: \$name$index, followRenames: true) {
          nameWithOwner
          page: pullRequests(
            headRefName: \$branch$index
            states: $states
            first: $_pullRequestPageSize
            after: \$cursor$index
            orderBy: {field: CREATED_AT, direction: DESC}
          ) { ...PullRequestConnection }
        }
        """,
      );
      final request = requests[index];
      fields["owner$index"] = request.target.repositoryOwner;
      fields["name$index"] = request.target.repositoryName;
      fields["branch$index"] = request.target.branchName;
      fields["cursor$index"] = request.cursor;
    }

    final query = _buildPullRequestQuery(definitions: definitions, selections: selections);
    final jq = _buildCursorPullRequestJq(requests: requests);
    return _runPullRequestQuery(query: query, fields: fields, jq: jq);
  }

  String _buildPullRequestQuery({
    required List<String> definitions,
    required List<String> selections,
  }) {
    return """
      query(${definitions.join(", ")}) {
        ${selections.join("\n")}
      }
      fragment PullRequestCandidate on PullRequest {
        number
        url
        title
        createdAt
        state
        headRefName
        isCrossRepository
        mergeable
        reviewDecision
        commits(last: 1) {
          nodes {
            commit {
              statusCheckRollup { state }
            }
          }
        }
      }
      fragment PullRequestConnection on PullRequestConnection {
        nodes { ...PullRequestCandidate }
        pageInfo { hasNextPage endCursor }
      }
    """;
  }

  String _buildInitialPullRequestJq({required int targetCount}) {
    final pages = <String>[];
    for (var index = 0; index < targetCount; index++) {
      pages.add(
        _buildPullRequestPageJq(
          requestIndex: index,
          stateGroup: GhPullRequestStateGroup.open,
          connectionPath: ".data.target$index.open",
          repositoryPath: ".data.target$index.nameWithOwner",
        ),
      );
      pages.add(
        _buildPullRequestPageJq(
          requestIndex: index,
          stateGroup: GhPullRequestStateGroup.terminal,
          connectionPath: ".data.target$index.terminal",
          repositoryPath: ".data.target$index.nameWithOwner",
        ),
      );
    }
    return _buildPullRequestJq(pages: pages);
  }

  String _buildCursorPullRequestJq({
    required List<GhPullRequestCursorRequest> requests,
  }) {
    return _buildPullRequestJq(
      pages: [
        for (var index = 0; index < requests.length; index++)
          _buildPullRequestPageJq(
            requestIndex: index,
            stateGroup: requests[index].stateGroup,
            connectionPath: ".data.target$index.page",
            repositoryPath: ".data.target$index.nameWithOwner",
          ),
      ],
    );
  }

  String _buildPullRequestJq({required List<String> pages}) {
    return """
      def normalize:
        .nodes |= map(
          . + {
            statusCheckRollup: (.commits.nodes[0].commit.statusCheckRollup.state // null)
          } | del(.commits)
        );
      {
        errorCount: ((.errors // []) | length),
        viewerLogin: (.data.viewer.login // ""),
        pages: [${pages.join(",")}]
      }
    """;
  }

  String _buildPullRequestPageJq({
    required int requestIndex,
    required GhPullRequestStateGroup stateGroup,
    required String connectionPath,
    required String repositoryPath,
  }) {
    return """
      {
        requestIndex: $requestIndex,
        stateGroup: "${stateGroup.name}",
        repositoryIdentity: ($repositoryPath // ""),
        connection: (($connectionPath // {
          nodes: [],
          pageInfo: {hasNextPage: false, endCursor: null}
        }) | normalize)
      }
    """;
  }

  Future<GhPullRequestBatchResponse> _runPullRequestQuery({
    required String query,
    required Map<String, String> fields,
    required String jq,
  }) async {
    final arguments = <String>[
      "api",
      "graphql",
      "--hostname",
      "github.com",
      "-f",
      "query=$query",
      for (final entry in fields.entries) ...["-f", "${entry.key}=${entry.value}"],
      "--jq",
      jq,
    ];
    final ProcessResult result;
    try {
      result = await _processRunner.run("gh", arguments);
    } on Object catch (error, stackTrace) {
      throw GhPullRequestWrappedException(
        innerError: error,
        innerStackTrace: stackTrace,
      );
    }
    if (result.exitCode != 0) {
      throw GhPullRequestProcessExitException(
        exitCode: result.exitCode,
      );
    }

    final GhPullRequestBatchResponse response;
    try {
      response = GhPullRequestBatchResponse.fromJson(
        jsonDecodeMap(result.stdout.toString()),
      );
    } on Object catch (error, stackTrace) {
      throw GhPullRequestWrappedException(
        innerError: error,
        innerStackTrace: stackTrace,
      );
    }
    if (response.errorCount > 0) {
      throw GhPullRequestGraphqlException(
        errorCount: response.errorCount,
      );
    }
    return response;
  }

  void _requireValidQuerySize({required int count}) {
    if (count < 1 || count > maxPullRequestTargetsPerQuery) {
      throw ArgumentError.value(
        count,
        "count",
        "GitHub pull request queries require 1-$maxPullRequestTargetsPerQuery targets",
      );
    }
  }
}

enum _GhAuthenticationFailure { unauthenticated, verificationFailed }
