import 'package:collection/collection.dart';

import '../api/github_releases_api.dart';
import '../api/update_cache_api.dart';
import '../models/cached_release.dart';
import '../models/github_release_dto.dart';
import '../models/release_info.dart';
import '../platform_info.dart';
import '../version_utils.dart';

class ReleaseRepository {
  final GitHubReleasesApi _api;
  final UpdateCacheApi _cache;
  final String _currentVersion;
  final DistributionTarget _target;

  ReleaseRepository({
    required GitHubReleasesApi api,
    required UpdateCacheApi cache,
    required String currentVersion,
    required DistributionTarget target,
  }) : _api = api,
       _cache = cache,
       _currentVersion = currentVersion,
       _target = target;

  Future<ReleaseInfo?> checkForNewerRelease() async {
    final cached = await _cache.read(ttl: const Duration(hours: 24));
    if (cached != null) {
      return _evaluateCached(cached: cached);
    }

    return _fetchAndEvaluate();
  }

  ReleaseInfo? _evaluateCached({required CachedRelease cached}) {
    final latestVersion = cached.latestVersion;
    if (latestVersion.contains('-')) {
      return null;
    }

    if (compareVersions(a: latestVersion, b: _currentVersion) > 0) {
      return ReleaseInfo(
        version: latestVersion,
        assetUrl: cached.downloadUrl,
        checksumsUrl: cached.checksumsUrl,
        publishedAt: cached.publishedAt,
      );
    }

    return null;
  }

  Future<ReleaseInfo?> _fetchAndEvaluate() async {
    final List<GitHubReleaseDto> releases;
    try {
      releases = await _api.fetchReleases();
    } on Object {
      return null;
    }

    final release = _selectLatestBridgeRelease(releases: releases);
    if (release == null) {
      return null;
    }

    return _evaluateRelease(release: release);
  }

  GitHubReleaseDto? _selectLatestBridgeRelease({required List<GitHubReleaseDto> releases}) {
    final filteredReleases = releases
        .where((release) => !release.draft && !release.prerelease && release.tagName.startsWith('bridge-v'))
        .map((release) => (release: release, version: release.tagName.replaceFirst('bridge-v', '')))
        .where((item) => !item.version.contains('-'))
        .where(
          (item) =>
              item.release.assets.any((asset) => asset.name == _target.assetName) &&
              item.release.assets.any((asset) => asset.name == 'checksums.txt'),
        )
        .sorted(
          // sort descending
          (a, b) => compareVersions(a: b.version, b: a.version),
        );

    return filteredReleases.firstOrNull?.release;
  }

  Future<ReleaseInfo?> _evaluateRelease({required GitHubReleaseDto release}) async {
    final tagName = release.tagName;
    if (!tagName.startsWith('bridge-v')) {
      return null;
    }

    final latestVersion = tagName.replaceFirst('bridge-v', '');

    final DateTime publishedAt;
    try {
      publishedAt = DateTime.parse(release.publishedAt);
    } on FormatException {
      return null;
    }

    final assetName = _target.assetName;

    String? assetUrl;
    String? checksumsUrl;
    for (final item in release.assets) {
      final name = item.name;
      final url = item.browserDownloadUrl;
      if (name == assetName) {
        assetUrl = url;
      }
      if (name == 'checksums.txt') {
        checksumsUrl = url;
      }
    }

    if (assetUrl != null && checksumsUrl != null) {
      await _cache.write(
        release: CachedRelease(
          latestVersion: latestVersion,
          downloadUrl: assetUrl,
          checksumsUrl: checksumsUrl,
          publishedAt: publishedAt,
          checkedAt: DateTime.now(),
        ),
      );
    }

    if (latestVersion.contains('-')) {
      return null;
    }
    if (compareVersions(a: latestVersion, b: _currentVersion) <= 0) {
      return null;
    }
    if (assetUrl == null || checksumsUrl == null) {
      return null;
    }

    return ReleaseInfo(
      version: latestVersion,
      assetUrl: assetUrl,
      checksumsUrl: checksumsUrl,
      publishedAt: publishedAt,
    );
  }
}
