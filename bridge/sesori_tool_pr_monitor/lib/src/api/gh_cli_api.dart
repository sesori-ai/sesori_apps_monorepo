import "dart:async";
import "dart:io" show ProcessException;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show CommandExecutor, CommandResult;
import "package:sesori_shared/sesori_shared.dart" show asStringKeyedMap, jsonDecodeMap;

import "../models/pull_request_target.dart";
import "gh_cli_exception.dart";
import "models/gh_graphql_response_dto.dart";
import "models/gh_pull_request_dto.dart";

/// GitHub through the user's own `gh` CLI on PATH, with its own credentials.
///
/// Each method is one `gh` call with a [commandTimeout]. Failures throw a
/// [GhCliException]; following pagination is the caller's job.
class GhCliApi({required final CommandExecutor _commandExecutor}) {
  static const Duration commandTimeout = Duration(seconds: 60);

  // gh documents exit code 4 as "authentication required".
  static const int _authRequiredExitCode = 4;
  static final RegExp _notFoundPattern = RegExp("could not resolve to|not found|404", caseSensitive: false);
  static final RegExp _unresolvedHostPattern = RegExp("could not resolve host", caseSensitive: false);
  static final RegExp _httpStatusPattern = RegExp(r"\bHTTP\s+(\d{3})\b", caseSensitive: false);

  /// The login `gh` is signed in as on github.com.
  Future<String> fetchAuthenticatedLogin() async {
    final stdout = await _run(arguments: const ["api", "--hostname", "github.com", "user", "--jq", ".login"]);
    final login = stdout.trim();
    if (login.isEmpty) {
      throw const GhCliInvalidResponseException(innerError: FormatException("gh api user returned no login"));
    }
    return login;
  }

  /// The first page of everything a poll needs. Throws
  /// [GhCliNotFoundException] when GitHub answers cleanly without the PR.
  Future<GhPullRequestDto> fetchPullRequest({required PullRequestTarget target}) async {
    final data = await _query(query: _pullRequestQuery, target: target, extraFields: const {}, includeNumber: true);
    return _decode<GhPullRequestDto>(() => GhPullRequestDto.fromJson(_pullRequestJson(data: data, target: target)));
  }

  /// The next page of the head commit's check contexts, or null when the
  /// commit or its rollup is gone, for example after a force-push.
  Future<GhCheckContextConnectionDto?> fetchCheckContextsPage({
    required PullRequestTarget target,
    required String headSha,
    required String cursor,
  }) async {
    final data = await _query(
      query: _checkContextsPageQuery,
      target: target,
      extraFields: {"head": headSha, "cursor": cursor},
      includeNumber: false,
    );
    final commit = asStringKeyedMap(value: asStringKeyedMap(value: data["repository"])?["object"]);
    final contexts = asStringKeyedMap(value: asStringKeyedMap(value: commit?["statusCheckRollup"])?["contexts"]);
    if (contexts == null) return null;
    return _decode<GhCheckContextConnectionDto>(() => GhCheckContextConnectionDto.fromJson(contexts));
  }

  Future<GhReviewConnectionDto> fetchLatestReviewsPage({
    required PullRequestTarget target,
    required String cursor,
  }) async {
    final data = await _query(
      query: _latestReviewsPageQuery,
      target: target,
      extraFields: {"cursor": cursor},
      includeNumber: true,
    );
    return _decode<GhReviewConnectionDto>(
      () => GhReviewConnectionDto.fromJson(_pullRequestField(data: data, target: target, field: "latestReviews")),
    );
  }

  Future<GhReviewThreadConnectionDto> fetchReviewThreadsPage({
    required PullRequestTarget target,
    required String cursor,
  }) async {
    final data = await _query(
      query: _reviewThreadsPageQuery,
      target: target,
      extraFields: {"cursor": cursor},
      includeNumber: true,
    );
    return _decode<GhReviewThreadConnectionDto>(
      () => GhReviewThreadConnectionDto.fromJson(_pullRequestField(data: data, target: target, field: "reviewThreads")),
    );
  }

  Future<GhLabelConnectionDto> fetchLabelsPage({
    required PullRequestTarget target,
    required String cursor,
  }) async {
    final data = await _query(
      query: _labelsPageQuery,
      target: target,
      extraFields: {"cursor": cursor},
      includeNumber: true,
    );
    return _decode<GhLabelConnectionDto>(
      () => GhLabelConnectionDto.fromJson(_pullRequestField(data: data, target: target, field: "labels")),
    );
  }

  Future<Map<String, dynamic>> _query({
    required String query,
    required PullRequestTarget target,
    required Map<String, String> extraFields,
    required bool includeNumber,
  }) async {
    // `-f` sends raw strings; only the PR number goes through `-F`, which
    // converts it to an Int (and would read a file for an `@` value).
    final stdout = await _run(
      arguments: [
        "api",
        "graphql",
        "--hostname",
        "github.com",
        "-f",
        "query=$query",
        "-f",
        "owner=${target.owner}",
        "-f",
        "repo=${target.repo}",
        if (includeNumber) ...["-F", "number=${target.number}"],
        for (final MapEntry(:key, :value) in extraFields.entries) ...["-f", "$key=$value"],
      ],
    );
    final response = _decode(() => GhGraphQlResponseDto.fromJson(jsonDecodeMap(stdout)));
    if (response.errors.isNotEmpty) {
      throw GhCliGraphQlException(
        errors: [for (final error in response.errors) error.message ?? "unknown GraphQL error"],
      );
    }
    final data = response.data;
    if (data == null) {
      throw const GhCliInvalidResponseException(innerError: FormatException("GraphQL response has no data"));
    }
    return data;
  }

