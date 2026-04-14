import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sesori_bridge/src/updater/api/github_releases_api.dart';
import 'package:sesori_bridge/src/updater/api/update_cache_api.dart';
import 'package:sesori_bridge/src/updater/foundation/platform_info.dart';
import 'package:sesori_bridge/src/updater/foundation/version_utils.dart';
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
}) => {
  'tag_name': tagName ?? 'bridge-v$version',
  'published_at': '2024-06-01T00:00:00Z',
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
  _FakeCache? cache,
  String currentVersion = '0.2.0',
  DistributionTarget? target,
}) {
  final resolvedTarget = target ?? _defaultTarget;

  return ReleaseRepository(
    api: GitHubReleasesApi(httpClient: httpClient),
    cache: cache ?? _FakeCache(),
    currentVersion: currentVersion,
    target: resolvedTarget,
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

      test('paginates release discovery until later pages to find the highest eligible stable release', () async {
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
          if (page == 2) {
            return http.Response(jsonEncode([_releaseJson(version: '0.4.0')]), 200);
          }
          return http.Response(jsonEncode(<Map<String, dynamic>>[]), 200);
        });

        final repository = _makeRepository(
          httpClient: client,
          currentVersion: '0.2.0',
        );

        final result = await repository.checkForNewerRelease();

        expect(result, isNotNull);
        expect(result!.version, equals('0.4.0'));
        expect(requestedPages, equals([1, 2]));
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

      test('HTTP 403 (rate limit) → throws', () async {
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

      test('HTTP 500 → throws', () async {
        await expectLater(
          _makeRepository(httpClient: _mockStatus(500)).checkForNewerRelease(),
          throwsA(isA<StateError>()),
        );
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

      test('tag_name without bridge-v prefix → returns null', () async {
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode([
              {
                'tag_name': 'v0.3.0',
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
  });

  // -------------------------------------------------------------------------
  group('compareVersions', () {
    test('newer major → positive', () {
      expect(compareVersions(a: '2.0.0', b: '1.0.0'), isPositive);
    });

    test('newer minor → positive', () {
      expect(compareVersions(a: '0.3.0', b: '0.2.0'), isPositive);
    });

    test('newer patch → positive', () {
      expect(compareVersions(a: '0.2.1', b: '0.2.0'), isPositive);
    });

    test('equal versions → zero', () {
      expect(compareVersions(a: '1.2.3', b: '1.2.3'), equals(0));
    });

    test('older major → negative', () {
      expect(compareVersions(a: '0.1.0', b: '0.2.0'), isNegative);
    });

    test('pre-release vs stable same base → negative', () {
      expect(compareVersions(a: '1.0.0-beta', b: '1.0.0'), isNegative);
    });

    test('stable vs pre-release same base → positive', () {
      expect(compareVersions(a: '1.0.0', b: '1.0.0-beta'), isPositive);
    });

    test('pre-release with newer numeric base → positive', () {
      expect(compareVersions(a: '2.0.0-beta', b: '1.9.9'), isPositive);
    });

    test('two pre-releases same base → zero', () {
      expect(compareVersions(a: '1.0.0-alpha', b: '1.0.0-beta'), equals(0));
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
