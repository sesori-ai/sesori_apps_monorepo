import 'dart:io';

import 'package:clock/clock.dart';
import 'package:sesori_bridge/src/updater/api/update_cache_api.dart';
import 'package:sesori_bridge/src/updater/models/cached_release.dart';
import 'package:test/test.dart';

void main() {
  late String tempDir;

  setUp(() {
    // Create a temporary directory for each test
    tempDir = Directory.systemTemp.createTempSync('update_cache_test_').path;
  });

  tearDown(() {
    // Clean up the temporary directory
    final dir = Directory(tempDir);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  group('UpdateCacheApi', () {
    test('roundtrip: write and read returns same data', () async {
      final now = DateTime(2024, 1, 1, 12, 0, 0);
      final clock = Clock.fixed(now);

      final cache = UpdateCacheApi(
        cacheDirectory: tempDir,
        clock: clock,
      );

      final release = CachedRelease(
        latestVersion: '1.2.3',
        downloadUrl: 'https://example.com/download/1.2.3',
        checksumsUrl: 'https://example.com/checksums/1.2.3',
        assetName: 'sesori-bridge-macos-arm64.tar.gz',
        publishedAt: now.subtract(const Duration(days: 1)),
        checkedAt: now,
      );

      // Write
      await cache.write(release: release);

      // Read
      final cached = await cache.read(ttl: const Duration(hours: 1));

      expect(cached, isNotNull);
      expect(cached!.latestVersion, equals('1.2.3'));
      expect(cached.downloadUrl, equals('https://example.com/download/1.2.3'));
      expect(cached.checksumsUrl, equals('https://example.com/checksums/1.2.3'));
      expect(cached.assetName, equals('sesori-bridge-macos-arm64.tar.gz'));
      expect(cached.publishedAt, equals(now.subtract(const Duration(days: 1))));
      expect(cached.checkedAt, equals(now));
    });

    test('expired: data older than TTL returns null', () async {
      final checkedAt = DateTime(2024, 1, 1, 12, 0, 0);
      const ttl = Duration(hours: 1);

      final cache = UpdateCacheApi(
        cacheDirectory: tempDir,
        clock: Clock.fixed(checkedAt),
      );

      final release = CachedRelease(
        latestVersion: '1.2.3',
        downloadUrl: 'https://example.com/download/1.2.3',
        checksumsUrl: 'https://example.com/checksums/1.2.3',
        assetName: 'sesori-bridge-macos-arm64.tar.gz',
        publishedAt: checkedAt.subtract(const Duration(days: 1)),
        checkedAt: checkedAt,
      );

      // Write at T=0
      await cache.write(release: release);

      // Advance clock past TTL
      final expiredTime = checkedAt.add(ttl).add(const Duration(seconds: 1));
      final expiredCache = UpdateCacheApi(
        cacheDirectory: tempDir,
        clock: Clock.fixed(expiredTime),
      );

      // Read should return null
      final cached = await expiredCache.read(ttl: ttl);
      expect(cached, isNull);
    });

    test('fresh: data within TTL returns data', () async {
      final checkedAt = DateTime(2024, 1, 1, 12, 0, 0);
      const ttl = Duration(hours: 1);

      final cache = UpdateCacheApi(
        cacheDirectory: tempDir,
        clock: Clock.fixed(checkedAt),
      );

      final release = CachedRelease(
        latestVersion: '1.2.3',
        downloadUrl: 'https://example.com/download/1.2.3',
        checksumsUrl: 'https://example.com/checksums/1.2.3',
        assetName: 'sesori-bridge-macos-arm64.tar.gz',
        publishedAt: checkedAt.subtract(const Duration(days: 1)),
        checkedAt: checkedAt,
      );

      // Write at T=0
      await cache.write(release: release);

      // Advance clock within TTL
      final freshTime = checkedAt.add(const Duration(minutes: 30));
      final freshCache = UpdateCacheApi(
        cacheDirectory: tempDir,
        clock: Clock.fixed(freshTime),
      );

      // Read should return data
      final cached = await freshCache.read(ttl: ttl);
      expect(cached, isNotNull);
      expect(cached!.latestVersion, equals('1.2.3'));
    });

    test('corrupt: garbage in file returns null', () async {
      final cache = UpdateCacheApi(
        cacheDirectory: tempDir,
        clock: Clock.fixed(DateTime.now()),
      );

      // Create cache directory
      await Directory(tempDir).create(recursive: true);

      // Write garbage to cache file
      final cacheFile = File('$tempDir/update_cache.json');
      await cacheFile.writeAsString('{ invalid json }');

      // Read should return null
      final cached = await cache.read(ttl: const Duration(hours: 1));
      expect(cached, isNull);
    });

    test('missing: no file exists returns null', () async {
      final cache = UpdateCacheApi(
        cacheDirectory: tempDir,
        clock: Clock.fixed(DateTime.now()),
      );

      // Don't write anything
      // Read should return null
      final cached = await cache.read(ttl: const Duration(hours: 1));
      expect(cached, isNull);
    });

    test('missing directory: write creates directory', () async {
      final nestedDir = '$tempDir/nested/cache/dir';
      final cache = UpdateCacheApi(
        cacheDirectory: nestedDir,
        clock: Clock.fixed(DateTime.now()),
      );

      final release = CachedRelease(
        latestVersion: '1.0.0',
        downloadUrl: 'https://example.com/download/1.0.0',
        checksumsUrl: 'https://example.com/checksums/1.0.0',
        assetName: 'sesori-bridge-macos-arm64.tar.gz',
        publishedAt: DateTime.now(),
        checkedAt: DateTime.now(),
      );

      // Write should create directory
      await cache.write(release: release);

      // Verify directory was created
      expect(Directory(nestedDir).existsSync(), isTrue);

      // Verify file was written
      expect(File('$nestedDir/update_cache.json').existsSync(), isTrue);
    });

    test('boundary: data at exact TTL expiration returns null', () async {
      final checkedAt = DateTime(2024, 1, 1, 12, 0, 0);
      const ttl = Duration(hours: 1);

      final cache = UpdateCacheApi(
        cacheDirectory: tempDir,
        clock: Clock.fixed(checkedAt),
      );

      final release = CachedRelease(
        latestVersion: '1.2.3',
        downloadUrl: 'https://example.com/download/1.2.3',
        checksumsUrl: 'https://example.com/checksums/1.2.3',
        assetName: 'sesori-bridge-macos-arm64.tar.gz',
        publishedAt: checkedAt.subtract(const Duration(days: 1)),
        checkedAt: checkedAt,
      );

      // Write at T=0
      await cache.write(release: release);

      // Advance clock to exactly TTL expiration
      final expiryTime = checkedAt.add(ttl);
      final expiryCache = UpdateCacheApi(
        cacheDirectory: tempDir,
        clock: Clock.fixed(expiryTime),
      );

      // Read at exact expiry should return null
      final cached = await expiryCache.read(ttl: ttl);
      expect(cached, isNull);
    });

    test('multiple writes: latest write is read', () async {
      final now = DateTime(2024, 1, 1, 12, 0, 0);
      final clock = Clock.fixed(now);

      final cache = UpdateCacheApi(
        cacheDirectory: tempDir,
        clock: clock,
      );

      // First write
      final release1 = CachedRelease(
        latestVersion: '1.0.0',
        downloadUrl: 'https://example.com/download/1.0.0',
        checksumsUrl: 'https://example.com/checksums/1.0.0',
        assetName: 'sesori-bridge-macos-arm64.tar.gz',
        publishedAt: now.subtract(const Duration(days: 2)),
        checkedAt: now,
      );
      await cache.write(release: release1);

      // Second write (overwrites)
      final release2 = CachedRelease(
        latestVersion: '2.0.0',
        downloadUrl: 'https://example.com/download/2.0.0',
        checksumsUrl: 'https://example.com/checksums/2.0.0',
        assetName: 'sesori-bridge-macos-arm64.tar.gz',
        publishedAt: now.subtract(const Duration(days: 1)),
        checkedAt: now,
      );
      await cache.write(release: release2);

      // Read should return latest
      final cached = await cache.read(ttl: const Duration(hours: 1));
      expect(cached, isNotNull);
      expect(cached!.latestVersion, equals('2.0.0'));
    });

    test('write error: propagates filesystem exception', () async {
      // Use a path that cannot be written to (e.g., /dev/null/cache)
      final cache = UpdateCacheApi(
        cacheDirectory: '/dev/null/cache',
        clock: Clock.fixed(DateTime.now()),
      );

      final release = CachedRelease(
        latestVersion: '1.0.0',
        downloadUrl: 'https://example.com/download/1.0.0',
        checksumsUrl: 'https://example.com/checksums/1.0.0',
        assetName: 'sesori-bridge-macos-arm64.tar.gz',
        publishedAt: DateTime.now(),
        checkedAt: DateTime.now(),
      );

      // Write should throw on I/O failure
      expect(
        () => cache.write(release: release),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}
