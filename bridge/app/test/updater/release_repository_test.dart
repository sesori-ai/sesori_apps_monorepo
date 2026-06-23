import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sesori_bridge/src/updater/api/github_releases_api.dart';
import 'package:sesori_bridge/src/updater/api/update_cache_api.dart';
import 'package:sesori_bridge/src/updater/foundation/platform_info.dart';
import 'package:sesori_bridge/src/updater/foundation/release_track.dart';
import 'package:sesori_bridge/src/updater/models/bridge_version.dart';
import 'package:sesori_bridge/src/updater/models/cached_release.dart';
import 'package:sesori_bridge/src/updater/models/distribution_target.dart';
import 'package:sesori_bridge/src/updater/models/release_info.dart';
import 'package:sesori_bridge/src/updater/repositories/release_repository.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// Fake cache that returns a pre-configured [CachedRelease] from [read] and
/// records all values passed to [write].
class _FakeCache extends UpdateCacheApi {
  final CachedRelease? _readResult;
  final List<CachedRelease> writtenReleases = [];

  _FakeCache({CachedRelease? readResult}) : _readResult = readResult, super(cacheDirectory: '', clock: const Clock());

  @override
  Future<CachedRelease?> read({required Duration ttl}) async => _readResult;

  @override
  Future<void> write({required CachedRelease release}) async {
    writtenReleases.add(release);
  }
}

/// Cache whose [write] always fails, simulating a full/unwritable cache dir.
class _ThrowingCache extends UpdateCacheApi {
  _ThrowingCache() : super(cacheDirectory: '', clock: const Clock());

  @override
  Future<CachedRelease?> read({required Duration ttl}) async => null;

