import 'dart:async';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:sesori_shared/sesori_shared.dart';

import '../foundation/github_rate_limit_exception.dart';
import '../models/github_release_dto.dart';

const _kGithubApiBaseUrl = 'https://api.github.com/repos/sesori-ai/sesori_apps_monorepo/releases';
const _kGithubReleasesPerPage = 100;
const _kGithubReleasesMaxPages = 1;

class GitHubReleasesApi {
  final http.Client _httpClient;
  final String? _authToken;

  GitHubReleasesApi({required http.Client httpClient, required String? authToken})
    : _httpClient = httpClient,
      _authToken = authToken;

  Future<List<GitHubReleaseDto>> fetchReleases() async {
    final releases = <GitHubReleaseDto>[];

    for (var page = 1; page <= _kGithubReleasesMaxPages; page++) {
      final Uri uri = Uri.parse(_kGithubApiBaseUrl).replace(
        queryParameters: <String, String>{
          'per_page': '$_kGithubReleasesPerPage',
          'page': '$page',
        },
      );
      final (:http.Response response, :bool authenticated) = await _getWithOpportunisticAuth(uri);

      if (_isRateLimited(response)) {
        throw GitHubRateLimitException(
          resetAt: _parseResetAt(response),
          authenticated: authenticated,
        );
      }
      if (response.statusCode == 404) {
        throw StateError('GitHub releases endpoint not found');
      }
      if (response.statusCode != 200) {
        throw StateError('GitHub releases request failed with status ${response.statusCode}');
      }

      final pageReleases = jsonDecodeListMap(response.body).map(GitHubReleaseDto.fromJson).toList();
      releases.addAll(pageReleases);

      if (pageReleases.length < _kGithubReleasesPerPage) {
        return releases;
      }
    }

    return releases;
  }

  /// Fetches [uri], sending the auth token when present. Authentication is
  /// opportunistic: a stale or invalid token must never leave the updater worse
  /// off than running unauthenticated. The releases endpoint is public, so an
  /// auth rejection triggers a single retry without the `Authorization` header.
  Future<({http.Response response, bool authenticated})> _getWithOpportunisticAuth(Uri uri) async {
    final headers = _buildHeaders();
    final bool authenticated = headers.containsKey('Authorization');
    final http.Response response = await _httpClient
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 5));

    if (!authenticated || !_isAuthRejection(response)) {
      return (response: response, authenticated: authenticated);
    }

    final unauthenticatedHeaders = Map<String, String>.of(headers)..remove('Authorization');
    final http.Response retried = await _httpClient
        .get(uri, headers: unauthenticatedHeaders)
        .timeout(const Duration(seconds: 5));
    return (response: retried, authenticated: false);
  }

  /// Whether [response] indicates the supplied token was rejected (as opposed to
  /// a rate limit or success). HTTP 401 is GitHub's "Bad credentials"; a 403
  /// that is not a rate limit on this public endpoint is most likely a token
  /// problem (missing scope, SSO enforcement). Both warrant an unauthenticated
  /// retry.
  bool _isAuthRejection(http.Response response) {
    if (response.statusCode == 401) {
      return true;
    }
    return response.statusCode == 403 && !_isRateLimited(response);
  }

  /// Builds the request headers. An `Authorization` header is sent only when a
  /// non-empty token is available, lifting the GitHub limit from 60/hour per IP
  /// (unauthenticated) to 5000/hour for the authenticated user.
  Map<String, String> _buildHeaders() {
    final headers = <String, String>{'Accept': 'application/vnd.github+json'};
    final token = _authToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// GitHub signals a primary rate limit with HTTP 403 and
  /// `x-ratelimit-remaining: 0`. Secondary/abuse limits arrive as HTTP 429, or
  /// as HTTP 403 carrying a `retry-after` hint (where the remaining count may
  /// still be non-zero). A 403 with neither signal is a different failure (e.g.
  /// a blocked request) and is intentionally not treated as a rate limit.
  bool _isRateLimited(http.Response response) {
    if (response.statusCode == 429) {
      return true;
    }
    if (response.statusCode != 403) {
      return false;
    }
    return response.headers['x-ratelimit-remaining'] == '0' ||
        response.headers.containsKey('retry-after');
  }

  /// Resolves when the caller may retry. `retry-after` (the explicit
  /// secondary-limit cooldown) takes precedence when present; otherwise the
  /// primary `x-ratelimit-reset` window is used.
  DateTime? _parseResetAt(http.Response response) {
    final retryAfterSeconds = int.tryParse(response.headers['retry-after'] ?? '');
    if (retryAfterSeconds != null) {
      return clock.now().add(Duration(seconds: retryAfterSeconds));
    }

    final resetEpochSeconds = int.tryParse(response.headers['x-ratelimit-reset'] ?? '');
    if (resetEpochSeconds != null) {
      return DateTime.fromMillisecondsSinceEpoch(
        resetEpochSeconds * 1000,
        isUtc: true,
      ).toLocal();
    }

    return null;
  }
}
