import 'package:collection/collection.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;

import '../api/github_releases_api.dart';
import '../api/update_cache_api.dart';
import '../foundation/release_track.dart';
import '../models/bridge_version.dart';
import '../models/cached_release.dart';
import '../models/distribution_target.dart';
import '../models/github_release_dto.dart';
import '../models/release_info.dart';
import '../models/update_resolution.dart';

class ReleaseRepository {
  final GitHubReleasesApi _api;
  final UpdateCacheApi _cache;
  final BridgeVersion _currentVersion;
  final DistributionTarget _target;
  final ReleaseTrack _track;

  ReleaseRepository({
    required GitHubReleasesApi api,
    required UpdateCacheApi cache,
    required String currentVersion,
    required DistributionTarget target,
    required ReleaseTrack track,
  }) : _api = api,
       _cache = cache,
       _currentVersion = BridgeVersion.parse(value: currentVersion),
       _target = target,
       _track = track;

  /// Whether [version] is eligible for the active [ReleaseTrack]:
  /// - stable: only stable releases.
  /// - internal: stable releases plus `-internal.*` pre-releases. Other
  ///   pre-release kinds (e.g. `-rc`, `-beta`) are intentionally excluded so
  ///   "internal" means exactly the internal lane, not "any non-stable build".
  bool _isEligible(BridgeVersion version) {
    if (version.isStable) {
      return true;
    }
    return _track == ReleaseTrack.internal &&
        version.prereleaseIdentifiers.isNotEmpty &&
        version.prereleaseIdentifiers.first == ReleaseTrack.internal.wireValue;
  }

  Future<ReleaseInfo?> checkForNewerRelease() async {
    final cached = await _cache.read(ttl: const Duration(minutes: 10));
    if (cached != null) {
      if (cached.assetName == _target.assetName && cached.track == _track.wireValue) {
        return _evaluateCached(cached: cached);
      }
    }

    return _fetchAndEvaluate();
  }

  /// Resolves the latest release eligible for the active track, regardless of
  /// the current version, for an explicit `update`.
  ///
  /// Always fetches fresh: it bypasses the read cache so the result reflects
  /// what is published right now (a just-cut release is never missed, and a
  /// repair reinstall sees current truth). It still writes the cache as a side
  /// effect, so the background updater benefits. The returned [UpdateResolution]
  /// also reports the current version and whether it is eligible for the track,
  /// so the caller can detect a track/version mismatch.
  Future<UpdateResolution> resolveUpdate() async {
    final releases = await _api.fetchReleases();
    final selected = _selectLatestBridgeRelease(releases: releases);

    ReleaseInfo? latestEligible;
    BridgeVersion? latestVersion;
    if (selected != null) {
      final extracted = await _extractReleaseInfo(release: selected);
      if (extracted != null) {
        latestEligible = extracted.info;
        latestVersion = extracted.version;
      }
    }

    return UpdateResolution(
      currentVersion: _currentVersion,
      currentEligible: _isEligible(_currentVersion),
      latestEligible: latestEligible,
      latestVersion: latestVersion,
    );
  }

  ReleaseInfo? _evaluateCached({required CachedRelease cached}) {
    if (cached.assetName != _target.assetName || cached.track != _track.wireValue) {
      return null;
    }

    final BridgeVersion? latestVersion = BridgeVersion.tryParse(value: cached.latestVersion);
    if (latestVersion == null || !_isEligible(latestVersion)) {
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
        .where(
          (release) =>
              !release.draft &&
              release.tagName.startsWith('v'),
        )
        .map(
          (release) {
            final tagName = release.tagName;
            final versionString = tagName.replaceFirst('v', '');
            final version = BridgeVersion.tryParse(value: versionString);
            return version != null && _isEligible(version)
                ? (
                    release: release,
                    version: version,
                  )
                : null;
          },
        )
        .nonNulls
        .where(
          (item) =>
              item.release.assets.any((asset) => asset.name == _target.assetName) &&
              item.release.assets.any((asset) => asset.name == 'checksums.txt'),
        )
        .sorted(
          // sort descending
          (a, b) => b.version.compareTo(a.version),
        );

    return filteredReleases.firstOrNull?.release;
  }

  Future<ReleaseInfo?> _evaluateRelease({required GitHubReleaseDto release}) async {
    final extracted = await _extractReleaseInfo(release: release);
    if (extracted == null) {
      return null;
    }
    if (!_isEligible(extracted.version)) {
      return null;
    }
    if (extracted.version.compareTo(_currentVersion) <= 0) {
      return null;
    }
    return extracted.info;
  }

  /// Parses [release] into a typed [ReleaseInfo] (version + asset/checksums
  /// URLs + published date) and writes the metadata cache as a side effect.
  /// Returns `null` when the tag/version is unparseable or the required assets
  /// are missing. Applies NO eligibility or "is newer" gating — callers decide.
  Future<({ReleaseInfo info, BridgeVersion version})?> _extractReleaseInfo({
    required GitHubReleaseDto release,
  }) async {
    final tagName = release.tagName;
    if (!tagName.startsWith('v')) {
      return null;
    }

    final versionString = tagName.replaceFirst('v', '');
    final BridgeVersion? version = BridgeVersion.tryParse(value: versionString);
    if (version == null) {
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
      // Best-effort: the cache is a 10-minute TTL optimization to avoid
      // re-hitting GitHub every cycle. A write failure (e.g. a full/unwritable
      // cache dir) must not turn an otherwise-successful check or resolution
      // into a genuine update failure with reinstall guidance.
      try {
        await _cache.write(
          release: CachedRelease(
            latestVersion: version.toString(),
            downloadUrl: assetUrl,
            checksumsUrl: checksumsUrl,
            assetName: assetName,
            track: _track.wireValue,
            publishedAt: publishedAt,
            checkedAt: DateTime.now(),
          ),
        );
      } on Object catch (error) {
        Log.w('Failed to cache the latest release metadata: $error');
      }
    }

    if (assetUrl == null || checksumsUrl == null) {
      return null;
    }

    return (
      info: ReleaseInfo(
        version: version.toString(),
        assetUrl: assetUrl,
        checksumsUrl: checksumsUrl,
        publishedAt: publishedAt,
      ),
      version: version,
    );
  }
}