  @override
  Future<void> write({required CachedRelease release}) async {
    throw const FileSystemException('disk full');
  }
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/// Minimal GitHub API response shape for the `/releases` endpoint.
final DistributionTarget _defaultTarget = DistributionTarget(
  os: DistributionPlatformOs.macos,
  arch: DistributionPlatformArch.arm64,
);

Map<String, dynamic> _releaseJson({
  String version = '0.3.0',
  String? assetName,
  bool draft = false,
  bool prerelease = false,
  String? tagName,
  String? publishedAt = '2024-06-01T00:00:00Z',
}) => {
  'tag_name': tagName ?? 'v$version',
  'published_at': publishedAt,
  'draft': draft,
  'prerelease': prerelease,
  'assets': [
    {
      'name': assetName ?? _defaultTarget.assetName,
      'browser_download_url': 'https://example.com/releases/download/$version/${assetName ?? _defaultTarget.assetName}',
    },
    {
      'name': 'checksums.txt',
      'browser_download_url': 'https://example.com/releases/download/$version/checksums.txt',
    },
  ],
};

/// Creates a [MockClient] that returns [body] as JSON with [status].
MockClient _mockOk({required Object body, int status = 200}) =>
    MockClient((_) async => http.Response(jsonEncode(body), status));

/// Creates a [MockClient] that always returns an empty body with [status].
MockClient _mockStatus(int status) => MockClient((_) async => http.Response('', status));

/// Creates a [ReleaseRepository] with overrideable defaults.
///
/// Platform is always locked to macos/arm64 so tests are machine-independent.
ReleaseRepository _makeRepository({
  required http.Client httpClient,
  UpdateCacheApi? cache,
  String currentVersion = '0.2.0',
  DistributionTarget? target,
  ReleaseTrack track = ReleaseTrack.stable,
}) {
  final resolvedTarget = target ?? _defaultTarget;

  return ReleaseRepository(
    api: GitHubReleasesApi(httpClient: httpClient, authToken: null),
    cache: cache ?? _FakeCache(),
    currentVersion: currentVersion,
    target: resolvedTarget,
    track: track,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ReleaseRepository', () {
    // -----------------------------------------------------------------------
    group('checkForNewerRelease - happy paths', () {
      test('newer version available → returns populated ReleaseInfo', () async {
        final repository = _makeRepository(
          httpClient: _mockOk(body: [_releaseJson(version: '0.3.0')]),
          currentVersion: '0.2.0',
        );

        final result = await repository.checkForNewerRelease();

        expect(result, isNotNull);
        expect(result!.version, equals('0.3.0'));
        expect(
          result.assetUrl,
          equals(
            'https://example.com/releases/download/0.3.0/sesori-bridge-macos-arm64.tar.gz',
          ),
        );
        expect(
          result.checksumsUrl,
          equals(
            'https://example.com/releases/download/0.3.0/checksums.txt',
          ),
        );
        expect(result.publishedAt, equals(DateTime.parse('2024-06-01T00:00:00Z')));
      });

      test('same version as current → returns null', () async {
        final repository = _makeRepository(
          httpClient: _mockOk(body: [_releaseJson(version: '0.2.0')]),
          currentVersion: '0.2.0',
        );

        expect(await repository.checkForNewerRelease(), isNull);
      });

      test('older version than current → returns null', () async {
        final repository = _makeRepository(
          httpClient: _mockOk(body: [_releaseJson(version: '0.1.5')]),
          currentVersion: '0.2.0',
        );

        expect(await repository.checkForNewerRelease(), isNull);
      });

      test('typed windows target selects zip asset and checksum url', () async {
        final windowsTarget = DistributionTarget(
          os: DistributionPlatformOs.windows,
          arch: DistributionPlatformArch.x64,
        );
        final repository = _makeRepository(
          httpClient: _mockOk(
            body: [
              _releaseJson(
                version: '0.3.0',
                assetName: windowsTarget.assetName,
              ),
            ],
          ),
          currentVersion: '0.2.0',
          target: windowsTarget,
        );

        final result = await repository.checkForNewerRelease();

        expect(result, isNotNull);
        expect(result!.assetUrl, endsWith('/sesori-bridge-windows-x64.zip'));
        expect(result.checksumsUrl, endsWith('/checksums.txt'));
      });

      test('skips newer invalid bridge releases until a valid stable target match is found', () async {
        final repository = _makeRepository(
          httpClient: _mockOk(
            body: [
              _releaseJson(
                version: '0.5.0',
                assetName: 'sesori-bridge-linux-x64.tar.gz',
              ),
              _releaseJson(
                version: '0.4.0-beta.1',
                prerelease: true,
              ),
              _releaseJson(version: '0.3.1'),
            ],
          ),
          currentVersion: '0.2.0',
        );

        final result = await repository.checkForNewerRelease();

        expect(result, isNotNull);
        expect(result!.version, equals('0.3.1'));
        expect(result.assetUrl, endsWith('/sesori-bridge-macos-arm64.tar.gz'));
      });

      test('only fetches one page of releases', () async {
        final requestedPages = <int>[];
        final firstPage = List.generate(100, (index) {
          return _releaseJson(
            version: '0.3.${index + 1}',
            assetName: 'sesori-bridge-linux-x64.tar.gz',
          );
        });
        final client = MockClient((request) async {
          final page = int.parse(request.url.queryParameters['page'] ?? '1');
          requestedPages.add(page);
          if (page == 1) {
            return http.Response(jsonEncode(firstPage), 200);
          }
          return http.Response(jsonEncode(<Map<String, dynamic>>[]), 200);
        });

        final repository = _makeRepository(
          httpClient: client,
          currentVersion: '0.2.0',
        );

        final result = await repository.checkForNewerRelease();

        expect(result, isNull);
        expect(requestedPages, equals([1]));
      });
    });

    // -----------------------------------------------------------------------
    group('checkForNewerRelease - error handling', () {
      test('network TimeoutException → throws so callers can surface the failure', () async {
        final client = MockClient(
          (_) async => throw TimeoutException('simulated timeout'),
        );

        await expectLater(
          _makeRepository(httpClient: client).checkForNewerRelease(),
          throwsA(isA<TimeoutException>()),
        );
      });

      test('HTTP 403 without rate-limit headers → throws StateError', () async {
        await expectLater(
          _makeRepository(httpClient: _mockStatus(403)).checkForNewerRelease(),
          throwsA(isA<StateError>()),
        );
      });

      test('HTTP 404 → throws', () async {
        await expectLater(
          _makeRepository(httpClient: _mockStatus(404)).checkForNewerRelease(),
          throwsA(isA<StateError>()),
        );
      });

      test('HTTP 500 → throws HttpException (transient/retryable, not a genuine failure)', () async {
        await expectLater(
          _makeRepository(httpClient: _mockStatus(500)).checkForNewerRelease(),
          throwsA(isA<HttpException>()),
        );
      });

      test('a release-cache write failure is best-effort and never fails the check', () async {
        // The fetched release is NOT newer than the running version, so the
        // correct result is null — even though the cache write throws.
        final repository = _makeRepository(
          httpClient: _mockOk(body: [_releaseJson(version: '0.1.0')]),
          cache: _ThrowingCache(),
          currentVersion: '0.2.0',
        );

        expect(await repository.checkForNewerRelease(), isNull);
      });

      test('malformed JSON body → throws', () async {
        final client = MockClient(
          (_) async => http.Response('{ not valid json }}}', 200),
        );

        await expectLater(
          _makeRepository(httpClient: client).checkForNewerRelease(),
          throwsA(isA<FormatException>()),
        );
      });

      test('missing platform asset does not poison cache', () async {
        final cache = _FakeCache();
        final repository = _makeRepository(
          httpClient: _mockOk(
            body: [_releaseJson(version: '0.3.0', assetName: 'sesori-bridge-linux-x64.tar.gz')],
          ),
          cache: cache,
          currentVersion: '0.2.0',
        );

        expect(await repository.checkForNewerRelease(), isNull);
        expect(cache.writtenReleases, isEmpty);
      });

      test('missing tag_name field → throws', () async {
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode([
              {
                'published_at': '2024-06-01T00:00:00Z',
                'draft': false,
                'prerelease': false,
                'assets': <Map<String, dynamic>>[],
              },
            ]),
            200,
          ),
        );

        await expectLater(
          _makeRepository(httpClient: client).checkForNewerRelease(),
          throwsA(isA<TypeError>()),
        );
      });

      test('unrecognized tag prefix (e.g., app-v) → returns null', () async {
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode([
              {
                'tag_name': 'app-v0.3.0',
                'published_at': '2024-06-01T00:00:00Z',
                'draft': false,
                'prerelease': false,
                'assets': <Map<String, dynamic>>[],
              },
            ]),
            200,
          ),
        );

        expect(await _makeRepository(httpClient: client).checkForNewerRelease(), isNull);
      });

