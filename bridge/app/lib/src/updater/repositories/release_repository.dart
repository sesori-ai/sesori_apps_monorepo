import 'package:collection/collection.dart';

import '../api/github_releases_api.dart';
import '../api/update_cache_api.dart';
import '../models/bridge_version.dart';
import '../models/cached_release.dart';
import '../models/distribution_target.dart';
import '../models/github_release_dto.dart';
import '../models/release_info.dart';

class ReleaseRepository {
  final GitHubReleasesApi _api;
  final UpdateCacheApi _cache;
  final BridgeVersion _currentVersion;
  final DistributionTarget _target;

  ReleaseRepository({
    required GitHubReleasesApi api,
    required UpdateCacheApi cache,
    required String currentVersion,
    required DistributionTarget target,
  }) : _api = api,
       _cache = cache,
       _currentVersion = BridgeVersion.parse(value: currentVersion),
       _target = target;

  Future<ReleaseInfo?> checkForNewerRelease() async {
    final cached = await _cache.read(ttl: const Duration(hours: 24));
    if (cached != null) {
      if (cached.assetName == _target.assetName) {
        return _evaluateCached(cached: cached);
      }
    }

    return _fetchAndEvaluate();
  }

  ReleaseInfo? _evaluateCached({required CachedRelease cached}) {
    if (cached.assetName != _target.assetName) {
      return null;
    }

    final BridgeVersion? latestVersion = BridgeVersion.tryParse(value: cached.latestVersion);
    if (latestVersion == null || !latestVersion.isStable) {
      return null;
    }

    if (latestVersion.compareTo(_currentVersion) > 0) {
      return ReleaseInfo(
        version: latestVersion.toString(),
        assetUrl: cached.downloadUrl,
        checksumsUrl: cached.checksumsUrl,
        publishedAt: cached.publishedAt,
      );
    }

    return null;
  }

  Future<ReleaseInfo?> _fetchAndEvaluate() async {
    final releases = await _api.fetchReleases();

    final release = _selectLatestBridgeRelease(releases: releases);
    if (release == null) {
      return null;
    }

    return _evaluateRelease(release: release);
  }

  GitHubReleaseDto? _selectLatestBridgeRelease({required List<GitHubReleaseDto> releases}) {
    final filteredReleases = releases
        .where((release) => !release.draft && !release.prerelease && release.tagName.startsWith('bridge-v'))
        .map(
          (release) => (
            release: release,
            version: BridgeVersion.tryParse(value: release.tagName.replaceFirst('bridge-v', '')),
          ),
        )
        .where((item) => item.version != null && item.version!.isStable)
        .where(
          (item) =>
              item.release.assets.any((asset) => asset.name == _target.assetName) &&
              item.release.assets.any((asset) => asset.name == 'checksums.txt'),
        )
        .sorted(
          // sort descending
          (a, b) => b.version!.compareTo(a.version!),
        );

    return filteredReleases.firstOrNull?.release;
  }

  Future<ReleaseInfo?> _evaluateRelease({required GitHubReleaseDto release}) async {
    final tagName = release.tagName;
    if (!tagName.startsWith('bridge-v')) {
      return null;
    }

    final BridgeVersion? latestVersion = BridgeVersion.tryParse(
      value: tagName.replaceFirst('bridge-v', ''),
    );
    if (latestVersion == null) {
      return null;
    }

    final DateTime publishedAt;
    try {
      final String? publishedAtRaw = release.publishedAt;
      if (publishedAtRaw == null) {
        throw const FormatException('published_at is null');
      }
      publishedAt = DateTime.parse(publishedAtRaw);
    } on FormatException catch (error) {
      throw StateError('Invalid published_at for release $tagName: ${error.message}');
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
          latestVersion: latestVersion.toString(),
          downloadUrl: assetUrl,
          checksumsUrl: checksumsUrl,
          assetName: assetName,
          publishedAt: publishedAt,
          checkedAt: DateTime.now(),
        ),
      );
    }

    if (!latestVersion.isStable) {
      return null;
    }
    if (latestVersion.compareTo(_currentVersion) <= 0) {
      return null;
    }
    if (assetUrl == null || checksumsUrl == null) {
      return null;
    }

    return ReleaseInfo(
      version: latestVersion.toString(),
      assetUrl: assetUrl,
      checksumsUrl: checksumsUrl,
      publishedAt: publishedAt,
    );
  }
}
