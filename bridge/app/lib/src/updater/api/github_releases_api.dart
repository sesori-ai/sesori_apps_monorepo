import 'dart:async';

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

  GitHubReleasesApi({required http.Client httpClient, String? authToken})
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
      final http.Response response = await _httpClient
          .get(uri, headers: _buildHeaders())
          .timeout(const Duration(seconds: 5));

      if (_isRateLimited(response)) {
        throw GitHubRateLimitException(resetAt: _parseResetAt(response));
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
  /// `x-ratelimit-remaining: 0`, and a secondary/abuse limit with HTTP 429. A
  /// 403 without an exhausted remaining count is a different failure (e.g. a
  /// blocked request) and is intentionally not treated as a rate limit.
  bool _isRateLimited(http.Response response) {
    if (response.statusCode == 429) {
      return true;
    }
    return response.statusCode == 403 && response.headers['x-ratelimit-remaining'] == '0';
  }

  DateTime? _parseResetAt(http.Response response) {
    final resetEpochSeconds = int.tryParse(response.headers['x-ratelimit-reset'] ?? '');
    if (resetEpochSeconds != null) {
      return DateTime.fromMillisecondsSinceEpoch(
        resetEpochSeconds * 1000,
        isUtc: true,
      ).toLocal();
    }

    final retryAfterSeconds = int.tryParse(response.headers['retry-after'] ?? '');
    if (retryAfterSeconds != null) {
      return DateTime.now().add(Duration(seconds: retryAfterSeconds));
    }

    return null;
  }
}