      test('generic exception from HTTP client → throws', () async {
        final client = MockClient((_) async => throw Exception('network error'));

        await expectLater(
          _makeRepository(httpClient: client).checkForNewerRelease(),
          throwsA(isA<Exception>()),
        );
      });

      test('invalid published_at on selected stable release → throws', () async {
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode([
              {
                ..._releaseJson(version: '0.3.0'),
                'published_at': 'not-a-date',
              },
            ]),
            200,
          ),
        );

        await expectLater(
          _makeRepository(httpClient: client).checkForNewerRelease(),
          throwsA(isA<StateError>()),
        );
      });
    });

    // -----------------------------------------------------------------------
    group('checkForNewerRelease - pre-release filtering', () {
      test('pre-release tag (e.g. 0.3.0-beta) → returns null', () async {
        final repository = _makeRepository(
          httpClient: _mockOk(body: [_releaseJson(version: '0.3.0-beta', prerelease: true)]),
          currentVersion: '0.2.0',
        );

        expect(await repository.checkForNewerRelease(), isNull);
      });

      test('pre-release same base as current → returns null', () async {
        final repository = _makeRepository(
          httpClient: _mockOk(body: [_releaseJson(version: '0.2.0-rc1', prerelease: true)]),
          currentVersion: '0.2.0',
        );

        expect(await repository.checkForNewerRelease(), isNull);
      });
    });

    // -----------------------------------------------------------------------
    group('checkForNewerRelease - caching', () {
      test('fresh cache with newer version → returns ReleaseInfo, no HTTP call', () async {
        var httpCallCount = 0;
        final client = MockClient((_) async {
          httpCallCount++;
          return http.Response(jsonEncode([_releaseJson()]), 200);
        });

        final cached = CachedRelease(
          latestVersion: '0.9.0',
          downloadUrl: 'https://example.com/dl/asset.tar.gz',
          checksumsUrl: 'https://example.com/dl/checksums.txt',
          assetName: _defaultTarget.assetName,
          track: 'stable',
          publishedAt: DateTime.parse('2024-06-01T00:00:00Z'),
          checkedAt: DateTime.now(),
        );
        final repository = _makeRepository(
          httpClient: client,
          cache: _FakeCache(readResult: cached),
          currentVersion: '0.2.0',
        );

        final result = await repository.checkForNewerRelease();

        expect(result, isNotNull);
        expect(result!.version, equals('0.9.0'));
        expect(result.publishedAt, equals(DateTime.parse('2024-06-01T00:00:00Z')));
        expect(httpCallCount, equals(0), reason: 'should not hit HTTP when cache is fresh');
      });

      test('fresh cache with same version → returns null, no HTTP call', () async {
        var httpCallCount = 0;
        final client = MockClient((_) async {
          httpCallCount++;
          return http.Response(jsonEncode([_releaseJson()]), 200);
        });

        final cached = CachedRelease(
          latestVersion: '0.2.0',
          downloadUrl: 'https://example.com/dl/asset.tar.gz',
          checksumsUrl: 'https://example.com/dl/checksums.txt',
          assetName: _defaultTarget.assetName,
          track: 'stable',
          publishedAt: DateTime.parse('2024-06-01T00:00:00Z'),
          checkedAt: DateTime.now(),
        );
        final repository = _makeRepository(
          httpClient: client,
          cache: _FakeCache(readResult: cached),
          currentVersion: '0.2.0',
        );

        expect(await repository.checkForNewerRelease(), isNull);
        expect(httpCallCount, equals(0), reason: 'should not hit HTTP when cache is fresh');
      });

      test('fresh cache with pre-release version → returns null, no HTTP call', () async {
        var httpCallCount = 0;
        final client = MockClient((_) async {
          httpCallCount++;
          return http.Response(jsonEncode([_releaseJson()]), 200);
        });

        final cached = CachedRelease(
          latestVersion: '0.3.0-beta',
          downloadUrl: 'https://example.com/dl/asset.tar.gz',
          checksumsUrl: 'https://example.com/dl/checksums.txt',
          assetName: _defaultTarget.assetName,
          track: 'stable',
          publishedAt: DateTime.parse('2024-06-01T00:00:00Z'),
          checkedAt: DateTime.now(),
        );
        final repository = _makeRepository(
          httpClient: client,
          cache: _FakeCache(readResult: cached),
          currentVersion: '0.2.0',
        );

        expect(await repository.checkForNewerRelease(), isNull);
        expect(httpCallCount, equals(0));
      });

      test('expired cache (read returns null) → makes HTTP call', () async {
        var httpCallCount = 0;
        final client = MockClient((_) async {
          httpCallCount++;
          return http.Response(jsonEncode([_releaseJson()]), 200);
        });

        // _FakeCache with no readResult returns null (simulates expired/missing cache)
        final repository = _makeRepository(httpClient: client);

        await repository.checkForNewerRelease();

        expect(httpCallCount, equals(1), reason: 'should hit HTTP when cache is expired');
      });

      test('successful HTTP fetch → writes result to cache', () async {
        final cache = _FakeCache();
        final repository = _makeRepository(
          httpClient: _mockOk(body: [_releaseJson(version: '0.3.0')]),
          cache: cache,
          currentVersion: '0.2.0',
        );

        await repository.checkForNewerRelease();

        expect(cache.writtenReleases, hasLength(1));
        expect(cache.writtenReleases.first.latestVersion, equals('0.3.0'));
        expect(cache.writtenReleases.first.assetName, equals(_defaultTarget.assetName));
        expect(
          cache.writtenReleases.first.publishedAt,
          equals(DateTime.parse('2024-06-01T00:00:00Z')),
        );
        expect(
          cache.writtenReleases.first.downloadUrl,
          equals(
            'https://example.com/releases/download/0.3.0/sesori-bridge-macos-arm64.tar.gz',
          ),
        );
      });

      test('same version from HTTP → still writes to cache', () async {
        final cache = _FakeCache();
        final repository = _makeRepository(
          httpClient: _mockOk(body: [_releaseJson(version: '0.2.0')]),
          cache: cache,
          currentVersion: '0.2.0',
        );

        await repository.checkForNewerRelease();

        expect(cache.writtenReleases, hasLength(1));
      });

      test('pre-release from HTTP is skipped and not cached', () async {
        final cache = _FakeCache();
        final repository = _makeRepository(
          httpClient: _mockOk(body: [_releaseJson(version: '0.3.0-beta', prerelease: true)]),
          cache: cache,
          currentVersion: '0.2.0',
        );

        await repository.checkForNewerRelease();

        expect(cache.writtenReleases, isEmpty);
      });

      test('draft releases with null published_at do not break stable resolution', () async {
        final repository = _makeRepository(
          httpClient: _mockOk(
            body: [
              _releaseJson(version: '0.4.0', draft: true, publishedAt: null),
              _releaseJson(version: '0.3.1'),
            ],
          ),
          currentVersion: '0.2.0',
        );

        final result = await repository.checkForNewerRelease();

        expect(result, isNotNull);
        expect(result!.version, equals('0.3.1'));
      });

      test('cache entries for another target are ignored and refreshed from HTTP', () async {
        var httpCallCount = 0;
        final client = MockClient((_) async {
          httpCallCount++;
          return http.Response(jsonEncode([_releaseJson(version: '0.3.0')]), 200);
        });

        final cached = CachedRelease(
          latestVersion: '9.9.9',
          downloadUrl: 'https://example.com/dl/windows.zip',
          checksumsUrl: 'https://example.com/dl/checksums.txt',
          assetName: 'sesori-bridge-windows-x64.zip',
          track: 'stable',
          publishedAt: DateTime.parse('2024-06-01T00:00:00Z'),
          checkedAt: DateTime.now(),
        );
        final repository = _makeRepository(
          httpClient: client,
          cache: _FakeCache(readResult: cached),
          currentVersion: '0.2.0',
        );

        final result = await repository.checkForNewerRelease();

        expect(result, isNotNull);
        expect(result!.version, equals('0.3.0'));
        expect(httpCallCount, equals(1));
      });

      test('selects newest stable bridge release instead of repo-wide latest release', () async {
        final repository = _makeRepository(
          httpClient: _mockOk(
            body: [
              _releaseJson(tagName: 'repo-v9.9.9', version: '9.9.9'),
              _releaseJson(version: '0.4.0-beta', prerelease: true),
              _releaseJson(version: '0.3.1'),
            ],
          ),
          currentVersion: '0.2.0',
        );

        final result = await repository.checkForNewerRelease();

        expect(result, isNotNull);
        expect(result!.version, equals('0.3.1'));
      });

      test('selects highest eligible bridge semver instead of first eligible release', () async {
        final repository = _makeRepository(
          httpClient: _mockOk(
            body: [
              _releaseJson(version: '0.3.1'),
              _releaseJson(version: '0.4.0'),
              _releaseJson(version: '0.3.9'),
            ],
          ),
          currentVersion: '0.2.0',
        );

        final result = await repository.checkForNewerRelease();

        expect(result, isNotNull);
        expect(result!.version, equals('0.4.0'));
      });

      test('skips invalid stable bridge release assets and picks next valid release', () async {
        final repository = _makeRepository(
          httpClient: _mockOk(
            body: [
              _releaseJson(version: '0.4.0', assetName: 'sesori-bridge-linux-x64.tar.gz'),
              _releaseJson(version: '0.3.1'),
            ],
          ),
          currentVersion: '0.2.0',
        );

        final result = await repository.checkForNewerRelease();

        expect(result, isNotNull);
        expect(result!.version, equals('0.3.1'));
      });
    });
    // -----------------------------------------------------------------------
    group('release track', () {
      test('stable track ignores a newer internal pre-release', () async {
        final repository = _makeRepository(
          httpClient: _mockOk(
            body: [
              _releaseJson(version: '0.5.0-internal.3', prerelease: true),
              _releaseJson(version: '0.3.1'),
            ],
          ),
          currentVersion: '0.2.0',
        );

        final result = await repository.checkForNewerRelease();

        expect(result, isNotNull);
        expect(result!.version, equals('0.3.1'));
      });

      test('internal track selects a newer internal pre-release', () async {
        final repository = _makeRepository(
          httpClient: _mockOk(
            body: [
              _releaseJson(version: '0.5.0-internal.3', prerelease: true),
              _releaseJson(version: '0.3.1'),
            ],
          ),
          currentVersion: '0.2.0',
          track: ReleaseTrack.internal,
        );

        final result = await repository.checkForNewerRelease();

        expect(result, isNotNull);
        expect(result!.version, equals('0.5.0-internal.3'));
      });

      test('internal track picks the newest of stable and internal', () async {
        final repository = _makeRepository(
          httpClient: _mockOk(
            body: [
              _releaseJson(version: '0.4.0-internal.2', prerelease: true),
              _releaseJson(version: '0.4.0'),
            ],
          ),
          currentVersion: '0.2.0',
          track: ReleaseTrack.internal,
        );

        final result = await repository.checkForNewerRelease();

        expect(result, isNotNull);
        // Stable 0.4.0 outranks its own 0.4.0-internal.2 pre-release.
        expect(result!.version, equals('0.4.0'));
      });

      test('internal track ignores non-internal pre-releases (rc/beta)', () async {
        final repository = _makeRepository(
          httpClient: _mockOk(
            body: [
              _releaseJson(version: '0.5.0-rc.1', prerelease: true),
              _releaseJson(version: '0.5.0-beta.2', prerelease: true),
              _releaseJson(version: '0.3.1'),
            ],
          ),
          currentVersion: '0.2.0',
          track: ReleaseTrack.internal,
        );

        final result = await repository.checkForNewerRelease();

        expect(result, isNotNull);
        expect(result!.version, equals('0.3.1'));
      });

      test('internal track is forward-only: stable older than current internal → null', () async {
        final repository = _makeRepository(
          httpClient: _mockOk(
            body: [
              _releaseJson(version: '0.3.0'),
            ],
          ),
          currentVersion: '0.4.0-internal.3',
          track: ReleaseTrack.internal,
        );

        // 0.3.0 < 0.4.0-internal.3, so no update (no downgrade to stable).
        expect(await repository.checkForNewerRelease(), isNull);
      });

      test('internal track selects the highest internal build number', () async {
        final repository = _makeRepository(
          httpClient: _mockOk(
            body: [
              _releaseJson(version: '0.4.0-internal.9', prerelease: true),
              _releaseJson(version: '0.4.0-internal.53', prerelease: true),
              _releaseJson(version: '0.4.0-internal.12', prerelease: true),
            ],
          ),
          currentVersion: '0.2.0',
          track: ReleaseTrack.internal,
        );

        final result = await repository.checkForNewerRelease();

        expect(result, isNotNull);
        expect(result!.version, equals('0.4.0-internal.53'));
      });

      test('internal track writes the track into the cache', () async {
        final cache = _FakeCache();
        final repository = _makeRepository(
          httpClient: _mockOk(body: [_releaseJson(version: '0.5.0-internal.3', prerelease: true)]),
          cache: cache,
          currentVersion: '0.2.0',
          track: ReleaseTrack.internal,
        );

        await repository.checkForNewerRelease();

        expect(cache.writtenReleases, hasLength(1));
        expect(cache.writtenReleases.first.track, equals('internal'));
        expect(cache.writtenReleases.first.latestVersion, equals('0.5.0-internal.3'));
      });

      test('cache entry from a different track is ignored and refreshed from HTTP', () async {
        var httpCallCount = 0;
        final client = MockClient((_) async {
          httpCallCount++;
          return http.Response(
            jsonEncode([_releaseJson(version: '0.5.0-internal.4', prerelease: true)]),
            200,
          );
        });

        final cached = CachedRelease(
          latestVersion: '9.9.9',
          downloadUrl: 'https://example.com/dl/asset.tar.gz',
          checksumsUrl: 'https://example.com/dl/checksums.txt',
          assetName: _defaultTarget.assetName,
          track: 'stable',
          publishedAt: DateTime.parse('2024-06-01T00:00:00Z'),
          checkedAt: DateTime.now(),
        );
        final repository = _makeRepository(
          httpClient: client,
          cache: _FakeCache(readResult: cached),
          currentVersion: '0.2.0',
          track: ReleaseTrack.internal,
        );

        final result = await repository.checkForNewerRelease();

        expect(result, isNotNull);
        expect(result!.version, equals('0.5.0-internal.4'));
        expect(httpCallCount, equals(1), reason: 'a stable cache must not satisfy an internal-track check');
      });
    });

    // -----------------------------------------------------------------------
    group('resolveUpdate', () {
      test('returns the latest eligible release and current eligibility', () async {
        final repository = _makeRepository(
          httpClient: _mockOk(
            body: [
              _releaseJson(version: '0.4.0'),
              _releaseJson(version: '0.3.1'),
            ],
          ),
          currentVersion: '0.2.0',
        );

        final resolution = await repository.resolveUpdate();

        expect(resolution.latestEligible?.version, equals('0.4.0'));
        expect(resolution.latestVersion?.toString(), equals('0.4.0'));
        expect(resolution.currentVersion.toString(), equals('0.2.0'));
        expect(resolution.currentEligible, isTrue);
      });

      test('returns the latest eligible release even when it is not newer (for --force)', () async {
        final repository = _makeRepository(
          httpClient: _mockOk(body: [_releaseJson(version: '0.3.0')]),
          currentVersion: '0.5.0',
        );

        final resolution = await repository.resolveUpdate();

        // checkForNewerRelease() would return null here; resolveUpdate must not.
        expect(resolution.latestEligible?.version, equals('0.3.0'));
        expect(resolution.latestVersion?.toString(), equals('0.3.0'));
      });

      test('reports an off-track running build as ineligible', () async {
        final repository = _makeRepository(
          httpClient: _mockOk(body: [_releaseJson(version: '0.3.0')]),
          currentVersion: '0.5.0-internal.3',
        );

        final resolution = await repository.resolveUpdate();

        expect(resolution.currentEligible, isFalse);
        expect(resolution.latestEligible?.version, equals('0.3.0'));
      });

      test('always fetches fresh, ignoring a fresh cache', () async {
        var httpCallCount = 0;
        final client = MockClient((_) async {
          httpCallCount++;
          return http.Response(jsonEncode([_releaseJson(version: '0.4.0')]), 200);
        });
        final cached = CachedRelease(
          latestVersion: '9.9.9',
          downloadUrl: 'https://example.com/dl/asset.tar.gz',
          checksumsUrl: 'https://example.com/dl/checksums.txt',
          assetName: _defaultTarget.assetName,
          track: 'stable',
          publishedAt: DateTime.parse('2024-06-01T00:00:00Z'),
          checkedAt: DateTime.now(),
        );
        final repository = _makeRepository(
          httpClient: client,
          cache: _FakeCache(readResult: cached),
          currentVersion: '0.2.0',
        );

        final resolution = await repository.resolveUpdate();

        expect(httpCallCount, equals(1), reason: 'resolveUpdate bypasses the read cache');
        expect(resolution.latestEligible?.version, equals('0.4.0'));
      });

      test('returns a null latest when no eligible release exists', () async {
        final repository = _makeRepository(
          httpClient: _mockOk(body: <Map<String, dynamic>>[]),
          currentVersion: '0.2.0',
        );

        final resolution = await repository.resolveUpdate();

        expect(resolution.latestEligible, isNull);
        expect(resolution.latestVersion, isNull);
      });

      test('writes the resolved release to the cache as a side effect', () async {
        final cache = _FakeCache();
        final repository = _makeRepository(
          httpClient: _mockOk(body: [_releaseJson(version: '0.4.0')]),
          cache: cache,
          currentVersion: '0.2.0',
        );

        await repository.resolveUpdate();

        expect(cache.writtenReleases, hasLength(1));
        expect(cache.writtenReleases.first.latestVersion, equals('0.4.0'));
      });
    });
  });

  // -------------------------------------------------------------------------
  group('BridgeVersion', () {
    test('newer major compares positive', () {
      expect(
        BridgeVersion.parse(value: '2.0.0').compareTo(BridgeVersion.parse(value: '1.0.0')),
        isPositive,
      );
    });

    test('newer minor compares positive', () {
      expect(
        BridgeVersion.parse(value: '0.3.0').compareTo(BridgeVersion.parse(value: '0.2.0')),
        isPositive,
      );
    });

    test('newer patch compares positive', () {
      expect(
        BridgeVersion.parse(value: '0.2.1').compareTo(BridgeVersion.parse(value: '0.2.0')),
        isPositive,
      );
    });

    test('equal versions compare to zero', () {
      expect(
        BridgeVersion.parse(value: '1.2.3').compareTo(BridgeVersion.parse(value: '1.2.3')),
        equals(0),
      );
    });

    test('older major compares negative', () {
      expect(
        BridgeVersion.parse(value: '0.1.0').compareTo(BridgeVersion.parse(value: '0.2.0')),
        isNegative,
      );
    });

    test('prerelease is lower precedence than stable with same base', () {
      expect(
        BridgeVersion.parse(value: '1.0.0-beta').compareTo(BridgeVersion.parse(value: '1.0.0')),
        isNegative,
      );
    });

    test('stable is higher precedence than prerelease with same base', () {
      expect(
        BridgeVersion.parse(value: '1.0.0').compareTo(BridgeVersion.parse(value: '1.0.0-beta')),
        isPositive,
      );
    });

    test('stable is higher precedence than internal build with same base', () {
      expect(
        BridgeVersion.parse(value: '9.8.7').compareTo(BridgeVersion.parse(value: '9.8.7-internal.53')),
        isPositive,
      );
      expect(
        BridgeVersion.parse(value: '9.8.7-internal.53').compareTo(BridgeVersion.parse(value: '9.8.7')),
        isNegative,
      );
    });

    test('internal builds with same base compare numerically by build number', () {
      expect(
        BridgeVersion.parse(value: '1.0.9-internal.9').compareTo(BridgeVersion.parse(value: '1.0.9-internal.53')),
        isNegative,
      );
      expect(
        BridgeVersion.parse(value: '1.0.9-internal.54').compareTo(BridgeVersion.parse(value: '1.0.9-internal.53')),
        isPositive,
      );
    });

    test('internal build of a newer base is higher than an older stable', () {
      expect(
        BridgeVersion.parse(value: '1.0.9-internal.53').compareTo(BridgeVersion.parse(value: '1.0.8')),
        isPositive,
      );
    });

    test('prerelease with newer numeric base still compares positive', () {
      expect(
        BridgeVersion.parse(value: '2.0.0-beta').compareTo(BridgeVersion.parse(value: '1.9.9')),
        isPositive,
      );
    });

    test('prerelease identifiers compare lexically when numeric base matches', () {
      expect(
        BridgeVersion.parse(value: '1.0.0-alpha').compareTo(BridgeVersion.parse(value: '1.0.0-beta')),
        isNegative,
      );
    });

    test('build metadata does not affect comparison precedence', () {
      expect(
        BridgeVersion.parse(value: '1.2.3+build.1').compareTo(BridgeVersion.parse(value: '1.2.3+build.9')),
        equals(0),
      );
    });

    test('tryParse returns null for invalid strings', () {
      expect(BridgeVersion.tryParse(value: 'not-a-version'), isNull);
    });
  });

  // -------------------------------------------------------------------------
  group('ReleaseInfo', () {
    test('toJson / fromJson roundtrip preserves all fields', () {
      final now = DateTime.parse('2024-06-01T00:00:00.000Z');
      final original = ReleaseInfo(
        version: '0.3.0',
        assetUrl: 'https://example.com/download/asset.tar.gz',
        checksumsUrl: 'https://example.com/download/checksums.txt',
        publishedAt: now,
      );

      final restored = ReleaseInfo.fromJson(original.toJson());

      expect(restored.version, equals(original.version));
      expect(restored.assetUrl, equals(original.assetUrl));
      expect(restored.checksumsUrl, equals(original.checksumsUrl));
      expect(restored.publishedAt, equals(original.publishedAt));
    });

    test('fromJson parses ISO-8601 date correctly', () {
      final info = ReleaseInfo.fromJson({
        'version': '1.0.0',
        'assetUrl': 'https://example.com/a',
        'checksumsUrl': 'https://example.com/c',
        'publishedAt': '2025-01-15T12:30:00.000Z',
      });

      expect(info.publishedAt, equals(DateTime.parse('2025-01-15T12:30:00.000Z')));
    });
  });
}