  Map<String, dynamic> _pullRequestJson({required Map<String, dynamic> data, required PullRequestTarget target}) {
    final pullRequest = asStringKeyedMap(value: asStringKeyedMap(value: data["repository"])?["pullRequest"]);
    if (pullRequest == null) {
      throw GhCliNotFoundException(detail: "${target.displayKey} is not in the GraphQL response");
    }
    return pullRequest;
  }

  Map<String, dynamic> _pullRequestField({
    required Map<String, dynamic> data,
    required PullRequestTarget target,
    required String field,
  }) {
    final connection = asStringKeyedMap(
      value: _pullRequestJson(data: data, target: target)[field],
    );
    if (connection == null) {
      throw GhCliInvalidResponseException(innerError: FormatException("GraphQL response has no $field"));
    }
    return connection;
  }

  T _decode<T>(T Function() decode) {
    try {
      return decode();
    } on GhCliException {
      rethrow;
    } on Object catch (error) {
      throw GhCliInvalidResponseException(innerError: error);
    }
  }

  Future<String> _run({required List<String> arguments}) async {
    final CommandResult result;
    try {
      result = await _commandExecutor.run(
        executable: "gh",
        arguments: arguments,
        workingDirectory: null,
        environment: null,
        timeout: commandTimeout,
      );
    } on ProcessException catch (error) {
      throw GhCliUnavailableException(innerError: error);
    } on TimeoutException catch (error) {
      throw GhCliTimedOutException(timeout: commandTimeout, innerError: error);
    }
    if (result.exitCode == 0) return result.stdout;
    throw _failure(result: result);
  }

  GhCliException _failure({required CommandResult result}) {
    final stderr = result.stderr.trim();
    final detail = stderr.isEmpty ? "exit code ${result.exitCode}" : stderr;
    final statusText = _httpStatusPattern.firstMatch(detail)?.group(1);
    final httpStatus = statusText == null ? null : int.tryParse(statusText);
    if (result.exitCode == _authRequiredExitCode || httpStatus == 401) {
      return GhCliUnauthenticatedException(detail: detail);
    }
    if (_notFoundPattern.hasMatch(detail) && !_unresolvedHostPattern.hasMatch(detail)) {
      return GhCliNotFoundException(detail: detail);
    }
    return GhCliCommandFailedException(exitCode: result.exitCode, httpStatus: httpStatus, detail: detail);
  }
}

const String _checkContextNodes = """
          nodes {
            __typename
            ... on CheckRun { id name status conclusion }
            ... on StatusContext { context state createdAt }
          }""";

const String _latestReviewNodes = """
        nodes {
          id author { login __typename } state submittedAt body
          comments(first: 1) { totalCount }
        }""";

const String _reviewThreadNodes = """
        nodes {
          id isResolved path line originalLine
          comments(last: 100) {
            nodes { id author { login __typename } body createdAt pullRequestReview { state } }
          }
        }""";

const String _pullRequestQuery =
    """
query(\$owner: String!, \$repo: String!, \$number: Int!) {
  repository(owner: \$owner, name: \$repo) {
    pullRequest(number: \$number) {
      title url state mergeable headRefOid
      commits(last: 1) { nodes { commit { statusCheckRollup {
        contexts(first: 100) {
          pageInfo { hasNextPage endCursor }
$_checkContextNodes
        }
      } } } }
      reviewRequests(first: 50) { nodes { requestedReviewer {
        __typename
        ... on User { login }
        ... on Team { slug }
        ... on Bot { login }
      } } }
      latestReviews(first: 50) {
        pageInfo { hasNextPage endCursor }
$_latestReviewNodes
      }
      reviewThreads(first: 100) {
        pageInfo { hasNextPage endCursor }
$_reviewThreadNodes
      }
      comments(last: 100) { totalCount nodes { id author { login __typename } body createdAt } }
      labels(first: 100) {
        pageInfo { hasNextPage endCursor }
        nodes { name }
      }
    }
  }
}""";

const String _checkContextsPageQuery =
    """
query(\$owner: String!, \$repo: String!, \$head: GitObjectID!, \$cursor: String!) {
  repository(owner: \$owner, name: \$repo) {
    object(oid: \$head) {
      ... on Commit {
        statusCheckRollup {
          contexts(first: 100, after: \$cursor) {
            pageInfo { hasNextPage endCursor }
$_checkContextNodes
          }
        }
      }
    }
  }
}""";

const String _latestReviewsPageQuery =
    """
query(\$owner: String!, \$repo: String!, \$number: Int!, \$cursor: String!) {
  repository(owner: \$owner, name: \$repo) {
    pullRequest(number: \$number) {
      latestReviews(first: 50, after: \$cursor) {
        pageInfo { hasNextPage endCursor }
$_latestReviewNodes
      }
    }
  }
}""";

const String _reviewThreadsPageQuery =
    """
query(\$owner: String!, \$repo: String!, \$number: Int!, \$cursor: String!) {
  repository(owner: \$owner, name: \$repo) {
    pullRequest(number: \$number) {
      reviewThreads(first: 100, after: \$cursor) {
        pageInfo { hasNextPage endCursor }
$_reviewThreadNodes
      }
    }
  }
}""";

const String _labelsPageQuery = r"""
query($owner: String!, $repo: String!, $number: Int!, $cursor: String!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      labels(first: 100, after: $cursor) {
        pageInfo { hasNextPage endCursor }
        nodes { name }
      }
    }
  }
}""";
