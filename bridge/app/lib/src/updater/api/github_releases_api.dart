import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sesori_shared/sesori_shared.dart';

import '../models/github_release_dto.dart';

const _kGithubApiBaseUrl = 'https://api.github.com/repos/sesori-ai/sesori_apps_monorepo/releases';
const _kGithubReleasesPerPage = 100;
const _kGithubReleasesMaxPages = 10;

class GitHubReleasesApi {
  final http.Client _httpClient;

  GitHubReleasesApi({required http.Client httpClient}) : _httpClient = httpClient;

  Future<List<GitHubReleaseDto>> fetchReleases() async {
    final releases = <GitHubReleaseDto>[];

    for (var page = 1; page <= _kGithubReleasesMaxPages; page++) {
      final Uri uri = Uri.parse(_kGithubApiBaseUrl).replace(
        queryParameters: <String, String>{
          'per_page': '$_kGithubReleasesPerPage',
          'page': '$page',
        },
      );
      final http.Response response = await _httpClient.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 403) {
        stderr.writeln(
          'sesori-bridge: GitHub API rate limit reached, skipping update check',
        );
        throw StateError('GitHub releases request was rate limited');
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
}
